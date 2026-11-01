---
title: Kubernetes HAMi
draft: true
---

## 1. Kubernetes HAMi

{{< figure caption="[Figure 1] HAMi Architecture" src="images/hami-architecture.png" width="900px" >}}

**HAMi** (Heterogeneous AI Computing Virtualization Middleware)는 Kubernetes 환경에서 GPU, NPU 같은 AI 가속기를 가상화하여 하나의 가속기를 다수의 Pod이 공유할 수 있도록 하는 CNCF의 Middleware이다. Kubernetes의 Device Plugin 방식은 가속기를 개수 단위로만 할당할 수 있지만, HAMi는 Device Plugin 방식 위에서 Memory 크기 제한과 연산 Core 사용률 제한을 제공하여 하나의 가속기를 조각 단위로 나누어 할당한다.

[Figure 1]은 HAMi의 Architecture를 나타내고 있다. HAMi는 다음의 세 가지 요소로 구성된다.

* **hami-scheduler** : Deployment를 통해서 동작하며, 하나의 Pod 안에서 kube-scheduler Container와 Scheduler Extender Container가 함께 동작한다. 가속기를 요청하는 Pod의 Scheduler를 hami-scheduler로 변경하는 Mutating Webhook도 Scheduler Extender가 함께 제공한다. 모든 종류의 가속기가 하나의 hami-scheduler를 공유하며, 가속기별 Scheduling 동작은 hami-scheduler 내부의 가속기별 Package로 구현되어 있다.
* **Device Plugin** : DaemonSet을 통해서 가속기가 존재하는 Node에서 동작하며, 가속기를 kubelet에 등록하고 Container에 할당하는 역할을 수행한다. 가속기에 따라서 HAMi 설치에 포함된 Device Plugin, HAMi가 별도로 제공하는 Device Plugin, 또는 가속기 제조사가 제공하는 Device Plugin을 이용한다.
* **격리 계층** : 조각 단위로 할당된 가속기가 제한을 초과하여 사용되지 않도록 강제하는 계층이다. HAMi 프로토콜 Device Plugin은 다음의 두 가지 수준으로 격리를 수행하며, 계층이 Hardware에 가까울수록 격리는 강해지지만 분할의 유연성은 줄어든다.
  * **Library 수준 격리** : Container에 주입된 격리 Library가 User 공간에서 가속기 API 호출을 가로채서 Memory 할당과 Core 사용을 제한한다. 제한이 API 호출 시점에 이루어지기 때문에 Memory 크기와 Core 사용률을 임의의 값으로 지정할 수 있다.
  * **Hardware 수준 격리** : 가속기 자체를 Hardware 수준에서 분할하여 가상 가속기를 생성한다. Hardware는 제조사가 Chip마다 미리 정의한 가상화 Template 구성으로만 분할될 수 있기 때문에, Pod가 요청한 Memory 크기를 수용하는 가장 작은 Template이 선택되어 가상 가속기가 생성된다. 격리가 가장 확실한 대신 요청한 크기가 Template 크기로 올림되기 때문에 Template보다 세밀한 분할은 불가능하다.

이처럼 HAMi는 Scheduling 계층은 공통으로 유지하면서 격리 계층은 가속기별 구현에 위임하는 구조를 갖는다. 세 계층의 구분은 HAMi에 국한되지 않고 일반적인 가속기 가상화 기법에도 그대로 적용된다.

{{< table caption="[Table 1] HAMi 프로토콜 Device Plugin이 제공되는 주요 가속기" >}}
| 가속기 | Resource 이름 | Memory / Core 제한 | 격리 계층 | Device Plugin |
|---|---|---|---|---|
| NVIDIA GPU | `nvidia.com/gpu`, `nvidia.com/gpumem`, `nvidia.com/gpucores` | O / O | Library, Hardware | HAMi 포함 |
| Huawei Ascend NPU | `huawei.com/Ascend910B3`, `huawei.com/Ascend910B3-memory` | O / O | Hardware | HAMi 별도 |
| Kunlunxin XPU | `kunlunxin.com/vxpu`, `kunlunxin.com/vxpu-memory` | O / X | Hardware | HAMi 별도 |
| AMD GPU | `amd.com/gpu`, `amd.com/gpumem`, `amd.com/gpucores` | O / O | Library | HAMi 별도 |
{{< /table >}}

[Table 1]은 HAMi 프로토콜을 따르는 Device Plugin이 제공되는 주요 가속기와 Resource 이름, 격리 계층, Device Plugin 패키징을 나타내고 있다. 각 가속기는 개수를 요청하는 Resource와 함께 Memory 크기, Core 사용률을 요청하는 Resource를 제공하며, hami-scheduler가 인식할 가속기별 Resource 이름은 `hami-scheduler-device` ConfigMap에 정의된다. Device Plugin은 `HAMi 포함` (HAMi Helm Chart 기본 포함)과 `HAMi 별도` (Project-HAMi 저장소의 별도 Chart·Manifest) 두 가지 방식으로 배포되며, NVIDIA GPU 외에는 HAMi 설치와 별개로 각 Device Plugin을 설치해야 한다. 등록·Scheduling·할당의 전체 흐름은 모두 HAMi가 담당하며, 1.1~1.3절은 이 경우를 기준으로 분석한다.

HAMi는 이 외에도 제조사가 제공하는 Device Plugin을 그대로 이용하는 가속기를 지원하여 v2.10.0 기준으로 총 14종의 가속기를 지원한다. 다만 제조사 Device Plugin 경로에서는 Device 선택과 격리 적용을 모두 벤더 Plugin이 담당하기 때문에, HAMi는 Pod Annotation을 통한 Node Scheduling 정책 지정과 Mutating Webhook routing 수준에서만 개입한다.

### 1.1. Device 등록 과정

{{< figure caption="[Figure 2] Device Registration Process" src="images/hami-device-registration.png" width="650px" >}}

Device Plugin의 첫 번째 역할은 Node에 존재하는 가속기를 부풀려서 Kubernetes에 등록하는 역할이다. [Figure 2]는 Device 등록 과정을 나타내고 있다.

1. Device Plugin이 DaemonSet을 통해서 가속기 Node에서 동작을 시작하며, 가속기의 UUID, Memory 크기, Core 개수, Type 정보를 파악한다.
2. Device Plugin은 kubelet의 Device Plugin Unix Domain Socket을 통해서 `Register()` gRPC 요청을 전송하여 자신을 kubelet에 등록한다.
3. kubelet은 Device Plugin에게 `ListAndWatch()` gRPC 요청을 전송하여 가속기 목록을 수신한다. 이때 Device Plugin은 물리 가속기의 개수를 `deviceSplitCount` 설정의 배수만큼 부풀려서 전달한다. 예를 들어 물리 가속기가 4개 존재하고 `deviceSplitCount`가 10으로 설정되어 있으면 40개의 가속기가 전달되며, 하나의 물리 가속기를 최대 10개의 Container에 할당할 수 있다는 의미가 된다.
4. kubelet은 전달받은 가속기 개수를 Node의 Allocatable/Capacity에 등록한다.
5. Device Plugin은 Device Plugin 규격과 별도로 물리 가속기의 상세 정보를 `hami.io/node-[가속기]-register` 계열의 Node Annotation에 기록한다.

kubelet의 Device Plugin 규격은 Device의 개수와 ID만 전달할 수 있기 때문에, 가속기의 Memory 크기 같은 상세 정보는 Device Plugin 규격으로는 전달할 수 없다. 따라서 Device Plugin은 상세 정보를 Node Annotation에 별도로 기록하며, 이후 Scheduler Extender가 이 Annotation을 참조하여 Scheduling을 수행한다. Annotation은 주기적으로 갱신되기 때문에 Node의 가속기 상태 변화도 Scheduler Extender에 반영된다.

### 1.2. Device Scheduling 과정

{{< figure caption="[Figure 3] Device Scheduling Process" src="images/hami-device-scheduling.png" width="650px" >}}

Device Plugin 방식에서는 Node 선택은 kube-scheduler가 수행하고 가속기 선택은 각 Node의 Device Plugin이 수행하지만, HAMi 환경에서는 hami-scheduler가 Node 선택뿐만 아니라 가속기 선택까지 수행한다. Memory 크기와 Core 사용률 조건을 만족하는 가속기를 선택하기 위해서는 Node 전체의 가속기 할당 상태를 알아야 하기 때문이다. [Figure 3]은 Device Scheduling 과정을 나타내고 있다.

1. Kubernetes Client는 Pod의 Resource에 가속기 Resource를 명시하여 Pod를 생성한다.
2. hami-scheduler의 Mutating Webhook은 등록된 모든 가속기 Resource를 검사하여 가속기를 요청하는 Pod를 감지하고, Pod의 `schedulerName`을 `hami-scheduler`로 변경하여 hami-scheduler가 해당 Pod의 Scheduling을 담당하도록 설정한다.
3. hami-scheduler 내부의 kube-scheduler는 Pod의 Scheduling을 시작하며, Filter/Score 단계에서 HTTP 기반의 Scheduler Extender를 호출한다.
4. Scheduler Extender는 각 Node의 Annotation에 기록된 가속기 정보와 기존 할당 내역을 기반으로, 요청 조건을 만족하는 가속기가 존재하는 Node를 선별하고 Scheduling 정책에 따라 점수를 계산한다.
5. Scheduler Extender는 선택된 가속기의 UUID와 Memory 크기, Core 사용률 제한 값을 Pod의 `hami.io/[가속기]-devices-allocated` 계열 Annotation에 기록하고, Pod를 선택된 Node에 Bind한다.

```shell {caption="[Shell 1] HAMi Mutating Webhook Configuration과 대상 hami-scheduler Service 확인"}
$ kubectl get mutatingwebhookconfigurations
NAME           WEBHOOKS   AGE
hami-webhook   1          14d

$ kubectl get mutatingwebhookconfigurations hami-webhook -o yaml
...
webhooks:
- name: vgpu.hami.io
  clientConfig:
    service:
      name: hami-scheduler
      namespace: kube-system
      path: /webhook
      port: 443
  rules:
  - apiGroups: [""]
    apiVersions: [v1]
    operations: [CREATE]
    resources: [pods]
  namespaceSelector:
    matchExpressions:
    - key: hami.io/webhook
      operator: NotIn
      values: [ignore]
  objectSelector:
    matchExpressions:
    - key: hami.io/webhook
      operator: NotIn
      values: [ignore]
  failurePolicy: Ignore
  sideEffects: None

$ kubectl -n kube-system get svc hami-scheduler
NAME             TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)                         AGE
hami-scheduler   NodePort   10.97.57.101   <none>        443:31998/TCP,31993:31993/TCP   14d

$ kubectl -n kube-system get endpoints hami-scheduler
NAME             ENDPOINTS                        AGE
hami-scheduler   10.244.0.6:443,10.244.0.6:9395   14d

$ kubectl -n kube-system get pods -l app.kubernetes.io/component=hami-scheduler -o wide
NAME                             READY   STATUS    RESTARTS   AGE   IP           NODE
hami-scheduler-55cc79689-lv8l6   2/2     Running   0          14d   10.244.0.6   gpu
```

[Shell 1]은 HAMi 설치 시 생성되는 Mutating Webhook Configuration (`hami-webhook`) 과 webhook 대상이 되는 `hami-scheduler` Service를 나타내고 있다. `rules`에 Pod 생성 요청 (`CREATE pods`) 이 지정되어 있어 모든 Pod 생성이 webhook을 거치며, `clientConfig.service`가 가리키는 `hami-scheduler` Service의 `/webhook` 경로 (`443` Port) 로 요청이 전달된다. Service의 Endpoint (`10.244.0.6:443`) 는 `hami-scheduler-55cc79689-lv8l6` Pod의 IP와 일치하며, 이 Pod 안의 Scheduler Extender Container가 webhook 요청을 수신한다. Extender는 요청에 포함된 Pod가 등록된 모든 가속기 Resource 중 하나라도 요청하는지 검사하고, 요청하는 경우에만 Pod의 `schedulerName`을 `hami-scheduler`로 변경한다. `namespaceSelector`와 `objectSelector`는 `hami.io/webhook: ignore` Label이 붙은 Namespace와 Pod를 webhook 처리에서 제외하여 특정 범위를 건너뛸 수 있도록 한다.

Scheduling 정책은 Node를 선택하는 Node Scheduling 정책과 Node 안에서 가속기를 선택하는 Device Scheduling 정책으로 구분된다. `binpack` 정책은 이미 할당량이 많은 Node나 가속기에 몰아서 할당하여 가속기 조각을 최소화하는 정책이고, `spread` 정책은 Node나 가속기에 고르게 분산하여 할당하는 정책이다. 기본 정책은 Helm 설정으로 지정하며 (Node는 `binpack`, Device는 `spread`가 기본값), Pod의 `hami.io/node-scheduler-policy`, `hami.io/gpu-scheduler-policy` Annotation을 통해서 Pod 단위로 변경할 수 있다.

### 1.3. Device 할당 과정

{{< figure caption="[Figure 4] Device Allocation Process" src="images/hami-device-allocation.png" width="650px" >}}

Device Plugin의 두 번째 역할은 hami-scheduler가 선택한 가속기를 실제로 Container에 할당하는 역할이다. [Figure 4]는 Device 할당 과정을 나타내고 있다.

1. Pod가 Bind된 Node의 kubelet은 Device Plugin에게 `Allocate()` gRPC 요청을 전송한다.
2. Device Plugin은 kube-apiserver를 통해서 해당 Pod의 Annotation을 조회하여, hami-scheduler가 선택한 가속기의 UUID와 Memory 크기, Core 사용률 제한 값을 파악한다. 일반적인 Device Plugin은 `Allocate()` 요청에 포함된 Device ID만으로 동작하지만, HAMi의 Device Plugin은 hami-scheduler의 가속기 선택 결과를 그대로 따라야 하기 때문에 Pod의 Annotation을 참조한다.
3. Device Plugin은 `Allocate()` 응답으로 할당할 가속기 정보와 격리 설정을 반환한다. 반환 내용은 격리 계층에 따라서 다른데, Library 수준은 격리 Library Mount와 제한값 환경 변수가, Driver/Hardware 수준은 가상화된 가속기 Device 참조가 반환된다.
4. kubelet은 반환받은 설정을 반영하여 Container를 생성하며, 이후 Container가 가속기를 사용하면 격리 계층이 Memory 크기 제한과 Core 사용률 제한을 강제한다.

### 1.4. HAMi Annotation 정리

HAMi의 Device Plugin과 hami-scheduler는 Node와 Pod에 다수의 Annotation을 기록하거나 참조한다. 아래 YAML은 Node와 Pod에 설정되는 주요 Annotation을 가속기 중립 형태로 나열한다. 가속기별로 Suffix가 달라지며, NVIDIA GPU는 초기 구현의 이름을 유지하는 Legacy Suffix (`vgpu` 등) 를 사용한다.

```yaml {caption="[File 1] Node에 설정되는 HAMi Annotation", linenos=table}
apiVersion: v1
kind: Node
metadata:
  annotations:
    hami.io/node-[가속기]-register: '[{...가속기 상세 목록 JSON...}]'
    hami.io/node-handshake: Requesting_<timestamp>
    hami.io/node-handshake-[가속기]: Requesting_<timestamp>
```

[File 1]은 Device Plugin이 Node에 기록하는 Annotation을 나타내고 있다.

* **`hami.io/node-[가속기]-register`** : 해당 Node의 가속기 상세 목록 (UUID, Memory 크기, Core 수, Chip Type, 동작 Mode, Health 등) 을 JSON 배열로 담는다. Device Plugin이 주기적으로 갱신하며, 가속기 Suffix는 Chip 종류에 따라 바뀐다.
* **`hami.io/node-handshake`**, **`hami.io/node-handshake-[가속기]`** : Scheduler Extender가 가속기별로 Node 상태를 주기적으로 확인하는 Health check 표시. `Requesting_<timestamp>` 형태로 갱신된다.

```yaml {caption="[File 2] Pod에 설정되는 HAMi Annotation", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  annotations:
    # Scheduler Extender가 Scheduling 단계에서 기록
    hami.io/[가속기]-devices-to-allocate: <할당 Phase 중간 상태>
    hami.io/[가속기]-devices-allocated: <할당된 결과 레코드>
    hami.io/vgpu-node: <Node 이름>
    hami.io/bind-phase: success
    hami.io/bind-time: "<Unix epoch>"
    hami.io/vgpu-time: "<Unix epoch>"
    # 사용자가 Scheduling 동작 제어를 위해 지정
    hami.io/node-scheduler-policy: binpack
    hami.io/gpu-scheduler-policy: spread
```

[File 2]는 Pod에 설정되는 HAMi Annotation을 나타내고 있다. Scheduler Extender가 Scheduling 단계에서 자동으로 기록하는 Annotation과 사용자가 Scheduling 동작 제어를 위해 Pod spec에 직접 지정하는 Annotation으로 구분된다.

Scheduler Extender가 기록하는 Annotation:

* **`hami.io/[가속기]-devices-to-allocate`** : 할당 Phase 중간에 Scheduler가 선택한 가속기를 임시로 기록하는 Field. 할당이 완료되면 비워진다.
* **`hami.io/[가속기]-devices-allocated`** : Scheduler가 최종 선택한 가속기 할당 결과 (UUID, Type, Memory 크기, Core 사용률 등). 가속기 1개당 1개 Record가 생성된다.
* **`hami.io/vgpu-node`** : 가속기가 할당된 Node 이름.
* **`hami.io/bind-phase`** : Scheduling의 Bind 단계 상태.
* **`hami.io/bind-time`**, **`hami.io/vgpu-time`** : Bind 수행 시각.

사용자가 지정하는 Annotation:

* **`hami.io/node-scheduler-policy`** : 해당 Pod의 Node Scheduling 정책 (`binpack` / `spread`).
* **`hami.io/gpu-scheduler-policy`** : 해당 Pod의 Device Scheduling 정책 (`binpack` / `spread` 등 가속기별 지원 값).

이 외에 Namespace 또는 Pod에 **`hami.io/webhook: ignore`** Label을 지정하면 HAMi Mutating Webhook이 해당 범위를 건너뛰어 `schedulerName`을 변경하지 않는다.

## 2. 참조

* HAMi GitHub : [https://github.com/Project-HAMi/HAMi](https://github.com/Project-HAMi/HAMi)
* HAMi Docs : [https://project-hami.io/docs/](https://project-hami.io/docs/)
* HAMi 지원 Device 목록 : [https://project-hami.io/docs/userguide/device-supported](https://project-hami.io/docs/userguide/device-supported)
* CNCF HAMi : [https://www.cncf.io/projects/hami/](https://www.cncf.io/projects/hami/)
