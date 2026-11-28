---
title: OpenSandbox BatchSandbox
draft: true
---

OpenSandbox의 기본 Sandbox 실행 모델인 BatchSandbox의 동작 구조를 분석한다. BatchSandbox는 Sandbox를 Kubernetes Pod로 실행하는 OpenSandbox의 1급 Workload Provider이며, Volume Lifecycle 관리, Egress 제약, Snapshot 기반 Pause/Resume 같은 OpenSandbox 기능 대부분이 BatchSandbox를 기준으로 제공된다. OpenSandbox의 전체 Architecture는 [OpenSandbox Architecture](../opensandbox-architecture/) 글에서 분석하였으며, 본 글은 BatchSandbox 경로의 상세 동작에 집중한다. 분석 기준 Version은 v1.2.1이다.

## 1. BatchSandbox 동작 구조

{{< figure caption="[Figure 1] BatchSandbox 생성 과정과 Sandbox Pod 구조" src="images/batchsandbox-flow.png" width="1000px" >}}

[Figure 1]은 Sandbox 생성 요청이 Pod로 구체화되는 과정을 나타내고 있다. Server는 생성 요청을 받으면 Sandbox Workload Namespace에 `sandbox.opensandbox.io/v1alpha1` Group의 **BatchSandbox** Custom Resource를 생성하고, Controller가 BatchSandbox를 Reconcile하여 Sandbox Pod를 생성한다. Pod의 골격은 Server에 Mount된 BatchSandbox Template(`batchsandbox_template_file`)이 결정하며, 생성 요청의 내용은 Template 위에 Merge된다. 따라서 Scheduling, SecurityContext 같은 Platform 소유 설정은 Template이 강제하고, Image나 Env 같은 Sandbox 단위 설정만 요청이 결정하는 구조이다.

Sandbox Pod는 사용자 Container 외에 OpenSandbox가 주입하는 Component를 포함한다.

* **execd** : In-Sandbox Bootstrap을 담당하는 Process이다. OSEP-0018에 따라서 Sandbox의 Init(PID 1)으로 동작하며 Child Process Reaping과 Signal Forwarding을 담당한다. Code 실행(exec) API와 File 송수신 API는 모두 execd를 통해서 처리된다.
* **Egress Sidecar / egress-init** : 생성 요청에 `networkPolicy`가 포함된 경우 주입되는 Egress 집행 Component이다. 상세 동작은 Egress NetworkPolicy 부분에서 분석한다.

생성된 Workload에는 `opensandbox.io/id`, `opensandbox.io/tenant`, `opensandbox.io/expires-at` 같은 예약 Label이 부여되며, Server는 이 Label을 통해서 Sandbox의 수명과 소유자를 추적한다.

## 2. Egress NetworkPolicy

Sandbox 단위의 Egress 제약은 생성 요청의 `networkPolicy` Field로 선언한다.

```python {caption="[Text 1] Egress NetworkPolicy 선언 예시"}
sandbox = await Sandbox.create(
    image="python:3.11",
    network_policy=NetworkPolicy(
        default_action="deny",                  # 생략시에도 deny가 기본
        egress=[
            NetworkRule(action="allow", target="pypi.org"),
            NetworkRule(action="allow", target="*.pythonhosted.org"),
            NetworkRule(action="allow", target="10.0.0.0/8", ports=[5432]),
            NetworkRule(action="deny",  target="*.internal.example.com"),
        ],
    ),
)
```

[Text 1]은 Python SDK를 이용한 NetworkPolicy 선언 예시를 나타내고 있다. NetworkPolicy는 기본 동작(`defaultAction`, 기본값 deny)과 순서대로 평가되는 Rule 목록(`egress`)으로 구성된다. 각 Rule의 `target`은 FQDN, Wildcard Domain, IP, CIDR을 지원하며 `ports`를 통해서 TCP 목적지 Port를 제한할 수 있다. 단 Domain Rule은 DNS Layer에서 평가되기 때문에 Port 차원이 존재하지 않으며, Domain과 `ports`를 조합하면 Validation Error로 거부된다. UDP Port 제한도 지원되지 않는다.

집행은 두 단계로 이루어진다. Pod 시작 시 `egress-init` Init Container가 Workload Container보다 먼저 Default-Deny nftables Fence를 설치하고, Egress Sidecar가 초기화되면 Fence를 선언된 Policy로 원자적으로 교체한다. 이후 Domain Rule은 Sidecar의 DNS Proxy가, IP/CIDR Rule은 nftables가 집행한다(`dns+nft` Mode 기준). 이러한 Bootstrap 순서 때문에 Sandbox Code가 Sidecar 초기화 이전의 시간 틈새를 이용할 수 없다.

NetworkPolicy는 Sandbox를 생성하는 Platform이 Sandbox 내부 Code로부터 스스로를 방어하는 장치라는 점에 주의해야 한다. Policy 결정권이 생성 요청자에게 있기 때문에, 요청자 자체를 신뢰할 수 없는 Multi-Tenant 환경에서는 Sandbox Workload Namespace에 Kubernetes NetworkPolicy로 하한선(IMDS, 내부망 차단)을 별도로 설치하여 요청자가 우회할 수 없는 경계를 한 겹 더 두는 구성이 필요하다.

## 3. Volume

BatchSandbox는 생성 요청의 `volumes` Field를 통해서 PVC를 Mount할 수 있으며, PVC Lifecycle의 소유자에 따라서 세 가지 Mode로 구분된다.

| Mode | `createIfNotExists` | `deleteOnSandboxTermination` | PVC Lifecycle 소유자 | 용도 |
|---|---|---|---|---|
| Bring Your Own | `false` | 무시됨 | Platform (사전 생성) | 공유 Cache, Model 저장소 |
| Server-Managed Persistent | `true` | `false` (기본값) | 최초 생성 이후 사용자 | Sandbox 수명을 넘는 상태 보존 |
| Server-Managed Ephemeral | `true` | `true` | Server | Sandbox 단위 Scratch 공간 |

```python {caption="[Text 2] Server-Managed PVC 선언 예시"}
sandbox = await Sandbox.create(
    image="python:3.11",
    volumes=[Volume(
        pvc=PVC(
            claimName="agent-cache",
            createIfNotExists=True,            # 없으면 Server가 생성
            deleteOnSandboxTermination=False,  # Sandbox 종료 후에도 유지
            storage="20Gi",
        ),
        mountPath="/mnt/cache",
    )],
)
```

[Text 2]는 Server-Managed Persistent Mode의 PVC 선언 예시를 나타내고 있다. Server-Managed Mode에서는 Client가 Kubernetes에 접근하지 않고도 PVC의 생성과 정리까지 API로 처리된다. Ephemeral PVC는 생성한 Sandbox가 배타적으로 소유하며, 다른 Sandbox가 동일한 `claimName`을 Mount하려고 하면 409 CONFLICT로 거부된다. 또한 Server는 자신이 `createIfNotExists`로 생성한 PVC만 삭제하며 기존 PVC는 삭제하지 않기 때문에, 사전에 생성된 공유 PVC가 Ephemeral 정리에 휩쓸리는 상황은 발생하지 않는다.

PVC 외에도 `[storage].allowed_host_paths`에 선언된 경로에 한하여 Host Bind Mount를 지원한다. Allowlist가 비어있으면 모든 Host Bind가 거부되는 Secure-by-Default 동작이다.

Volume은 Snapshot 기반 Pause/Resume의 대안으로도 의미를 갖는다. 보존이 필요한 상태를 Persistent PVC에 두면, Sandbox를 종료한 후 동일한 `claimName`으로 재생성하는 방식으로 Registry 없이도 상태 보존과 Compute 반납을 달성할 수 있다. 다만 이 방식은 `sandboxId`가 변경되고 Mount 경로 밖의 Rootfs 변경사항은 보존되지 않는다는 점에서 Snapshot과 구별된다.

## 4. Secure Runtime

BatchSandbox의 Sandbox Pod는 기본적으로 runc로 실행되지만, `[secure_runtime]` 설정을 통해서 더 강한 격리의 Runtime을 이용할 수 있다.

```toml {caption="[Text 3] Secure Runtime 설정"}
[secure_runtime]
type = "gvisor"               # "", gvisor, kata, firecracker
k8s_runtime_class = "gvisor"  # Kubernetes RuntimeClass 이름
```

[Text 3]은 gVisor를 이용하는 Secure Runtime 설정을 나타내고 있다. Server는 Sandbox Pod 생성 시 지정된 RuntimeClass를 주입한다. RuntimeClass의 `scheduling` Field에 NodeSelector와 Toleration을 정의해두면 Sandbox Pod가 해당 Runtime이 설치된 Node로 자동으로 배치되기 때문에, gVisor나 Kata가 특정 NodeGroup에만 설치된 Cluster에서도 Server 설정 변경 없이 동작한다.

Secure Runtime Profile은 Server Process당 하나이며 API 요청이 Runtime을 선택할 수 없다. runc Sandbox와 gVisor Sandbox를 동시에 제공하려면 Server를 별도로 배포해야 한다. 또한 Runtime 선택은 Snapshot 기반 Pause/Resume 기능의 가용성에 직접적인 영향을 준다.

## 5. Pause/Resume과 Snapshot

{{< figure caption="[Figure 2] BatchSandbox Pause/Resume 과정" src="images/batchsandbox-snapshot.png" width="1000px" >}}

[Figure 2]는 BatchSandbox의 Pause/Resume 과정을 나타내고 있다. BatchSandbox의 Pause는 Sandbox의 Rootfs를 OCI Image로 보존한 후 Pod를 제거하여 Compute Resource를 반납하는 기능이다. Pause 요청이 들어오면 Controller는 내부 Custom Resource인 **SandboxSnapshot**을 생성하고, Snapshot 처리를 위한 단기 **Commit Job**을 Sandbox와 동일한 Namespace에 생성한다. Commit Job의 image-committer는 nerdctl을 이용하여 Container Rootfs를 OCI Image로 Commit하고 설정된 Registry에 Push한다. Resume 시에는 BatchSandbox의 Template이 Snapshot Image로 재작성되어 Pod가 재생성되기 때문에, `sandboxId`가 유지된 채 Filesystem 상태가 복원된다. Pause 이전에 실행 중이던 Process는 보존되지 않고 재시작된다.

Snapshot 설정은 Server가 아닌 Controller 설정이다. Registry 주소, Push/Pull Secret(`kubernetes.io/dockerconfigjson` Type), Image 명명 Template을 Controller에 지정하며, Client는 설정 없이 Pause/Resume API만 호출한다. Registry가 설정되지 않은 상태에서 Pause가 요청되면 SandboxSnapshot의 Status Condition으로 실패가 보고된다.

### 5.1. Runtime별 Snapshot 호환성

Snapshot 동작은 Sandbox의 Container Runtime에 따라서 가용성과 보존 범위가 달라진다.

| Runtime | Pause/Snapshot | 보존 범위 |
|---|---|---|
| runc (기본) | 지원 (rootfs-v1 Committer) | Rootfs만, Process 재시작 |
| gVisor (runsc) | **거부 (HTTP 409)** | - |
| Kata (QEMU) | 지원 (QEMU Checkpoint) | Rootfs + **VM Memory 전체** |

기본 rootfs-v1 Committer는 containerd의 Task Pause/Resume과 Writable Snapshot API를 전제로 하는데, gVisor(runsc)는 이 계약을 만족하지 않는다. 이 때문에 Server는 runsc Handler의 RuntimeClass로 실행된 BatchSandbox에 대한 Pause 요청을 Snapshot Record 생성 이전에 HTTP 409로 거부하며, 실행 중인 Sandbox에는 영향을 주지 않는다. 즉 **gVisor 격리와 Snapshot 기반 Pause/Resume은 양립할 수 없는 Trade-off** 관계이다.

반면 QEMU 기반 Kata Runtime에서는 별도의 QEMU Checkpoint 경로가 제공된다. image-committer가 QEMU Checkpoint Helper를 통해서 VM의 Memory 상태 전체를 Checkpoint하고 압축하여 Registry Image로 Packaging하며, Resume 시 VM State Loader가 이를 복원한다. 이 경우 Filesystem뿐만 아니라 실행 중이던 Process와 Memory까지 보존되기 때문에, Fast Sandbox의 Live Snapshot과 유사한 보존 범위를 Pod 기반 실행 모델에서 제공한다. 다만 Memory 상태가 Registry를 왕복하기 때문에 Pause/Resume 소요 시간은 Node Local에 Checkpoint를 보존하는 Fast Sandbox와 비교하여 크게 길다. Fast Sandbox의 Live Snapshot과 자동 Idle-Pause/Wake는 [OpenSandbox Fast Sandbox](../opensandbox-fast-sandbox/) 글에서 분석한다.

## 6. 참조

* [https://github.com/opensandbox-group/OpenSandbox](https://github.com/opensandbox-group/OpenSandbox)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/pause-resume.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/guides/pause-resume.md)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/examples/kubernetes-pvc-volume-mount.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/examples/kubernetes-pvc-volume-mount.md)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/server/configuration.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/server/configuration.md)
