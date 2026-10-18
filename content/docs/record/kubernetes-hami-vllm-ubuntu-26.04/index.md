---
title: Kubernetes (kubeadm) + HAMi 설치 및 vLLM 모델 서빙 / Ubuntu 26.04 환경
---

## 1. 설치, 실행 환경

설치, 실행 환경은 다음과 같다. 단일 Node가 Control-plane과 Worker 역할을 겸하는 Single-node Cluster로 구성한다.

* Ubuntu 26.04 LTS 64bit, root user
* Nvidia RTX 5060 Ti GPU 16GB
  * **GPU Driver** : 610.43.02
  * **CUDA UMD** : 13.3
* Software
  * **containerd** : 2.2.2
  * **NVIDIA Container Toolkit** : 1.20.1
  * **Kubernetes** : v1.34.12 (kubeadm 설치)
  * **CNI** : Flannel (Pod CIDR `10.244.0.0/16`)
  * **Helm** : v3
  * **HAMi** : Chart 2.10.0 (App v2.10.0)
  * **vLLM Image** : vllm/vllm-openai:latest
  * **Model** : Qwen/Qwen3-14B-AWQ

## 2. containerd + NVIDIA Container Toolkit 설치

```shell
$ apt install -y containerd apt-transport-https ca-certificates gnupg
$ mkdir -p /etc/containerd
$ containerd config default > /etc/containerd/config.toml
$ sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
$ sed -i 's#sandbox_image = ".*"#sandbox_image = "registry.k8s.io/pause:3.10"#' /etc/containerd/config.toml
```

**containerd**를 설치하고 Default Config를 생성한다. `SystemdCgroup = true`로 kubelet의 Cgroup Driver와 일치시키고, `sandbox_image`는 kubeadm이 Pre-pull하는 Pause Image와 Version을 맞춘다.

```shell
$ curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
$ curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list
$ apt update && apt install -y nvidia-container-toolkit
$ nvidia-ctk runtime configure --runtime=containerd --set-as-default
$ systemctl enable --now containerd && systemctl restart containerd
```

**NVIDIA Container Toolkit** APT Repo를 등록하여 `nvidia-container-toolkit`을 설치한다. `nvidia-ctk runtime configure`가 `/etc/containerd/conf.d/99-nvidia.toml`을 생성하여 containerd의 Default Runtime을 `nvidia`로 전환한다. Container 안에서 CUDA Device를 사용하기 위한 Runtime Hook이 자동 주입된다.

## 3. OS 설정

```shell
$ swapoff -a
$ sed -i '/\sswap\s/ s/^/#/' /etc/fstab
```

**Swap**을 Off한다. kubelet은 Memory 압박 상황에서 OOM Kill 동작을 Swap과 함께 쓰는 것을 지양하므로 Swap이 꺼져 있어야 한다.

```shell
$ cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
$ modprobe overlay && modprobe br_netfilter
$ cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
$ sysctl --system
```

Kernel Module `overlay`와 `br_netfilter`를 Load하고 Bridged Traffic이 iptables Rule을 거치도록 Sysctl을 설정한다. `net.ipv4.ip_forward=1`은 Pod간 Traffic Forwarding에 필요하다.

## 4. kubeadm, kubelet, kubectl 설치

```shell
$ mkdir -p -m 755 /etc/apt/keyrings
$ curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
$ echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list
$ apt update && apt install -y kubelet kubeadm kubectl
$ apt-mark hold kubelet kubeadm kubectl
$ systemctl enable --now kubelet
```

Kubernetes 공식 APT Repo에서 **kubelet**, **kubeadm**, **kubectl**을 설치한다. `apt-mark hold`로 Minor Version 자동 Upgrade를 막아 Cluster와 Node Version을 분리하여 관리한다.

```shell
$ kubeadm version -o short && kubelet --version
v1.34.12
Kubernetes v1.34.12
```

Package Version을 확인한다.

## 5. Cluster 초기화

```shell
$ kubeadm init \
    --pod-network-cidr=10.244.0.0/16 \
    --apiserver-advertise-address=192.168.1.32 \
    --cri-socket=unix:///run/containerd/containerd.sock
...
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
...
kubeadm join 192.168.1.32:6443 --token rabogi.suts0px1g5iqn133 \
	--discovery-token-ca-cert-hash sha256:6267f98d3abad7add24e38eec39aa72ebdcb7e7832668800c44bb729d8b22e4d
```

`kubeadm init`으로 Control-plane을 Bootstrap한다. `--pod-network-cidr`는 Flannel의 Default인 `10.244.0.0/16`을 지정하고, `--apiserver-advertise-address`는 Node의 외부 IP를 지정하여 다른 Host가 kube-apiserver에 접근할 수 있도록 한다.

```shell
$ mkdir -p /root/.kube
$ cp -f /etc/kubernetes/admin.conf /root/.kube/config
```

Admin용 Kubeconfig를 복사해 `kubectl`이 Cluster에 접근할 수 있게 한다.

```shell
$ kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
namespace/kube-flannel created
...
daemonset.apps/kube-flannel-ds created
```

**Flannel**을 CNI로 설치한다. Pod가 각자의 IP를 받고 Node 간 Pod-to-Pod 통신이 가능해지며, Flannel DaemonSet이 각 Node에서 VXLAN Overlay Network를 구성한다.

```shell
$ kubectl taint nodes --all node-role.kubernetes.io/control-plane-
node/gpu untainted
```

Control-plane Node에 기본으로 걸리는 `node-role.kubernetes.io/control-plane:NoSchedule` **Taint**를 제거한다. Single-node Cluster에서는 Control-plane이 사용자 Workload도 받아야 하므로 Taint를 걷어내야 한다.

```shell
$ kubectl get nodes -o wide
NAME   STATUS   ROLES           AGE   VERSION    INTERNAL-IP    EXTERNAL-IP   OS-IMAGE           KERNEL-VERSION     CONTAINER-RUNTIME
gpu    Ready    control-plane   20s   v1.34.12   192.168.1.32   <none>        Ubuntu 26.04 LTS   7.0.0-38-generic   containerd://2.2.2
```

Node Status가 `Ready`로 전환되고 containerd Runtime이 인식되었는지 확인한다.

## 6. Helm + HAMi 설치

```shell
$ curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
$ helm version --short
v3.19.0+g3d8990f
```

**Helm**을 설치한다. HAMi는 공식 Helm Chart로 배포된다.

```shell
$ kubectl label node gpu gpu=on --overwrite
node/gpu labeled
```

HAMi가 관리할 GPU Node에 **`gpu=on`** Label을 부착한다. HAMi Device Plugin은 이 Label이 있는 Node에서만 동작하여 GPU 자원을 광고한다.

```shell
$ helm repo add hami-charts https://project-hami.github.io/HAMi/
$ helm repo update
$ helm install hami hami-charts/hami --version 2.10.0 -n kube-system
NAME: hami
LAST DEPLOYED: ...
NAMESPACE: kube-system
STATUS: deployed
...
```

**HAMi** (Heterogeneous AI computing Virtualization middleware)는 Nvidia Container Toolkit 위에서 GPU를 Pod간 Memory·Core 단위로 분할해 공유할 수 있게 하는 Scheduler Extension이다. `hami-scheduler`는 kube-scheduler Framework에 Webhook으로 끼어들어 GPU 요구량과 Memory 요구량을 함께 고려하고, `hami-device-plugin`은 각 GPU Node에서 가상화된 GPU 자원을 광고한다.

```shell
$ kubectl -n kube-system get pods -l app.kubernetes.io/instance=hami -o wide
NAME                             READY   STATUS    RESTARTS   AGE   IP           NODE   NOMINATED NODE   READINESS GATES
hami-device-plugin-4q4tm         2/2     Running   0          23s   10.244.0.5   gpu    <none>           <none>
hami-scheduler-55cc79689-lv8l6   2/2     Running   0          23s   10.244.0.6   gpu    <none>           <none>
```

HAMi Component가 모두 Running 상태인지 확인한다. `hami-device-plugin`은 DaemonSet이고 `hami-scheduler`는 Scheduler + Webhook Sidecar 두 Container로 구성된다.

```shell
$ kubectl describe node gpu | grep -A 10 'Capacity:'
Capacity:
  cpu:                12
  ephemeral-storage:  959218776Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             31975692Ki
  nvidia.com/gpu:     10
  pods:               110
```

Node Capacity에 **`nvidia.com/gpu: 10`**이 광고된다. 물리 GPU 1장을 HAMi가 10개 Virtual Slot으로 분할하는 Default 설정이다. `nvidia.com/gpumem` (MiB)과 `nvidia.com/gpucores` (%)로 Slot별 Memory·Compute를 세분화해 요청할 수 있다.

## 7. vLLM Pod 배포

```yaml {caption="[File 1] qwen3-14b-awq.yaml", linenos=table}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: qwen3-14b-awq
  namespace: default
  labels:
    app: qwen3-14b-awq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: qwen3-14b-awq
  template:
    metadata:
      labels:
        app: qwen3-14b-awq
    spec:
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        args:
          - "--model=Qwen/Qwen3-14B-AWQ"
          - "--max-model-len=8192"
          - "--reasoning-parser=qwen3"
          - "--host=0.0.0.0"
          - "--port=8000"
        ports:
        - containerPort: 8000
          name: http
        resources:
          limits:
            nvidia.com/gpu: 1
            nvidia.com/gpumem: 15000
        volumeMounts:
        - name: hf-cache
          mountPath: /root/.cache/huggingface
        - name: shm
          mountPath: /dev/shm
        readinessProbe:
          httpGet:
            path: /v1/models
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 60
      volumes:
      - name: hf-cache
        hostPath:
          path: /root/.cache/huggingface
          type: Directory
      - name: shm
        emptyDir:
          medium: Memory
          sizeLimit: 4Gi
---
apiVersion: v1
kind: Service
metadata:
  name: qwen3-14b-awq
  namespace: default
spec:
  type: NodePort
  selector:
    app: qwen3-14b-awq
  ports:
  - name: http
    port: 8000
    targetPort: 8000
    nodePort: 30800
```

**vLLM** OpenAI 호환 Server를 Qwen3-14B-AWQ Model과 함께 Pod로 띄우기 위한 Manifest다. 주요 포인트는 다음과 같다.

* `resources.limits` : `nvidia.com/gpu: 1`로 Virtual Slot 1개를, `nvidia.com/gpumem: 15000`으로 15000 MiB VRAM을 요청한다. HAMi가 `gpumem` 요구를 보고 KV Cache 여유가 충분한 Slot을 할당하며, Container 안에서는 VRAM 상한이 15 GiB로 제한된다.
* `volumes.hf-cache` : Host의 `/root/.cache/huggingface`를 `hostPath`로 Mount하여 이미 Download되어 있는 Model Weight를 재사용한다. 처음부터 Download하는 경우에는 PVC로 바꿔도 된다.
* `volumes.shm` : vLLM이 Worker Process간 IPC에 Shared Memory를 쓰므로 Default 64 MiB로는 부족하다. `emptyDir medium=Memory`로 4 GiB Shared Memory를 할당한다.
* **Deployment/Service 이름을 `qwen3-14b-awq`로 지정** : Service 이름이 `vllm`이면 Kubernetes가 Pod에 Service Link 환경변수 (`VLLM_PORT=tcp://10.x.x.x:8000`)를 자동 주입하는데, 이 값이 vLLM의 자체 Config 환경변수 `VLLM_PORT`와 충돌해 `ValueError: VLLM_PORT 'tcp://...' appears to be a URI`로 Pod가 Crash한다. Service 이름을 Model 이름 기반으로 바꿔 환경변수 Prefix (`QWEN3_14B_AWQ_*`)를 분리한다.

```shell
$ kubectl apply -f qwen3-14b-awq.yaml
deployment.apps/qwen3-14b-awq created
service/qwen3-14b-awq created
```

Manifest를 적용한다.

```shell
$ kubectl get pods -l app=qwen3-14b-awq -o wide
NAME                             READY   STATUS    RESTARTS   AGE    IP           NODE
qwen3-14b-awq-84dfd5c495-nw9rg   1/1     Running   0          3m2s   10.244.0.9   gpu
$ kubectl get svc qwen3-14b-awq
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
qwen3-14b-awq   NodePort    10.106.249.208   <none>        8000:30800/TCP   3m
```

Pod가 `1/1 Running`이 되고 Service가 NodePort `30800`을 통해 외부로 노출된 상태를 확인한다. Image Pull에 약 4분 (약 9 GiB), Model Load에 약 1분이 소요된다.

```shell
$ kubectl describe node gpu | grep -A 7 'Allocated resources:'
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests    Limits
  --------           --------    ------
  cpu                950m (7%)   0 (0%)
  memory             290Mi (0%)  340Mi (1%)
  nvidia.com/gpu     1           1
```

Node의 `Allocated resources`에서 `nvidia.com/gpu: 1`이 사용 중임을 확인한다. HAMi가 요청한 Slot을 Pod에 바인딩한 결과다.

```shell
$ nvidia-smi --query-gpu=memory.used,memory.free --format=csv
memory.used [MiB], memory.free [MiB]
13254 MiB, 2632 MiB
```

Host의 `nvidia-smi`에서도 vLLM Pod가 ~13.2 GiB VRAM을 점유한 상태를 확인한다. HAMi가 요청한 15 GiB 상한 안에서 실제 사용량이 유지된다.

## 8. 추론 확인

```shell
$ curl -s http://192.168.1.32:30800/v1/models | python3 -m json.tool
{
    "object": "list",
    "data": [
        {
            "id": "Qwen/Qwen3-14B-AWQ",
            "object": "model",
            ...
            "max_model_len": 8192,
            ...
        }
    ]
}
```

Node IP (`192.168.1.32`) + NodePort (`30800`)로 외부에서 `/v1/models`를 조회한다.

```shell
$ curl -s http://192.168.1.32:30800/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "Qwen/Qwen3-14B-AWQ",
      "messages": [{"role": "user", "content": "안녕! 너는 어떤 모델이고 뭘 할 수 있는지 2문장으로 알려줘."}],
      "max_tokens": 512,
      "temperature": 0.7
    }' | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(d, ensure_ascii=False, indent=2))'
{
  "id": "chatcmpl-930e7923fbfe14fc",
  "object": "chat.completion",
  "created": 1792247114,
  "model": "Qwen/Qwen3-14B-AWQ",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "\n\n안녕하세요! 저는 Qwen으로, 알리바바 클라우드에서 개발한 대규모 언어 모델입니다. 저는 질문에 답변하거나, 글을 작성하거나, 다양한 언어로 대화를 도와드릴 수 있습니다.",
        "reasoning": "\nOkay, the user greeted me with ...\n",
        ...
      },
      "finish_reason": "stop",
      ...
    }
  ],
  ...
  "usage": {
    "prompt_tokens": 32,
    "total_tokens": 172,
    "completion_tokens": 140,
    "completion_tokens_details": {
      "reasoning_tokens": 81
    }
  }
}
```

OpenAI 호환 `/v1/chat/completions` Endpoint로 Chat 요청을 보내 Qwen3-14B-AWQ의 응답을 받는다. `--reasoning-parser qwen3` Option이 Pod Args에도 적용되어 있어 `message.content`와 `message.reasoning`이 분리되어 돌아온다.

## 9. 참조

* kubeadm Installation : [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
* Flannel : [https://github.com/flannel-io/flannel](https://github.com/flannel-io/flannel)
* NVIDIA Container Toolkit : [https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
* HAMi : [https://github.com/Project-HAMi/HAMi](https://github.com/Project-HAMi/HAMi)
* vLLM OpenAI Docker Image : [https://hub.docker.com/r/vllm/vllm-openai](https://hub.docker.com/r/vllm/vllm-openai)
* Qwen3-14B-AWQ Model Card : [https://huggingface.co/Qwen/Qwen3-14B-AWQ](https://huggingface.co/Qwen/Qwen3-14B-AWQ)
