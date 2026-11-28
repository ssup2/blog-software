---
title: OpenSandbox Architecture
draft: true
---

OpenSandbox의 Architecture를 분석한다. OpenSandbox는 AI Agent가 생성한 Code 실행처럼 신뢰할 수 없는 Workload를 격리된 환경에서 실행하기 위한 Sandbox Platform이며, Sandbox의 Lifecycle을 REST API로 추상화하여 제공한다. OpenSandbox는 단일 Host에서 동작하는 Docker Runtime과 Kubernetes Runtime을 지원하지만, Docker Runtime은 개발 및 단일 Host PoC 용도이기 때문에 본 글에서는 Kubernetes Runtime을 기준으로 분석한다. 분석 기준 Version은 v1.2.1이다.

## 1. Architecture

{{< figure caption="[Figure 1] OpenSandbox Architecture" src="images/opensandbox-architecture.png" width="1000px" >}}

[Figure 1]은 OpenSandbox를 Kubernetes 위에서 구성할 경우의 Architecture를 나타내고 있다. OpenSandbox는 다음의 Component로 구성된다.

* **Server** : Sandbox Lifecycle REST API를 제공하는 Component이다. SDK 또는 REST API를 통해서 Sandbox 생성/실행/종료 요청을 받으며, Kubernetes의 Custom Resource를 생성하는 방식으로 Sandbox를 관리한다. 설정은 TOML 형식의 ConfigMap으로 주입되며, 다수의 Replica를 통한 HA 구성은 지원하지 않기 때문에 단일 Replica로 동작한다.
* **Controller** : Server가 생성한 **BatchSandbox**, **Pool**, **SandboxSnapshot** Custom Resource를 Reconcile하여 실제 Sandbox Pod를 관리하는 Kubernetes Operator이다.
* **Base** : OpenSandbox의 CRD와 RBAC 같은 Cluster-scoped Resource만 설치하는 Component이다. Workload가 없기 때문에 Cluster당 한번만 설치된다.
* **Ingress Gateway** (Optional) : Sandbox로 향하는 Traffic을 중계하는 Proxy이다. Server는 Gateway의 주소를 Client에게 반환하는 역할만 수행하며, 실제 Sandbox Traffic은 Gateway를 통해서 Sandbox로 전달된다.
* **Node Agent** (Optional) : 각 Node에서 Sandbox의 Container Log를 수집하는 DaemonSet이다.
* **Fast Sandbox** (Optional) : Firecracker MicroVM 기반의 고속 Sandbox 실행 경로를 제공하는 별도의 Control Plane과 Node Runtime이다.

OpenSandbox Architecture의 핵심은 **Lifecycle API를 고정점으로 두고 그 아래의 실행 모델을 Layer로 추가**해온 구조라는 점이다. Client가 이용하는 API는 동일하게 유지되고, Sandbox가 실제로 어떻게 실행되는지는 Server 설정의 Runtime(`runtime.type`), Workload Provider(`workload_provider`), Secure Runtime(`secure_runtime`)이라는 서로 직교하는 세 가지 축으로 결정된다. 신규 기능은 Kubernetes의 KEP와 유사한 **OSEP**(OpenSandbox Enhancement Proposal) 프로세스를 통해서 추가되며, 실제로 agent-sandbox Workload Provider와 Fast Sandbox 실행 경로가 Version을 거치며 추가되었다.

## 2. Namespace 신뢰 경계

OpenSandbox는 Component의 성격에 따라서 Namespace를 분리하는 것을 전제로 설계되어 있다.

* **Control Plane Namespace** : Server, Controller, Ingress Gateway 같은 Platform Component가 동작하는 Namespace이다. API Key, 서명 Key 같은 Secret도 Control Plane Namespace에 위치한다.
* **Sandbox Workload Namespace** : 실제 Sandbox Pod가 생성되는 Namespace이며, Server 설정의 `[kubernetes].namespace`로 지정한다. Helm Chart는 Sandbox Workload Namespace를 생성하지 않기 때문에 별도로 생성해야 한다.

Sandbox Pod에서는 신뢰할 수 없는 사용자 Code가 직접 실행되기 때문에, Control Plane의 Secret과 Sandbox Workload를 같은 Namespace에 두지 않는 것이 이러한 분리의 핵심 이유이다. Sandbox Workload Namespace는 신뢰할 수 없는 Code의 실행 공간이라는 특성상, LimitRange/ResourceQuota를 통한 Resource 제한이나 NetworkPolicy를 통한 하한선 차단 같은 Kubernetes Level의 가드레일을 적용하는 지점으로도 활용된다.

## 3. Sandbox 실행 경로

{{< figure caption="[Figure 2] OpenSandbox Sandbox 실행 경로" src="images/opensandbox-execution-paths.png" width="1000px" >}}

[Figure 2]는 Kubernetes Runtime에서 Sandbox가 실행되는 세 가지 경로를 나타내고 있다. Workload Provider는 Server당 하나만 선택할 수 있는 배타적인 설정이지만, Fast Sandbox는 Workload Provider와 무관하게 요청 내용에 따라서 함께 서빙되는 별도의 경로이다.

```toml {caption="[Text 1] Server config.toml의 실행 경로 관련 설정"}
[runtime]
type = "kubernetes"

[kubernetes]
namespace = "opensandbox"                  # Sandbox Workload Namespace
workload_provider = "batchsandbox"         # batchsandbox 또는 agent-sandbox
fastpath_endpoint = "fast-sandbox-fastpath.opensandbox-system.svc:9090"  # Fast Sandbox 경로
```

[Text 1]은 Server config.toml에서 실행 경로를 결정하는 설정을 나타내고 있다. 어떤 Workload Provider를 이용할지와 Fast Sandbox 경로의 활성화 여부가 모두 Server 설정으로 결정되며, Client가 이용하는 API 형식은 실행 경로와 무관하게 동일하게 유지된다.

### 3.1. BatchSandbox Provider

기본 Workload Provider이다. Server가 자체 CRD인 BatchSandbox Custom Resource를 생성하면 Controller가 Sandbox Pod를 생성한다. Sandbox Pod에는 In-Sandbox Bootstrap을 담당하는 **execd**가 Init 형태로 주입되며, Code 실행(exec) API는 execd를 통해서 처리된다. Volume(PVC) Lifecycle 관리, Egress 제약, Snapshot 기반 Pause/Resume 같은 OpenSandbox의 기능 대부분이 BatchSandbox Provider를 기준으로 제공되는 1급 경로이다.

### 3.2. agent-sandbox Provider

Kubernetes SIG의 [agent-sandbox](https://github.com/kubernetes-sigs/agent-sandbox) Controller에게 Sandbox Pod 관리를 위임하는 Workload Provider이다. Server는 BatchSandbox Custom Resource 대신 agents.x-k8s.io Group의 Sandbox Custom Resource를 생성하며, Pod Lifecycle은 agent-sandbox Controller가 담당한다. Pause/Resume도 Sandbox Custom Resource의 `spec.operatingMode` Field를 patch하는 방식으로 구현되어 있기 때문에, Snapshot을 위한 Container Registry 없이 Pod 제거/재생성 방식의 Pause/Resume이 가능하다는 특징을 갖는다. 반면 Egress 제약이나 요청 단위 PVC Lifecycle 관리 같은 BatchSandbox Provider의 기능은 제공되지 않는다.

### 3.3. Fast Sandbox

Firecracker MicroVM 기반의 고속 실행 경로이다. Sandbox 생성 요청에 `templateId`가 포함되어 있으면 Server는 Workload Provider 대신 Fast Sandbox의 gRPC Control Plane인 **FastPath**를 통해서 Sandbox를 생성한다. Sandbox는 Kubernetes Pod가 아니라 **Fastlet**이라고 불리는 Worker Pod 내부의 Firecracker MicroVM으로 실행되며, 미리 빌드된 Golden Image Snapshot을 복원하는 방식으로 ms 단위의 기동 시간을 제공한다. KVM을 이용할 수 있는 Node가 필요하다.

### 3.4. 실행 경로 비교

| | BatchSandbox | agent-sandbox | Fast Sandbox |
|---|---|---|---|
| 실행 단위 | Pod | Pod | Fastlet Pod 내부의 MicroVM |
| Sandbox 관리 주체 | OpenSandbox Controller | agent-sandbox Controller | Fast Sandbox Control Plane (FastPath) |
| 선택 방식 | `workload_provider` | `workload_provider` | 요청의 `templateId` (Provider와 병행) |
| 기동 시간 | Pod 생성 + Container 기동 | Pod 생성 + Container 기동 | Snapshot 복원 (ms 단위) |
| Pause/Resume | Rootfs Snapshot Commit (Registry 필요) | Pod 제거/재생성 (Registry 불필요) | Live Snapshot (Memory 포함, Node Local) |
| Egress 제약 | 지원 | 미지원 | 별도 Profile |
| 특수 요구사항 | - | agent-sandbox Controller 설치 | KVM Node, Artifact Store |

BatchSandbox와 agent-sandbox Provider의 상세 동작은 [OpenSandbox BatchSandbox](../opensandbox-batch-sandbox/) 글에서, Fast Sandbox의 상세 동작은 [OpenSandbox Fast Sandbox](../opensandbox-fast-sandbox/) 글에서 분석한다.

## 4. Lifecycle API

Server가 제공하는 Lifecycle API는 실행 경로와 무관하게 동일한 Endpoint를 제공하며, 실행 경로에 따라서 내부 구현만 달라진다.

* **Create** : Sandbox를 생성한다. Container Image 기반 생성(`image`)과 Fast Sandbox Template 기반 생성(`templateId`)을 지원하며, Volume, Egress Policy(`networkPolicy`), Idle Policy 같은 Sandbox 단위 Spec을 함께 선언한다.
* **Exec** : Sandbox 내부에서 Code를 실행한다. Sandbox Pod에 주입된 execd가 처리한다.
* **Timeout / Renew** : 모든 Sandbox는 생성 시점에 수명(`timeout`)을 가지며, Renew API 또는 접근 기반 자동 갱신(OSEP-0009)을 통해서 연장할 수 있다. Server 설정의 `max_sandbox_timeout_seconds`를 통해서 생성 요청의 timeout 상한을 강제할 수 있다.
* **Pause / Resume** : Sandbox를 유휴 상태로 전환하여 Compute Resource를 반납하고, 이후 동일한 `sandboxId`로 재개한다. [Text 2]와 같이 실행 경로별로 구현과 보존 범위가 다르다.

```text {caption="[Text 2] 실행 경로별 Pause/Resume 의미"}
BatchSandbox  : Rootfs를 OCI Image로 Commit하여 Registry에 Push 후 Pod 제거
                (Filesystem 보존, Process 재시작)
agent-sandbox : Sandbox Custom Resource의 operatingMode patch로 Pod만 제거
                (PVC 데이터만 보존)
Fast Sandbox  : MicroVM Memory Checkpoint를 Node Local에 저장
                (Memory/Process까지 보존, 자동 Idle-Pause/Wake 지원)
```

[Text 2]는 동일한 Pause/Resume API가 실행 경로에 따라서 어떻게 다르게 구현되는지를 나타내고 있다. 동일한 API라도 보존되는 범위가 Filesystem, PVC 데이터, Memory로 각각 다르기 때문에, Client는 Server가 이용하는 실행 경로의 의미 차이를 인지하고 이용해야 한다.

인증은 `OPEN-SANDBOX-API-KEY` Header를 통한 API Key 방식이며, `[tenants]` 설정을 통해서 Tenant별로 분리된 API Key를 제공하는 Multi-Tenant 구성도 지원한다. API Key가 설정되지 않은 경우 Server는 명시적인 위험 승인 없이는 기동되지 않는다.

## 5. Ingress 경로

{{< figure caption="[Figure 3] OpenSandbox Ingress Gateway 요청 경로" src="images/opensandbox-ingress.png" width="900px" >}}

[Figure 3]은 Gateway Mode에서 Client의 요청이 Ingress Gateway를 거쳐서 Sandbox에 도달하는 경로를 나타내고 있다. Sandbox 내부에서 동작하는 HTTP Server에 접근하는 Ingress 경로는 `[ingress].mode` 설정에 따라서 두 가지 방식으로 동작한다.

* **direct** : Server가 Sandbox의 주소를 직접 반환하며, Client가 Sandbox에 직접 접근한다.
* **gateway** : Server가 Ingress Gateway의 주소를 반환하며, Client의 요청은 Gateway를 통해서 Sandbox로 중계된다. Gateway는 Header 또는 URI에 포함된 Route 정보를 기반으로 대상 Sandbox를 찾는다.

Gateway Mode에서는 **OSEP-0011 Secure Access**를 통해서 Route 정보의 위변조를 방지할 수 있다. Server와 Gateway가 HMAC-SHA256 서명 Key Ring을 공유하며, Server가 서명한 Route Token을 Gateway가 검증하는 구조이다. Key Ring은 다수의 Key와 Active Key 지정을 지원하기 때문에 무중단 Key Rotation이 가능하다. 서명 Key는 Kubernetes Secret을 통해서 환경변수로 주입되며, Key 원문이 설정 파일이나 Pod Args에 노출되지 않도록 설계되어 있다.

Gateway는 Sandbox Traffic의 유일한 관문이라는 위치 특성 때문에 Ingress 중계 외의 역할도 수행한다. Fast Sandbox의 Idle-Pause/Wake-on-Access(OSEP-0024)에서 Sandbox별 마지막 활동 시각을 기록하는 Activity Source와, Pause된 Sandbox로 향하는 요청을 복원이 완료될 때까지 Parking하는 Wake 주체가 모두 Gateway이다.

## 6. Egress 경계

{{< figure caption="[Figure 4] OpenSandbox Egress 집행 체인" src="images/opensandbox-egress.png" width="900px" >}}

[Figure 4]는 Sandbox에서 외부로 향하는 Egress Traffic의 집행 체인을 나타내고 있다. Sandbox 내부의 Code가 외부로 나가는 Egress Traffic은 Sandbox Pod에 주입되는 **Egress Sidecar**를 통해서 제어된다. Egress Sidecar는 Sandbox 생성 요청에 `networkPolicy`가 포함된 경우에만 주입되며, `[egress].mode` 설정에 따라서 세 가지 수준의 집행을 제공한다.

| Mode | 집행 방식 | 특징 |
|---|---|---|
| `dns` | DNS Proxy | Domain 단위 허용/거부. IP/CIDR Rule은 집행되지 않음 |
| `dns+nft` | DNS Proxy + nftables | Domain 단위에 더해 IP/CIDR 단위 차단 |
| `forward` | CONNECT Relay | 모든 Sandbox의 모든 TCP 연결을 지정된 Upstream Proxy로 강제 중계. `networkPolicy` 유무와 무관하게 모든 Sandbox에 Sidecar 주입 |

Egress 집행에서 주목할 부분은 **신뢰할 수 없는 Code를 전제로 한 Bootstrap 순서**이다. Kubernetes에서는 `egress-init` Init Container가 Workload Container가 시작되기 전에 Default-Deny nftables Fence를 먼저 설치하고, Egress Sidecar가 초기화를 완료하면 Fence를 실제 Policy로 원자적으로 교체한다. 이를 통해서 Sandbox Code가 Sidecar 초기화 이전의 시간 틈새를 이용하여 외부로 접근하는 것을 차단한다. 이는 협조적인 Workload를 전제로 하는 Service Mesh의 Sidecar 주입과 구별되는 지점이다.

Sandbox별 `networkPolicy`의 상세 Spec과 Volume, Snapshot을 포함한 BatchSandbox의 상세 동작은 [OpenSandbox BatchSandbox](../opensandbox-batch-sandbox/) 글에서 이어서 분석한다.

## 7. 참조

* [https://github.com/opensandbox-group/OpenSandbox](https://github.com/opensandbox-group/OpenSandbox)
* [https://github.com/opensandbox-group/OpenSandbox/blob/main/server/configuration.md](https://github.com/opensandbox-group/OpenSandbox/blob/main/server/configuration.md)
* [https://github.com/opensandbox-group/OpenSandbox/tree/main/manifests](https://github.com/opensandbox-group/OpenSandbox/tree/main/manifests)
* [https://github.com/kubernetes-sigs/agent-sandbox](https://github.com/kubernetes-sigs/agent-sandbox)
