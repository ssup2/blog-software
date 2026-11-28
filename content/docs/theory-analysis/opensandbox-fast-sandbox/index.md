---
title: OpenSandbox Fast Sandbox
draft: true
---

OpenSandbox의 고속 Sandbox 실행 경로인 Fast Sandbox의 동작 구조를 분석한다. [OpenSandbox BatchSandbox](../opensandbox-batch-sandbox/) 글에서 분석한 Pod 기반 실행 모델은 Pod 생성과 Container Cold Boot 때문에 기동에 초 단위의 시간이 소요되고, Pause/Resume시 Snapshot이 Registry를 왕복하기 때문에 수십 초 이상이 소요된다. Fast Sandbox는 미리 빌드된 Golden Image Snapshot을 Firecracker MicroVM으로 복원하는 방식으로 ms 단위의 기동 시간을 제공하며, Memory 상태까지 보존하는 Live Snapshot과 자동 Idle-Pause/Wake를 지원하는 별도의 실행 경로이다. 분석 기준 Version은 v1.2.1이다.

## 1. Architecture

{{< figure caption="[Figure 1] Fast Sandbox Architecture" src="images/fast-sandbox-architecture.png" width="1000px" >}}

[Figure 1]은 Fast Sandbox의 Architecture를 나타내고 있다. Fast Sandbox는 OpenSandbox Server와 별도의 Control Plane 및 Node Runtime으로 구성되며, Sandbox 생성 요청에 `templateId`가 포함되면 Server가 Workload Provider 대신 Fast Sandbox 경로로 요청을 전달한다.

* **Controller (FastPath)** : Fast Sandbox의 Control Plane이다. `sandbox.fast.io` Group의 SandboxPool, SandboxTemplate, Sandbox Custom Resource를 Reconcile하는 Reconciler와, Server가 Sandbox 생성/삭제/Pause/Resume을 요청하는 gRPC API인 **FastPath**가 하나의 Process로 동작한다.
* **Firecracker Runtime** : 각 KVM Node에서 동작하는 DaemonSet이다. Fastlet의 Firecracker Driver가 통신하는 UDS 관리 API(Artifact Pull, Lease 상태)를 제공하며, Node 적합성 검사와 Firecracker Asset 설치를 수행하는 Node Readiness Loop를 포함한다. P2P Artifact 전달을 위한 Node-Local **DART** Child와 고아 Resource를 정리하는 **Janitor** Sidecar도 함께 동작한다.
* **Fastlet** : Sandbox가 실제로 실행되는 Worker Pod이다. 하나의 Fastlet은 다수의 Firecracker MicroVM을 동시에 수용하며, Sandbox는 Kubernetes Pod가 아니라 Fastlet 내부의 MicroVM으로 실행된다.

Node 준비 과정에서 주목할 부분은 **Runtime의 자가 라벨링**이다. Firecracker Runtime은 Node에서 KVM 사용 가능 여부를 포함한 Host 검사를 수행하고, 통과한 Node에 `fast-sandbox.io/kvm`과 `fast-sandbox.io/firecracker-node` Label 그리고 `FirecrackerReady` Node Condition을 스스로 부여한다. 운영자가 KVM Node를 수동으로 라벨링할 필요가 없으며, Fastlet과 Golden Image Builder Pod는 이 Label을 기준으로 스케줄링된다. Firecracker는 `/dev/kvm`을 요구하기 때문에 Bare Metal Node 또는 Nested Virtualization이 활성화된 Node가 필요하다.

## 2. Fastlet과 SandboxPool

Fastlet의 수량과 규격은 **SandboxPool** Custom Resource가 결정한다. SandboxPool은 Runtime 종류, Sandbox의 CPU/Memory/PID Limit, Fastlet Template을 고정하는 **Fixed Pool Model**을 채택하고 있으며, 하나의 Pool에 속한 모든 Sandbox는 동일한 규격을 갖는다. Server는 생성 요청의 `extensions.poolRef` 또는 설정의 기본 Pool(`fastpath_resource_pool`)을 통해서 Pool을 선택한다.

```yaml {caption="[Text 1] SandboxPool 주요 Spec"}
apiVersion: sandbox.fast.io/v1alpha2
kind: SandboxPool
spec:
  runtime: firecracker
  capacity:
    poolMin: 2                  # 상시 유지할 Fastlet 수
    poolMax: 4
  maxSandboxesPerPod: 5         # Fastlet당 수용 가능한 MicroVM 수
  sandboxResources:             # Pool 내 모든 Sandbox의 고정 규격
    cpu: "1"
    memory: 512Mi
    pids: 128
  warmImages:                   # Fastlet 기동시 미리 당겨올 Golden Image
    - python-agent:v1
```

[Text 1]은 SandboxPool의 주요 Spec을 나타내고 있다. Pod 단위로 Sandbox를 만드는 BatchSandbox와 달리 Fast Sandbox는 **미리 떠있는 Fastlet에 MicroVM을 배치**하는 모델이기 때문에, Sandbox 생성 경로에 Pod Scheduling과 Image Pull이 존재하지 않는다. 배치는 Node-Local Scheduling Registry와 Fastlet의 원자적 Admission을 통해서 이루어지며, 모든 Fastlet이 가득 찬 경우에는 Sandbox Custom Resource를 생성하기 전에 ResourceExhausted로 거부하는 Bounded Capacity Error 시맨틱을 갖는다. 하나의 Fastlet이 다수의 MicroVM을 수용하는 구조는 Sandbox당 Pod 하나를 만드는 모델과 비교하여 밀도 측면에서도 유리하다.

## 3. Golden Image Pipeline

{{< figure caption="[Figure 2] Golden Image Build와 배포 경로" src="images/fast-sandbox-golden-image.png" width="1000px" >}}

[Figure 2]는 Golden Image의 빌드와 배포 경로를 나타내고 있다. Fast Sandbox의 기동 시간은 "부팅을 미리 수행해두고 그 시점을 저장한다"는 Golden Image 전략에서 나온다.

**SandboxTemplate** Custom Resource가 생성되면 Controller는 일회성 **Builder Pod**를 생성한다. Builder는 KVM Node에서 Base Container Image로 Firecracker VM을 실제로 부팅하고, execd를 Guest에 Bake한 후, VM의 Memory와 Rootfs Snapshot(Snapfiles)을 생성하여 **Artifact Store**에 Publish한다. Artifact Store는 S3 호환 Object Storage이며, 이후 Sandbox 생성은 이 Snapshot을 복원하는 것으로 대체된다. 즉 Cold Boot는 Template 빌드 시점에 한번만 수행된다.

Artifact Store가 원격 Storage임에도 생성 경로가 빠른 이유는 **복원 소스가 Node Local이기 때문**이다.

* **Warm Image** : SandboxPool의 `warmImages`에 선언된 Golden Image는 Fastlet이 기동되는 과정에서 미리 Node Local Cache(StateRoot)로 Pull된다. Warm Image 조회는 Image 이름의 Hash를 기준으로 Byte-Exact하게 수행되기 때문에, Template의 Image와 정확히 일치해야 한다.
* **Cache 인지 스케줄링** : Sandbox 배치는 해당 Artifact가 이미 Cache된 Fastlet을 우선한다. Warm Image, Infra Component, 활성 Runtime Content 같은 Cache는 GC로부터 보호된다.
* **DART P2P** : Node가 추가되어 Cache가 비어있는 경우에도 Artifact Store 대신 이웃 Node의 DART Peer로부터 Block을 가져온다. Peer 탐색은 Headless Service의 DNS Seeding으로 이루어진다.

따라서 Artifact Store를 왕복하는 비용은 Template 빌드와 최초 Warm-Up 시점에만 지불되며, 정상 상태의 Sandbox 생성은 Node Local Snapshot 복원만으로 완료된다.

## 4. Live Snapshot과 Idle-Pause/Wake

### 4.1. Live Snapshot

Fast Sandbox의 Pause는 BatchSandbox의 Rootfs Commit과 달리 **MicroVM의 Memory 상태 전체를 Checkpoint**한다. Checkpoint는 Memory 기반 Spill 영역에 먼저 기록된 후 Node Local StateRoot로 이동하며, Registry나 Artifact Store를 왕복하지 않는다. 이 때문에 Pause된 Sandbox는 실행 중이던 Process와 Memory까지 그대로 보존된 채 ms~초 단위로 복원될 수 있다. BatchSandbox 경로에서 유사한 보존 범위를 제공하는 Kata QEMU Snapshot이 Memory 상태를 Registry로 왕복시키는 것과 대비되는 지점이다.

### 4.2. Idle-Pause/Wake-on-Access

{{< figure caption="[Figure 3] OSEP-0024 Idle-Pause/Wake-on-Access 순환" src="images/fast-sandbox-idle-pause-wake.png" width="1000px" >}}

[Figure 3]은 OSEP-0024 Idle-Pause/Wake-on-Access의 순환 구조를 나타내고 있다. 빠르고 무손실인 Live Snapshot은 자동 Idle-Pause/Wake 기능의 전제가 되며, Ingress Gateway, Server, Sandbox 세 Component가 순환 구조를 이룬다.

```text {caption="[Text 2] Idle-Pause/Wake 순환"}
Active : Ingress Gateway를 통과하는 모든 요청이 Redis에 Sandbox별 Activity를 기록
Idle   : Server의 Sweeper가 주기적으로 Activity를 확인하고, Idle Timeout이 지난
         Sandbox에 대해서 FastPath PauseSandbox 호출 → Checkpoint 후 Paused 전환
Wake   : Paused Sandbox로 요청이 도착하면 Gateway가 Resume을 트리거하고,
         요청을 Parking Budget 내에서 대기시킨 후 복원된 Sandbox로 전달
```

[Text 2]는 순환의 각 단계에서 수행되는 동작을 나타내고 있다. 자동화는 세 주체의 합의로만 동작한다. Server의 `[automation.idle_pause]` 설정(Sweeper), Gateway의 Activity/Wake Flag, 그리고 Sandbox 자신의 Opt-In이다. Sandbox는 생성 요청의 `lifecycle.idlePolicy`(Idle Timeout, Wake 여부)를 통해서 Opt-In하며, 이 Policy는 Sandbox Custom Resource의 `sandbox.opensandbox.io/idle-policy` Annotation으로 보존된다. Opt-In하지 않은 Sandbox는 자동으로 Pause되지 않는다.

Wake의 요청 Parking은 Budget(기본 5초)으로 제한되며, Budget 내에 복원이 완료되지 않으면 503과 Retry-After가 반환되고 복원은 Background에서 계속된다. 이 Parking Budget이 Fast Sandbox에만 자동화가 존재하는 이유를 설명한다. **"다음 요청이 도착했을 때 수 초의 Parking 안에 복원을 완료할 수 있다"는 전제가 성립해야 사용자 몰래 Pause하는 자동화가 안전**한데, Pod 재생성과 Image Pull이 필요한 BatchSandbox의 Resume은 이 전제를 만족할 수 없기 때문이다. 같은 이유로 Memory까지 보존되지 않는 실행 모델에서는 자동 Pause가 실행 중인 작업을 임의로 중단시키는 위험을 갖는다.

한 가지 주의할 점은 Activity의 유일한 기록 지점이 Ingress Gateway라는 것이다. Gateway를 경유하지 않는 Traffic은 Activity로 기록되지 않기 때문에, 그러한 Workload를 Idle Policy에 Opt-In시키면 실제로는 사용 중임에도 Idle로 판정되어 Pause될 수 있다.

## 5. 참조

* [https://github.com/opensandbox-group/OpenSandbox](https://github.com/opensandbox-group/OpenSandbox)
* [https://github.com/opensandbox-group/fast-sandbox](https://github.com/opensandbox-group/fast-sandbox)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/auto-pause-wake.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/auto-pause-wake.md)
* [https://github.com/opensandbox-group/fast-sandbox/blob/main/docs/concepts/scheduling-and-capacity.md](https://github.com/opensandbox-group/fast-sandbox/blob/main/docs/concepts/scheduling-and-capacity.md)
