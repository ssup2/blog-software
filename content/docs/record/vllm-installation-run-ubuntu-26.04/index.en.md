---
title: vLLM Installation and Model Serving / Ubuntu 26.04 Environment
---

## 1. Installation and Runtime Environment

The installation and runtime environment is as follows.

* Ubuntu 26.04 LTS 64bit, root user
* Nvidia RTX 5060 Ti GPU 16GB
  * **GPU Driver** : 610.43.02
  * **CUDA UMD** : 13.3
* Software
  * **uv** : 0.13.1
  * **Python** : 3.12.15 (installed by uv)
  * **vLLM** : 0.31.0
  * **PyTorch** : 2.13.0+cu130
  * **Model** : Qwen/Qwen3-14B-AWQ (AWQ 4-bit)

## 2. uv Installation

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

Install **uv**. The default Python on Ubuntu 26.04 is 3.14, but vLLM only supports up to Python 3.12. uv is a Package Manager that downloads various Python Versions and sets up virtual environments, so a vLLM-dedicated environment separated from the System Python can be built.

## 3. Python Virtual Environment Setup

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

Create and activate a Python 3.12-based virtual environment in the working Directory. uv automatically downloads the CPython 3.12.15 Binary and sets up the virtual environment at `/root/vllm-test/.venv`.

## 4. vLLM Installation

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

Install **vLLM**. vLLM is an LLM Inference-dedicated Serving Engine that supports PagedAttention-based KV Cache management, Continuous Batching, OpenAI-compatible API, etc. During installation, Dependencies required for GPU Inference such as `torch`, `triton`, and `transformers` are installed together.

```shell
$ python -c 'import vllm, torch; print("vllm", vllm.__version__); print("torch", torch.__version__); print("cuda", torch.cuda.is_available(), torch.cuda.get_device_name(0))'
vllm 0.31.0
torch 2.13.0+cu130
cuda True NVIDIA GeForce RTX 5060 Ti
```

Verify the installed vLLM, PyTorch Versions and GPU recognition status. PyTorch is installed as a CUDA 13.0 Build (`cu130`), supporting the `sm_120` Compute Capability of the Blackwell-generation RTX 5060 Ti.

## 5. Model Serving

```shell
$ nohup vllm serve Qwen/Qwen3-14B-AWQ \
    --host 0.0.0.0 --port 8000 \
    --max-model-len 8192 \
    --reasoning-parser qwen3 \
    > /root/vllm-test/vllm.log 2>&1 &
```

Serve the **Qwen/Qwen3-14B-AWQ** Model. `vllm serve` is a command that downloads the specified Model from the Hugging Face Hub and launches an OpenAI-compatible API Server. On the first run, Model Weights are downloaded under `~/.cache/huggingface/` and then loaded onto the GPU.

* `--host` : Listen Address. Specifying `0.0.0.0` accepts requests on all Interfaces.
* `--port` : API Server Port.
* `--max-model-len` : Maximum Context Token count a single Request can use. Since the 14B model consumes ~9.4 GiB of Weight Memory, this is reduced to 8192 to secure KV Cache headroom.
* `--reasoning-parser` : Qwen3 has Thinking mode enabled by default, which prepends `<think>...</think>` reasoning content to the response. Specifying the `qwen3` Parser splits the Thinking Tokens into the response's `message.reasoning` Field so that `message.content` only contains the final answer.

Qwen3-14B-AWQ is a Model whose Weights are quantized to 4-bit using **AWQ** (Activation-aware Weight Quantization). It reduces Weight Memory to about 1/4 compared to 16-bit Weights, enabling 14B-class Models to be served on a 16GB VRAM GPU. vLLM checks `quantization_config` in the Model's `config.json` and automatically applies `quantization=auto_awq`.

```text
(APIServer pid=51419) INFO 10-17 20:29:11 [api_utils.py:286] non-default args: {'model_tag': 'Qwen/Qwen3-14B-AWQ', 'host': '0.0.0.0', 'model': 'Qwen/Qwen3-14B-AWQ', 'max_model_len': 8192, 'reasoning_parser': 'qwen3'}
(EngineCore pid=51646) INFO 10-17 20:29:21 [core.py:129] Initializing a V1 LLM engine (v0.31.0) with config: model='Qwen/Qwen3-14B-AWQ', ... dtype=torch.float16, max_seq_len=8192, ... quantization=auto_awq, ... structured_outputs_config=StructuredOutputsConfig(..., reasoning_parser='qwen3', ...), ...
(EngineCore pid=51646) INFO 10-17 20:29:26 [model_runner.py:407] Model loading took 9.44 GiB memory and 4.675787 seconds
(EngineCore pid=51646) INFO 10-17 20:29:39 [gpu_worker.py:692] Available KV cache memory: 3.85 GiB
(EngineCore pid=51646) INFO 10-17 20:29:39 [kv_cache_utils.py:2464] GPU KV cache size: 25,232 tokens, Maximum concurrency for 8,192 tokens per request: 3.08x
INFO:     Application startup complete.
```

Check the Model Load result in `/root/vllm-test/vllm.log`. While Activations use float16, Weights are loaded as AWQ 4-bit taking 9.44 GiB, and the remaining 3.85 GiB is allocated to the KV Cache, securing about 3.08x concurrency for an 8192 Token Context per Request. The Server becomes ready to receive Requests after the `Application startup complete` Log.

```shell
$ nvidia-smi
...
|   0  NVIDIA GeForce RTX 5060 Ti     Off |   00000000:01:00.0 Off |                  N/A |
|  0%   37C    P8              8W /  180W |   14997MiB /  16311MiB |      0%      Default |
...
|    0   N/A  N/A           51646      C   VLLM::EngineCore                      14546MiB |
```

Check GPU usage with `nvidia-smi`. The `VLLM::EngineCore` Process holds 14.5 GB of VRAM while remaining idle. This is the sum of Weights (9.44 GiB), KV Cache (3.85 GiB), CUDA Graph, and other auxiliary Memory.

## 6. Inference Verification

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

Query the list of Models being served via the `/v1/models` Endpoint. The `id` field is the Model Name to use in requests, and `max_model_len` reflects the Context length configured at serving time.

```shell
$ curl -s http://localhost:8000/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "Qwen/Qwen3-14B-AWQ",
      "messages": [{"role": "user", "content": "Hi! Tell me in two sentences what model you are and what you can do."}],
      "max_tokens": 512,
      "temperature": 0.7
    }' | python3 -m json.tool
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
        "content": "\n\nI'm Qwen, a large-scale language model developed by Alibaba Cloud. I can answer questions, generate text, translate between languages, help with programming, and support conversations in many languages including Korean and English.",
        "reasoning": "\nOkay, the user greeted me and asked me to introduce myself in two sentences, explaining what model I am and what I can do. ...\n",
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

Send a Chat request to the OpenAI-compatible `/v1/chat/completions` Endpoint and receive the response from Qwen3. The `model` field in the Request Body must match the Model `id` returned by `/v1/models`, and `messages` carries the Message array in the OpenAI Chat Completions format.

Thanks to the `--reasoning-parser qwen3` Option, the response is split into `message.content` (the final answer) and `message.reasoning` (the Thinking trace). OpenAI SDK-based Clients only read `message.content`, so Thinking Tokens are not exposed to users. The `usage.completion_tokens_details.reasoning_tokens` field reports the number of Tokens spent on Thinking separately.

## 7. References

* vLLM Documentation : [https://docs.vllm.ai/](https://docs.vllm.ai/)
* uv Documentation : [https://docs.astral.sh/uv/](https://docs.astral.sh/uv/)
* Qwen3-14B-AWQ Model Card : [https://huggingface.co/Qwen/Qwen3-14B-AWQ](https://huggingface.co/Qwen/Qwen3-14B-AWQ)
* AWQ: Activation-aware Weight Quantization : [https://arxiv.org/abs/2306.00978](https://arxiv.org/abs/2306.00978)
* OpenAI Chat Completions API Reference : [https://platform.openai.com/docs/api-reference/chat](https://platform.openai.com/docs/api-reference/chat)
