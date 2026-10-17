---
title: Kubernetes (kubeadm) + HAMi Installation and vLLM Model Serving / Ubuntu 26.04 Environment
---

## 1. Installation and Runtime Environment

The installation and runtime environment is as follows. The cluster is configured as a Single-node Cluster where one Node serves as both Control-plane and Worker.

* Ubuntu 26.04 LTS 64bit, root user
* Nvidia RTX 5060 Ti GPU 16GB
  * **GPU Driver** : 610.43.02
  * **CUDA UMD** : 13.3
* Software
  * **containerd** : 2.2.2
  * **NVIDIA Container Toolkit** : 1.20.1
  * **Kubernetes** : v1.34.12 (installed with kubeadm)
  * **CNI** : Flannel (Pod CIDR `10.244.0.0/16`)
  * **Helm** : v3
  * **HAMi** : latest (hami-charts Repo)
  * **vLLM Image** : vllm/vllm-openai:latest
  * **Model** : Qwen/Qwen3-14B-AWQ

## 2. containerd + NVIDIA Container Toolkit Installation

```shell
$ apt install -y containerd apt-transport-https ca-certificates gnupg
$ mkdir -p /etc/containerd
$ containerd config default > /etc/containerd/config.toml
$ sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
$ sed -i 's#sandbox_image = ".*"#sandbox_image = "registry.k8s.io/pause:3.10"#' /etc/containerd/config.toml
```

Install **containerd** and generate the Default Config. `SystemdCgroup = true` aligns with the kubelet's Cgroup Driver, and `sandbox_image` is matched to the Pause Image Version that kubeadm pre-pulls.

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

Register the **NVIDIA Container Toolkit** APT Repo and install `nvidia-container-toolkit`. `nvidia-ctk runtime configure` generates `/etc/containerd/conf.d/99-nvidia.toml` to switch containerd's Default Runtime to `nvidia`. The Runtime Hook needed to use CUDA Devices inside Containers is injected automatically.

## 3. OS Configuration

```shell
$ swapoff -a
$ sed -i '/\sswap\s/ s/^/#/' /etc/fstab
```

Disable **Swap**. The kubelet avoids combining OOM Kill behavior with Swap under Memory pressure, so Swap must be off.

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

Load the Kernel Modules `overlay` and `br_netfilter`, and set Sysctl so that Bridged Traffic passes through iptables Rules. `net.ipv4.ip_forward=1` is required for Pod-to-Pod Traffic Forwarding.

## 4. kubeadm, kubelet, kubectl Installation

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

Install **kubelet**, **kubeadm**, and **kubectl** from the official Kubernetes APT Repo. `apt-mark hold` prevents automatic Minor Version Upgrades so Cluster and Node Versions can be managed separately.

```shell
$ kubeadm version -o short && kubelet --version
v1.34.12
Kubernetes v1.34.12
```

Verify the installed Package Versions.

## 5. Cluster Initialization

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

Bootstrap the Control-plane with `kubeadm init`. `--pod-network-cidr` is set to Flannel's Default `10.244.0.0/16`, and `--apiserver-advertise-address` is set to the Node's external IP so other Hosts can reach the kube-apiserver.

```shell
$ mkdir -p /root/.kube
$ cp -f /etc/kubernetes/admin.conf /root/.kube/config
```

Copy the Admin Kubeconfig so `kubectl` can access the Cluster.

```shell
$ kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
namespace/kube-flannel created
...
daemonset.apps/kube-flannel-ds created
```

Install **Flannel** as the CNI. Pods obtain their own IPs and Pod-to-Pod communication across Nodes becomes possible; the Flannel DaemonSet sets up a VXLAN Overlay Network on each Node.

```shell
$ kubectl taint nodes --all node-role.kubernetes.io/control-plane-
node/gpu untainted
```

Remove the `node-role.kubernetes.io/control-plane:NoSchedule` **Taint** attached to Control-plane Nodes by default. In a Single-node Cluster, the Control-plane also has to accept user Workloads, so the Taint must be removed.

```shell
$ kubectl get nodes -o wide
NAME   STATUS   ROLES           AGE   VERSION    INTERNAL-IP    EXTERNAL-IP   OS-IMAGE           KERNEL-VERSION     CONTAINER-RUNTIME
gpu    Ready    control-plane   20s   v1.34.12   192.168.1.32   <none>        Ubuntu 26.04 LTS   7.0.0-38-generic   containerd://2.2.2
```

Confirm that the Node Status has transitioned to `Ready` and the containerd Runtime is recognized.

## 6. Helm + HAMi Installation

```shell
$ curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
$ helm version --short
v3.19.0+g3d8990f
```

Install **Helm**. HAMi is distributed as an official Helm Chart.

```shell
$ kubectl label node gpu gpu=on --overwrite
node/gpu labeled
```

Attach the **`gpu=on`** Label to the GPU Node that HAMi will manage. The HAMi Device Plugin only operates on Nodes with this Label and advertises GPU resources from those Nodes.

```shell
$ helm repo add hami-charts https://project-hami.github.io/HAMi/
$ helm repo update
$ helm install hami hami-charts/hami -n kube-system
NAME: hami
LAST DEPLOYED: ...
NAMESPACE: kube-system
STATUS: deployed
...
```

**HAMi** (Heterogeneous AI computing Virtualization middleware) is a Scheduler Extension that sits on top of the Nvidia Container Toolkit and allows a GPU to be shared across Pods on a per-Memory and per-Core basis. `hami-scheduler` hooks into the kube-scheduler Framework as a Webhook to consider both GPU count and Memory requests, and `hami-device-plugin` advertises virtualized GPU resources on each GPU Node.

```shell
$ kubectl -n kube-system get pods -l app.kubernetes.io/instance=hami -o wide
NAME                             READY   STATUS    RESTARTS   AGE   IP           NODE   NOMINATED NODE   READINESS GATES
hami-device-plugin-4q4tm         2/2     Running   0          23s   10.244.0.5   gpu    <none>           <none>
hami-scheduler-55cc79689-lv8l6   2/2     Running   0          23s   10.244.0.6   gpu    <none>           <none>
```

Verify that all HAMi Components are in Running state. `hami-device-plugin` is a DaemonSet, and `hami-scheduler` consists of two Containers (Scheduler + Webhook Sidecar).

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

**`nvidia.com/gpu: 10`** is advertised in the Node Capacity. This is HAMi's Default setting that splits one physical GPU into 10 Virtual Slots. `nvidia.com/gpumem` (MiB) and `nvidia.com/gpucores` (%) can be requested in addition to subdivide per-Slot Memory and Compute.

## 7. vLLM Pod Deployment

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

Manifest for launching the **vLLM** OpenAI-compatible Server with the Qwen3-14B-AWQ Model as a Pod. The main points are as follows.

* `resources.limits` : Request 1 Virtual Slot via `nvidia.com/gpu: 1` and 15000 MiB of VRAM via `nvidia.com/gpumem: 15000`. HAMi uses the `gpumem` request to allocate a Slot with sufficient KV Cache room, and inside the Container the VRAM cap is enforced at 15 GiB.
* `volumes.hf-cache` : Mount the Host's `/root/.cache/huggingface` as a `hostPath` to reuse Model Weights already downloaded on the Host. For a fresh download, replace this with a PVC.
* `volumes.shm` : vLLM uses Shared Memory for IPC between Worker Processes, and the Default 64 MiB is insufficient. Allocate 4 GiB of Shared Memory using `emptyDir medium=Memory`.
* **Deployment/Service name set to `qwen3-14b-awq`** : If the Service name is `vllm`, Kubernetes auto-injects Service Link environment variables into the Pod (`VLLM_PORT=tcp://10.x.x.x:8000`), and this collides with vLLM's own `VLLM_PORT` config environment variable, causing the Pod to Crash with `ValueError: VLLM_PORT 'tcp://...' appears to be a URI`. The Service name is changed to one based on the Model name so that the auto-injected environment variable Prefix (`QWEN3_14B_AWQ_*`) does not collide.

```shell
$ kubectl apply -f qwen3-14b-awq.yaml
deployment.apps/qwen3-14b-awq created
service/qwen3-14b-awq created
```

Apply the Manifest.

```shell
$ kubectl get pods -l app=qwen3-14b-awq -o wide
NAME                             READY   STATUS    RESTARTS   AGE    IP           NODE
qwen3-14b-awq-84dfd5c495-nw9rg   1/1     Running   0          3m2s   10.244.0.9   gpu
$ kubectl get svc qwen3-14b-awq
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
qwen3-14b-awq   NodePort    10.106.249.208   <none>        8000:30800/TCP   3m
```

Verify that the Pod becomes `1/1 Running` and the Service is exposed externally via NodePort `30800`. Image Pull takes about 4 minutes (about 9 GiB) and Model Load takes about 1 minute.

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

In the Node's `Allocated resources`, confirm that `nvidia.com/gpu: 1` is in use. HAMi has bound the requested Slot to the Pod.

```shell
$ nvidia-smi --query-gpu=memory.used,memory.free --format=csv
memory.used [MiB], memory.free [MiB]
13254 MiB, 2632 MiB
```

The Host's `nvidia-smi` also shows the vLLM Pod occupying ~13.2 GiB of VRAM. Actual usage stays within the 15 GiB cap requested through HAMi.

## 8. Inference Verification

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

Query `/v1/models` from outside using the Node IP (`192.168.1.32`) + NodePort (`30800`).

```shell
$ curl -s http://192.168.1.32:30800/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "Qwen/Qwen3-14B-AWQ",
      "messages": [{"role": "user", "content": "Hi! Tell me in two sentences what model you are and what you can do."}],
      "max_tokens": 512,
      "temperature": 0.7
    }' | python3 -m json.tool
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
        "content": "\n\nI'm Qwen, a large-scale language model developed by Alibaba Cloud. I can answer questions, generate text, help with programming, and support conversations in many languages.",
        "reasoning": "\nOkay, the user greeted me and asked me to introduce myself in two sentences ...\n",
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

Send a Chat request to the OpenAI-compatible `/v1/chat/completions` Endpoint and receive the Qwen3-14B-AWQ response. The `--reasoning-parser qwen3` Option is passed to the Pod Args as well, so `message.content` and `message.reasoning` are returned separately.

## 9. References

* kubeadm Installation : [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
* Flannel : [https://github.com/flannel-io/flannel](https://github.com/flannel-io/flannel)
* NVIDIA Container Toolkit : [https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
* HAMi : [https://github.com/Project-HAMi/HAMi](https://github.com/Project-HAMi/HAMi)
* vLLM OpenAI Docker Image : [https://hub.docker.com/r/vllm/vllm-openai](https://hub.docker.com/r/vllm/vllm-openai)
* Qwen3-14B-AWQ Model Card : [https://huggingface.co/Qwen/Qwen3-14B-AWQ](https://huggingface.co/Qwen/Qwen3-14B-AWQ)
