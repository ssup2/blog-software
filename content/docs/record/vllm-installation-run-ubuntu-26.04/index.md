---
title: vLLM 설치 및 모델 서빙 / Ubuntu 26.04 환경
draft: true
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
  * **Model** : Qwen/Qwen2.5-1.5B-Instruct

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
$ nohup vllm serve Qwen/Qwen2.5-1.5B-Instruct \
    --host 0.0.0.0 --port 8000 \
    --max-model-len 4096 \
    > /root/vllm-test/vllm.log 2>&1 &
```

**Qwen/Qwen2.5-1.5B-Instruct** Model을 Serving한다. `vllm serve`는 Hugging Face Hub에서 지정한 Model을 Download하여 OpenAI 호환 API Server를 띄우는 명령어다. 최초 실행 시 Model Weight가 `~/.cache/huggingface/` 아래로 Download된 뒤 GPU에 Load된다.

* `--host` : Listen Address로 `0.0.0.0`을 지정하면 모든 Interface에서 요청을 수신한다.
* `--port` : API Server Port
* `--max-model-len` : 단일 Request가 사용할 수 있는 최대 Context Token 수. RTX 5060 Ti 16GB VRAM에서 KV Cache 여유를 확보하기 위해 4096으로 축소한다.

```text
(EngineCore pid=18579) INFO 10-17 01:22:27 [model_runner.py:407] Model loading took 2.98 GiB memory and 55.235320 seconds
(EngineCore pid=18579) INFO 10-17 01:23:21 [gpu_worker.py:692] Available KV cache memory: 10.23 GiB
(EngineCore pid=18579) INFO 10-17 01:23:21 [kv_cache_utils.py:2464] GPU KV cache size: 383,216 tokens, Maximum concurrency for 4,096 tokens per request: 93.56x
INFO:     Application startup complete.
```

`/root/vllm-test/vllm.log`에서 Model Load 결과를 확인한다. Model Weight는 bfloat16으로 2.98GiB를 차지하고, KV Cache에는 10.23GiB가 할당되어 4096 Token Request 기준 최대 93.56배 동시성을 확보한다. `Application startup complete` Log 이후 Server가 Request를 받을 준비가 완료된다.

```shell
$ nvidia-smi
...
|   0  NVIDIA GeForce RTX 5060 Ti     Off |   00000000:01:00.0 Off |                  N/A |
|  0%   32C    P1             20W /  180W |   14811MiB /  16311MiB |      0%      Default |
...
|    0   N/A  N/A           18579      C   VLLM::EngineCore                      14360MiB |
```

`nvidia-smi`로 GPU 사용량을 확인한다. `VLLM::EngineCore` Process가 14.36GB VRAM을 점유한 상태로 Idle을 유지한다. Weight (2.98GiB)와 KV Cache (10.23GiB), CUDA Graph 등 부가 Memory가 합쳐진 양이다.

## 6. 추론 확인

```shell
$ curl -s http://localhost:8000/v1/models | python3 -m json.tool
{
    "object": "list",
    "data": [
        {
            "id": "Qwen/Qwen2.5-1.5B-Instruct",
            "object": "model",
            "created": 1792167980,
            "owned_by": "vllm",
            "root": "Qwen/Qwen2.5-1.5B-Instruct",
            "parent": null,
            "max_model_len": 4096,
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
      "model": "Qwen/Qwen2.5-1.5B-Instruct",
      "messages": [{"role": "user", "content": "안녕! 너는 어떤 모델이고 뭘 할 수 있는지 2문장으로 알려줘."}],
      "max_tokens": 128,
      "temperature": 0.7
    }' | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(d, ensure_ascii=False, indent=2))'
{
  "id": "chatcmpl-b4d221d94865f355",
  "object": "chat.completion",
  "created": 1792168083,
  "model": "Qwen/Qwen2.5-1.5B-Instruct",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "저는 Qwen라는 AI 언어 모델입니다. 다양한 주제에 대해 대화를 나누고 정보 검색, 질문 응답 등 다양한 작업을 수행할 수 있습니다.",
        ...
      },
      "finish_reason": "stop",
      ...
    }
  ],
  ...
  "usage": {
    "prompt_tokens": 53,
    "total_tokens": 94,
    "completion_tokens": 41
  }
}
```

OpenAI 호환 `/v1/chat/completions` Endpoint로 Chat 요청을 보내 Qwen2.5의 응답을 받는다. Request Body의 `model` 필드는 `/v1/models`로 조회한 Model `id`와 동일해야 하며, `messages`에는 OpenAI Chat Completions 규격의 Message 배열을 전달한다. 응답의 `usage` 필드로 입력/출력 Token 수를 확인할 수 있다.

## 7. 참조

* vLLM Documentation : [https://docs.vllm.ai/](https://docs.vllm.ai/)
* uv Documentation : [https://docs.astral.sh/uv/](https://docs.astral.sh/uv/)
* Qwen2.5-1.5B-Instruct Model Card : [https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct)
* OpenAI Chat Completions API Reference : [https://platform.openai.com/docs/api-reference/chat](https://platform.openai.com/docs/api-reference/chat)
