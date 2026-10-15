---
title: Kubernetes Scheduler
draft: true
---

## 1. Kubernetes Scheduler

{{< figure caption="[Figure 1] kube-scheduler Architecture" src="images/scheduler-architecture.png" width="900px" >}}

**Kubernetes Scheduler** (kube-scheduler)는 생성된 Pod를 어느 Node에서 실행할지 결정하는 Control Plane Component이다. kube-scheduler는 kube-apiserver를 Watch하여 Node가 결정되지 않은 Pod를 감지하고, Node 선별과 점수 계산을 거쳐서 최적의 Node를 선택한 뒤에 Pod의 `spec.nodeName`을 설정하는 Bind를 수행한다. Pod의 `spec.schedulerName`에는 해당 Pod의 Scheduling을 담당할 Scheduler의 이름을 명시할 수 있으며, 기본 Scheduler는 `default-scheduler` 이름을 이용한다. 각 Scheduler는 자신의 이름이 명시된 Pod만 처리하기 때문에 하나의 Kubernetes Cluster에서 다수의 Scheduler를 함께 운영할 수 있다.

[Figure 1]은 kube-scheduler의 Architecture를 나타내고 있다. Informer가 Watch를 통해서 감지한 미배치 Pod는 Scheduling Queue에 저장되고, Scheduling Cycle이 Queue에서 Pod를 하나씩 꺼내서 Node를 결정하며, Binding Cycle이 결정된 Node로 Bind를 수행한다. Scheduling Cycle은 한 번에 하나의 Pod만 처리하는 직렬 구조이지만, Binding Cycle은 Goroutine을 통해서 비동기로 처리되기 때문에 Bind가 완료되기 전에 다음 Pod의 Scheduling이 시작될 수 있다.

### 1.1. Scheduling Queue

Scheduling Queue는 미배치 Pod를 저장하는 Queue이며, 내부적으로 세 가지 영역으로 구분된다.

* **activeQ** : Scheduling을 대기하는 Pod가 저장되는 우선순위 Queue이다. 정렬 순서는 QueueSort Plugin이 결정하며, 기본 Plugin인 `PrioritySort`는 PriorityClass가 높은 Pod를 먼저 처리하도록 정렬한다.
* **backoffQ** : Scheduling에 실패한 Pod가 재시도 전에 대기하는 Queue이다. 실패 횟수에 따라서 지수적으로 증가하는 Backoff 시간이 지나면 activeQ로 이동한다.
* **unschedulablePods** : 모든 Node가 Filtering에서 탈락하여 Scheduling이 불가능하다고 판정된 Pod가 저장되는 영역이다. Node 추가나 Pod 삭제 같은 Cluster Event가 발생하면 해당 Event로 Scheduling 가능성이 생긴 Pod만 activeQ나 backoffQ로 이동하며, Event와 Pod의 연관성은 각 Plugin이 제공하는 QueueingHint를 통해서 판단된다.

### 1.2. Scheduling Framework

{{< figure caption="[Figure 2] Scheduling Framework Extension Points" src="images/scheduling-framework.png" width="1000px" >}}

kube-scheduler는 **Scheduling Framework** 구조로 동작한다. Scheduling Framework는 Scheduling 과정을 Extension Point 단위로 나누고 각 Extension Point에 Plugin을 등록할 수 있는 구조이며, Resource 검사나 Affinity 처리 같은 kube-scheduler의 기본 기능도 모두 내장 Plugin으로 구현되어 있다. [Figure 2]는 Scheduling Framework의 Extension Point를 나타내고 있다. Scheduling Cycle의 Extension Point는 다음과 같다.

* **PreFilter** : Filtering 전에 Pod의 요청 정보를 전처리하고 사전 조건을 검사한다.
* **Filter** : 각 Node가 Pod를 실행할 수 있는지 검사하여 불가능한 Node를 제외한다. Node의 가용 Resource를 검사하는 `NodeResourcesFit`, Node Affinity를 검사하는 `NodeAffinity`, Taint와 Toleration을 검사하는 `TaintToleration` Plugin이 대표적이다.
* **PostFilter** : 모든 Node가 Filtering에서 탈락한 경우에만 실행된다. 기본 Plugin인 `DefaultPreemption`은 우선순위가 낮은 Pod를 축출하여 배치 공간을 확보하는 Preemption을 수행한다.
* **PreScore, Score** : Filtering을 통과한 Node들의 점수를 계산하고, 가장 높은 점수의 Node를 선택한다. Resource 사용률의 균형을 평가하는 `NodeResourcesBalancedAllocation`, Container Image 보유 여부를 평가하는 `ImageLocality` Plugin이 대표적이다.
* **Reserve** : 선택된 Node에 Pod가 사용할 Resource를 kube-scheduler 내부 Cache에 미리 반영한다. Bind가 완료되기 전에도 다음 Pod의 Scheduling이 반영된 Resource 상태를 기준으로 수행되기 때문에, 비동기 Binding Cycle과 직렬 Scheduling Cycle이 공존할 수 있다.
* **Permit** : Bind 직전에 Pod의 Bind를 승인, 지연 또는 거부한다. 다수의 Pod가 함께 배치되어야 하는 Gang Scheduling 구현에 이용된다.

Binding Cycle의 Extension Point는 다음과 같다.

* **PreBind** : Bind 전에 필요한 준비 작업을 수행한다. Volume을 Node에 Attach하는 `VolumeBinding` Plugin이 대표적이다.
* **Bind** : kube-apiserver에 Binding 요청을 전송하여 Pod의 `spec.nodeName`을 설정한다.
* **PostBind** : Bind 완료 후 정리 작업을 수행한다.

### 1.3. Scheduler 확장

{{< figure caption="[Figure 3] Scheduler Extender" src="images/scheduler-extender.png" width="700px" >}}

kube-scheduler의 Scheduling 동작을 확장하는 방법은 세 가지가 존재한다.

* **Scheduling Framework Plugin** : Extension Point에 Custom Plugin을 구현하고 kube-scheduler를 다시 Build하는 방식이다. 모든 Extension Point를 이용할 수 있어 가장 유연하지만 kube-scheduler의 재빌드가 필요하며, Kubernetes 공식 Plugin 모음인 scheduler-plugins Project가 이 방식을 이용한다.
* **Scheduler Extender** : kube-scheduler의 설정에 HTTP Webhook 서버를 등록하는 방식이다. 재빌드 없이 확장할 수 있지만 이용할 수 있는 Extension Point가 제한적이고 HTTP 통신 비용이 발생한다.
* **Custom Scheduler** : 별도의 Scheduler를 배포하고 Pod의 `spec.schedulerName`으로 해당 Scheduler를 지정하는 방식이다.

```yaml {caption="[File 1] Scheduler Extender 설정 예제", linenos=table}
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
extenders:
- urlPrefix: "http://127.0.0.1:8080"
  filterVerb: filter
  prioritizeVerb: prioritize
  bindVerb: bind
  weight: 1
  managedResources:
  - name: nvidia.com/gpu
    ignoredByScheduler: true
```

[Figure 3]은 Scheduler Extender의 구조를 나타내고 있고, [File 1]은 KubeSchedulerConfiguration의 Scheduler Extender 설정 예제를 나타내고 있다. Extender는 Node를 선별하는 `filter`, Node의 점수를 계산하는 `prioritize`, Bind를 대신 수행하는 `bind` 세 가지 Verb를 제공하며, kube-scheduler는 각 단계에서 명시된 URL로 HTTP 요청을 전송하여 Extender의 판단을 반영한다. `managedResources`에는 Extender가 담당하는 Resource를 명시하며, 해당 Resource를 요청하는 Pod에만 Extender가 호출된다. `ignoredByScheduler`가 `true`로 설정되어 있으면 해당 Resource는 kube-scheduler의 기본 Resource 검사에서 제외되어 Extender가 할당 가능 여부를 전담한다.

Scheduler Extender와 Custom Scheduler 방식은 함께 이용되기도 한다. GPU 공유 Middleware인 HAMi의 hami-scheduler가 대표적인 예이며, kube-scheduler와 Scheduler Extender를 하나의 Pod로 배포하고 Mutating Webhook을 통해서 vGPU Pod의 `spec.schedulerName`을 hami-scheduler로 변경하는 방식으로 동작한다.

## 2. 참조

* Kubernetes Scheduler : [https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)
* Kubernetes Scheduling Framework : [https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/](https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/)
* Kubernetes Scheduler Configuration : [https://kubernetes.io/docs/reference/scheduling/config/](https://kubernetes.io/docs/reference/scheduling/config/)
* Scheduler Extender Design : [https://github.com/kubernetes/design-proposals-archive/blob/main/scheduling/scheduler_extender.md](https://github.com/kubernetes/design-proposals-archive/blob/main/scheduling/scheduler_extender.md)
* scheduler-plugins : [https://github.com/kubernetes-sigs/scheduler-plugins](https://github.com/kubernetes-sigs/scheduler-plugins)
