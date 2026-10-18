---
title: vLLM 설치 및 모델 서빙 / GPU Ubuntu 26.04 환경
---

## 1. 설치, 실행 환경

설치, 실행 환경은 다음과 같다.

* Ubuntu 26.04 LTS 64bit, root user
* Nvidia RTX 5060 Ti GPU 16GB
  * **GPU Driver** : 610.43.02
  * **CUDA UMD** : 13.3
* Software
  * **uv** : 0.13.1
  * **Python** : 3.12.15 (uv 설치)
  * **vLLM** : 0.31.0
  * **PyTorch** : 2.13.0+cu130
  * **Model** : Qwen/Qwen3-14B-AWQ (AWQ 4-bit)

## 2. uv 설치

```shell
$ apt install curl -y
$ wget -qO- https://astral.sh/uv/install.sh | sh
downloading uv 0.13.1 x86_64-unknown-linux-gnu
installing to /root/.local/bin
  uv
  uvx
everything's installed!
$ export PATH=/root/.local/bin:$PATH
```

**uv**를 설치한다. Ubuntu 26.04의 기본 Python은 3.14인데 vLLM은 Python 3.12까지만 지원한다. uv는 다양한 Python Version을 Download하고 가상환경을 구성해 주는 Package Manager로, System Python과 분리된 vLLM 전용 환경을 만들 수 있다.

## 3. Python 가상환경 생성

```shell
$ mkdir -p /root/vllm-test && cd /root/vllm-test
$ uv venv --python 3.12
Downloading cpython-3.12.15-linux-x86_64-gnu (download) (32.7MiB)
 Downloaded cpython-3.12.15-linux-x86_64-gnu (download)
Using CPython 3.12.15
Creating virtual environment at: .venv
$ source .venv/bin/activate
$ python --version
Python 3.12.15
```

작업 Directory에 Python 3.12 기반 가상환경을 생성하고 활성화한다. uv가 CPython 3.12.15 Binary를 자동으로 Download하여 `/root/vllm-test/.venv`에 가상환경을 구성한다.

## 4. vLLM 설치

```shell
$ uv pip install vllm
...
 + torch==2.13.0
 + torchaudio==2.11.0
 + torchvision==0.28.0
 + transformers==5.17.0
 + triton==3.7.1
 + vllm==0.31.0
 + xgrammar==0.2.7
```

**vLLM**을 설치한다. vLLM은 LLM Inference 전용 Serving Engine으로 PagedAttention 기반 KV Cache 관리, Continuous Batching, OpenAI 호환 API 제공 등을 지원한다. 설치 시 `torch`, `triton`, `transformers` 등 GPU Inference에 필요한 Dependency를 함께 설치한다.

```shell
$ python -c 'import vllm, torch; print("vllm", vllm.__version__); print("torch", torch.__version__); print("cuda", torch.cuda.is_available(), torch.cuda.get_device_name(0))'
vllm 0.31.0
torch 2.13.0+cu130
cuda True NVIDIA GeForce RTX 5060 Ti
```

설치된 vLLM, PyTorch Version과 GPU 인식 상태를 확인한다. PyTorch가 CUDA 13.0 Build (`cu130`)로 설치되어 Blackwell 세대의 RTX 5060 Ti가 가진 `sm_120` Compute Capability를 지원한다.

## 5. 모델 서빙

```shell
$ nohup vllm serve Qwen/Qwen3-14B-AWQ \
    --host 0.0.0.0 --port 8000 \
    --max-model-len 8192 \
    --reasoning-parser qwen3 \
    > /root/vllm-test/vllm.log 2>&1 &
```

**Qwen/Qwen3-14B-AWQ** Model을 Serving한다. `vllm serve`는 Hugging Face Hub에서 지정한 Model을 Download하여 OpenAI 호환 API Server를 띄우는 명령어다. 최초 실행 시 Model Weight가 `~/.cache/huggingface/` 아래로 Download된 뒤 GPU에 Load된다.

* `--host` : Listen Address로 `0.0.0.0`을 지정하면 모든 Interface에서 요청을 수신한다.
* `--port` : API Server Port
* `--max-model-len` : 단일 Request가 사용할 수 있는 최대 Context Token 수. 14B 모델이 Weight로 ~9.4GiB를 쓰므로 KV Cache 여유 확보를 위해 8192로 축소한다.
* `--reasoning-parser` : Qwen3는 응답 앞에 `<think>...</think>` 추론 과정을 포함하는 Thinking 모드를 기본 활성화한다. `qwen3` Parser를 지정하면 Thinking Token을 응답의 `message.reasoning` Field로 분리하여 `message.content`는 최종 답변만 담도록 한다.

Qwen3-14B-AWQ는 **AWQ** (Activation-aware Weight Quantization) 방식으로 Weight가 4-bit로 양자화된 Model이다. 16-bit Weight 대비 Weight Memory를 1/4 수준으로 줄여 16GB VRAM GPU에서 14B급 Model을 서빙할 수 있게 한다. vLLM은 Model의 `config.json`에서 `quantization_config`를 확인해 `quantization=auto_awq`로 자동 적용한다.

```text
(APIServer pid=51419) INFO 10-17 20:29:11 [api_utils.py:286] non-default args: {'model_tag': 'Qwen/Qwen3-14B-AWQ', 'host': '0.0.0.0', 'model': 'Qwen/Qwen3-14B-AWQ', 'max_model_len': 8192, 'reasoning_parser': 'qwen3'}
(EngineCore pid=51646) INFO 10-17 20:29:21 [core.py:129] Initializing a V1 LLM engine (v0.31.0) with config: model='Qwen/Qwen3-14B-AWQ', ... dtype=torch.float16, max_seq_len=8192, ... quantization=auto_awq, ... structured_outputs_config=StructuredOutputsConfig(..., reasoning_parser='qwen3', ...), ...
(EngineCore pid=51646) INFO 10-17 20:29:26 [model_runner.py:407] Model loading took 9.44 GiB memory and 4.675787 seconds
(EngineCore pid=51646) INFO 10-17 20:29:39 [gpu_worker.py:692] Available KV cache memory: 3.85 GiB
(EngineCore pid=51646) INFO 10-17 20:29:39 [kv_cache_utils.py:2464] GPU KV cache size: 25,232 tokens, Maximum concurrency for 8,192 tokens per request: 3.08x
INFO:     Application startup complete.
```

`/root/vllm-test/vllm.log`에서 Model Load 결과를 확인한다. Activation은 float16을 쓰면서 Weight는 AWQ 4-bit로 Load되어 9.44GiB를 차지하고, 남은 3.85GiB를 KV Cache로 할당하여 8192 Token Context 기준 약 3.08배 동시성을 확보한다. `Application startup complete` Log 이후 Server가 Request를 받을 준비가 완료된다.

```shell
$ nvidia-smi
...
|   0  NVIDIA GeForce RTX 5060 Ti     Off |   00000000:01:00.0 Off |                  N/A |
|  0%   37C    P8              8W /  180W |   14997MiB /  16311MiB |      0%      Default |
...
|    0   N/A  N/A           51646      C   VLLM::EngineCore                      14546MiB |
```

`nvidia-smi`로 GPU 사용량을 확인한다. `VLLM::EngineCore` Process가 14.5GB VRAM을 점유한 상태로 Idle을 유지한다. Weight (9.44GiB), KV Cache (3.85GiB), CUDA Graph 등 부가 Memory가 합쳐진 양이다.

## 6. 추론 확인

```shell
$ curl -s http://localhost:8000/v1/models | python3 -m json.tool
{
    "object": "list",
    "data": [
        {
            "id": "Qwen/Qwen3-14B-AWQ",
            "object": "model",
            "created": 1792236627,
            "owned_by": "vllm",
            "root": "Qwen/Qwen3-14B-AWQ",
            "parent": null,
            "max_model_len": 8192,
            ...
        }
    ]
}
```

`/v1/models` Endpoint로 Serving 중인 Model 목록을 조회한다. `id` 필드가 요청 시 사용할 Model Name이며, `max_model_len`은 서빙 시 설정한 Context 길이를 반영한다.

```shell
$ curl -s http://localhost:8000/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "Qwen/Qwen3-14B-AWQ",
      "messages": [{"role": "user", "content": "안녕! 너는 어떤 모델이고 뭘 할 수 있는지 2문장으로 알려줘."}],
      "max_tokens": 512,
      "temperature": 0.7
    }' | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(d, ensure_ascii=False, indent=2))'
{
  "id": "chatcmpl-9fdfb90f7591f4d9",
  "object": "chat.completion",
  "created": 1792236676,
  "model": "Qwen/Qwen3-14B-AWQ",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "\n\n안녕하세요! 저는 알리바바 그룹에서 개발한 초대규모 언어 모델인 Qwen입니다. 저는 질문에 답변하거나 텍스트 생성, 번역, 프로그래밍 등 다양한 작업을 수행할 수 있으며, 한국어를 포함한 여러 언어를 지원합니다.",
        "reasoning": "\nOkay, the user greeted me with \"안녕!\" which means \"Hello!\" in Korean. They asked me to introduce myself in two sentences, explaining what model I am and what I can do.\n\nFirst, I need to confirm my identity. I am Qwen, a large-scale language model developed by Alibaba. ...\n",
        ...
      },
      "finish_reason": "stop",
      ...
    }
  ],
  ...
  "usage": {
    "prompt_tokens": 32,
    "total_tokens": 276,
    "completion_tokens": 244,
    "completion_tokens_details": {
      "reasoning_tokens": 174
    }
  }
}
```

OpenAI 호환 `/v1/chat/completions` Endpoint로 Chat 요청을 보내 Qwen3의 응답을 받는다. Request Body의 `model` 필드는 `/v1/models`로 조회한 Model `id`와 동일해야 하며, `messages`에는 OpenAI Chat Completions 규격의 Message 배열을 전달한다.

`--reasoning-parser qwen3` Option 효과로 응답이 `message.content` (최종 답변)와 `message.reasoning` (Thinking 과정)으로 분리된다. OpenAI SDK 기반 Client는 `message.content`만 참조하므로 Thinking Token이 사용자에게 노출되지 않는다. `usage.completion_tokens_details.reasoning_tokens`로 Thinking에 소비된 Token 수를 별도로 확인할 수 있다.

## 7. 참조

* vLLM Documentation : [https://docs.vllm.ai/](https://docs.vllm.ai/)
* uv Documentation : [https://docs.astral.sh/uv/](https://docs.astral.sh/uv/)
* Qwen3-14B-AWQ Model Card : [https://huggingface.co/Qwen/Qwen3-14B-AWQ](https://huggingface.co/Qwen/Qwen3-14B-AWQ)
* AWQ: Activation-aware Weight Quantization : [https://arxiv.org/abs/2306.00978](https://arxiv.org/abs/2306.00978)
* OpenAI Chat Completions API Reference : [https://platform.openai.com/docs/api-reference/chat](https://platform.openai.com/docs/api-reference/chat)
