---
title: Kubernetes Scheduler
draft: true
---

## 1. Kubernetes Scheduler

{{< figure caption="[Figure 1] kube-scheduler Architecture" src="images/scheduler-architecture.png" width="1000px" >}}

**Kubernetes Scheduler** (kube-scheduler)는 생성된 Pod를 어느 Node에서 실행할지 결정하는 Control Plane Component이다. kube-scheduler는 kube-apiserver를 Watch하여 Node가 결정되지 않은 Pod를 감지하고, Node 선별과 점수 계산을 거쳐서 최적의 Node를 선택한 뒤에 Pod의 `spec.nodeName`을 설정하는 Bind를 수행한다.

[Figure 1]은 kube-scheduler의 Architecture를 나타내고 있다. 전체 동작은 다음의 네 부분으로 구분된다.

* **Scheduler 지정** : Pod가 생성될 때 kube-apiserver의 Defaulting과 Mutating Admission 과정에서 해당 Pod를 담당할 Scheduler의 이름이 결정된다.
* **Scheduling Cycle** : Node가 결정되지 않은 Pod는 Informer의 Watch를 통해서 감지되어 Scheduling Queue에 저장되며, Scheduling Cycle이 Queue에서 Pod를 하나씩 꺼내서 Scheduling Framework Plugin을 통해서 Node를 결정한다.
* **Binding Cycle** : 결정된 Node로 Pod를 Bind하여 `spec.nodeName`을 설정하며, Goroutine을 통해서 비동기로 수행된다.
* **Scheduler Extender** : kube-scheduler의 재빌드 없이 Scheduling 동작을 확장하는 HTTP Webhook이며, 별도로 배포되는 Custom Scheduler와 함께 이용되기도 한다.

### 1.1. Scheduler 지정

```yaml {caption="[File 1] 기본 설정과 동일한 KubeSchedulerConfiguration Profile 예제", linenos=table}
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: default-scheduler
```

Scheduler의 이름은 kube-scheduler가 실행될 때 전달받는 KubeSchedulerConfiguration의 `profiles`에 정의되며, [File 1]은 기본 설정과 동일한 Profile 설정을 나타내고 있다. `profiles` 자체를 생략하거나 Profile의 `schedulerName`을 생략하면 kube-scheduler는 `default-scheduler` 이름이 설정된 하나의 Profile로 동작하며, 이 기본값 때문에 기본 Scheduler의 이름이 `default-scheduler`가 된다. 하나의 kube-scheduler에 다수의 Profile을 정의하면 Profile마다 다른 Plugin 구성을 갖는 다수의 Scheduler를 하나의 kube-scheduler Process가 함께 제공할 수도 있다.

```yaml {caption="[File 2] schedulerName을 생략한 Pod 생성 요청과 저장된 Pod 예제", linenos=table}
# Pod creation request (schedulerName omitted)
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.27
---
# Pod stored in kube-apiserver (schedulerName defaulted)
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  schedulerName: default-scheduler
  containers:
  - name: nginx
    image: nginx:1.27
```

Pod를 담당할 Scheduler는 Pod의 `spec.schedulerName`에 이름을 명시하여 지정하며, 생략하면 생성 시점에 자동으로 채워진다. [File 2]는 schedulerName을 생략한 Pod 생성 요청과 kube-apiserver에 저장된 Pod를 나타내고 있다. Pod 생성 요청이 kube-apiserver에 도달하면 요청을 객체로 변환하는 시점에 수행되는 **Defaulting** 단계에서 비어 있는 `schedulerName`에 `default-scheduler`가 설정되기 때문에, 저장된 모든 Pod는 담당 Scheduler의 이름을 항상 갖는다. 각 Scheduler는 자신의 Profile 이름과 일치하는 Pod만 Scheduling Queue에 넣기 때문에 하나의 Kubernetes Cluster에서 다수의 Scheduler를 함께 운영할 수 있으며, 존재하지 않는 Scheduler 이름이 명시된 Pod는 어느 Scheduler도 처리하지 않아 Pending 상태로 남는다.

```go {caption="[Code 1] Pod의 Defaulting 함수 (축약)", linenos=table}
// pkg/apis/core/v1/defaults.go
func SetDefaults_PodSpec(obj *v1.PodSpec) {
	if obj.RestartPolicy == "" {
		obj.RestartPolicy = v1.RestartPolicyAlways
	}
	if obj.DNSPolicy == "" {
		obj.DNSPolicy = v1.DNSClusterFirst
	}
	if obj.SchedulerName == "" {
		obj.SchedulerName = v1.DefaultSchedulerName // "default-scheduler"
	}
}
```

[Figure 1]의 Scheduler Assignment 영역과 같이 kube-apiserver가 생성 요청의 내용을 변형하는 단계는 두 곳이다. 요청 Body를 객체로 Decode하는 시점에 수행되는 Defaulting과, 이후 Admission 단계에서 수행되는 **Mutating Admission** (내장 Admission Plugin과 Mutating Admission Webhook)이다. `schedulerName`의 기본값은 Mutating Admission이 아니라 Defaulting 단계에서 설정되며, [Code 1]은 Pod의 Defaulting 함수를 축약하여 나타내고 있다. kube-apiserver는 API 버전마다 등록된 Defaulting 함수를 Decode 직후에 실행하며, `SetDefaults_PodSpec()`은 `restartPolicy`, `dnsPolicy` 같은 다른 필드의 기본값과 함께 비어 있는 `schedulerName`에 `DefaultSchedulerName` 상수의 값인 `default-scheduler`를 설정한다.

Defaulting이 Mutating Admission보다 먼저 수행되기 때문에, Mutating Admission Webhook이 Pod를 전달받는 시점에는 이미 `default-scheduler`가 설정되어 있다. 따라서 HAMi처럼 특정 Pod를 Custom Scheduler로 보내는 Middleware는 기본값이 설정된 `schedulerName`을 Admission 단계에서 자신의 Scheduler 이름으로 덮어쓰는 방식으로 동작하며, `schedulerName`은 생성 후에는 변경할 수 없는 필드이기 때문에 이러한 변경은 생성 시점에만 가능하다.

### 1.2. Scheduling Cycle

**Scheduling Cycle**은 Scheduling Queue에서 Pod를 하나씩 꺼내서 Node를 결정하는 직렬 과정이다. kube-scheduler는 Scheduling 과정을 Extension Point 단위로 나누고 각 Extension Point에 Plugin을 등록할 수 있는 **Scheduling Framework** 구조로 동작하며, Resource 검사나 Affinity 처리 같은 kube-scheduler의 기본 기능도 모두 내장 Plugin으로 구현되어 있다.

Custom Plugin도 `FilterPlugin`, `ScorePlugin`, `PermitPlugin` 같은 Go Interface를 구현하여 kube-scheduler Binary에 포함시키는 방식으로 추가할 수 있으며, 내장 Plugin과 동급으로 동작하기 때문에 모든 Extension Point와 QueueingHint까지 구현할 수 있다. 구현된 Plugin을 어느 Extension Point에서 활성화할지는 KubeSchedulerConfiguration의 Profile에 있는 `plugins` 설정으로 지정한다. Gang Scheduling을 구현한 scheduler-plugins의 Coscheduling Plugin이 QueueSort와 Permit Extension Point를 함께 이용하는 대표적인 예이다.

Node가 결정되지 않은 Pod는 먼저 **Scheduling Queue**에 저장되며, Scheduling Queue는 내부적으로 세 가지 영역으로 구분된다.

* **activeQ** : Scheduling을 대기하는 Pod가 저장되는 우선순위 Queue이다. 정렬 순서는 QueueSort Plugin이 결정하며, 기본 Plugin인 `PrioritySort`는 PriorityClass가 높은 Pod를 먼저 처리하도록 정렬한다.
* **backoffQ** : 재시도가 예정된 Pod가 Backoff 시간 동안 대기하는 Queue이다. 반복해서 실패하는 Pod가 직렬 구조의 Scheduling Cycle을 계속 점유하는 것을 막기 위한 영역이며, 실패 횟수에 따라서 지수적으로 증가하는 Backoff 시간 (기본 1초에서 최대 10초)이 지나면 activeQ로 이동한다.
* **unschedulablePods** : Cluster의 상태가 변하지 않는 한 재시도해도 같은 결과가 나오는 Pod가 저장되는 영역이다. 시간이 지나면 벗어나는 backoffQ와 다르게, Scheduling 가능성이 생기는 Cluster Event가 발생해야 벗어난다.

Scheduling에 실패한 Pod는 기본적으로 unschedulablePods에 저장된다. 모든 Node가 Filtering에서 탈락한 Pod는 Cluster의 상태가 변하지 않는 한 몇 번을 재시도해도 같은 결과가 나오기 때문에, Node 추가나 Pod 삭제 같은 Cluster Event가 발생하여 Scheduling 가능성이 생겼을 때만 unschedulablePods에서 벗어난다. 벗어나는 시점에 Backoff 시간이 남아 있으면 backoffQ를 거쳐서 activeQ로 이동하고 이미 지났으면 activeQ로 바로 이동하기 때문에, backoffQ는 unschedulablePods에서 activeQ로 돌아가는 길목의 완충 구간으로 동작한다.

단 모든 실패가 unschedulablePods를 거치는 것은 아니다. Scheduling이 진행되는 동안 Cluster Event가 발생한 경우에는 해당 Pod가 Event를 놓쳤을 가능성이 있기 때문에 Event를 기다리지 않고 바로 backoffQ로 이동하며, kube-apiserver 요청 오류 같은 일시적인 오류로 실패한 Pod도 Cluster의 변화와 무관하게 재시도가 필요하기 때문에 backoffQ로 이동한다. 또한 unschedulablePods에 일정 시간 (기본 5분) 이상 머문 Pod는 Event가 발생하지 않아도 주기적으로 backoffQ나 activeQ로 이동하는 안전장치도 존재한다.

Scheduling Cycle의 Extension Point는 다음과 같다.

* **PreFilter** : Filtering 전에 Pod의 요청 정보를 전처리하고 사전 조건을 검사한다.
* **Filter** : 각 Node가 Pod를 실행할 수 있는지 검사하여 불가능한 Node를 제외한다. Node의 가용 Resource를 검사하는 `NodeResourcesFit`, Node Affinity를 검사하는 `NodeAffinity`, Taint와 Toleration을 검사하는 `TaintToleration` Plugin이 대표적이다.
* **PostFilter** : 모든 Node가 Filtering에서 탈락한 경우에만 실행된다. 기본 Plugin인 `DefaultPreemption`은 우선순위가 낮은 Pod를 축출하여 배치 공간을 확보하는 Preemption을 수행한다.
* **PreScore, Score** : Filtering을 통과한 Node들의 점수를 계산하고, 가장 높은 점수의 Node를 선택한다. Resource 사용률의 균형을 평가하는 `NodeResourcesBalancedAllocation`, Container Image 보유 여부를 평가하는 `ImageLocality` Plugin이 대표적이다.
* **Reserve** : 선택된 Node에 Pod가 사용할 Resource를 kube-scheduler 내부 Cache에 미리 반영한다. Bind가 완료되기 전에도 다음 Pod의 Scheduling이 반영된 Resource 상태를 기준으로 수행되기 때문에, 비동기 Binding Cycle과 직렬 Scheduling Cycle이 공존할 수 있다.
* **Permit** : Bind 직전에 Pod의 Bind를 승인, 지연 또는 거부한다. 다수의 Pod가 함께 배치되어야 하는 Gang Scheduling 구현에 이용된다.

#### 1.2.1. QueueingHint

```go {caption="[Code 2] NodeAffinity Plugin의 QueueingHint 구현 (축약)", linenos=table}
// Register the cluster events NodeAffinity is interested in, with QueueingHintFns
func (pl *NodeAffinity) EventsToRegister(_ context.Context) ([]framework.ClusterEventWithHint, error) {
	return []framework.ClusterEventWithHint{
		{
			Event:          framework.ClusterEvent{Resource: framework.Node, ActionType: framework.Add | framework.UpdateNodeLabel},
			QueueingHintFn: pl.isSchedulableAfterNodeChange,
		},
	}, nil
}

// Called on Node Add/Update events to decide whether to retry the Pod
func (pl *NodeAffinity) isSchedulableAfterNodeChange(logger klog.Logger, pod *v1.Pod,
	oldObj, newObj interface{}) (framework.QueueingHint, error) {
	node := newObj.(*v1.Node)
	if matchesNodeAffinity(pod, node) {
		return framework.Queue, nil
	}
	return framework.QueueSkip, nil
}
```

Event와 Pod의 연관성은 각 Plugin이 제공하는 **QueueingHint**를 통해서 판단되며, [Code 2]는 NodeAffinity Plugin의 QueueingHint 구현을 축약하여 나타내고 있다. 각 Plugin은 자신의 판단 결과에 영향을 줄 수 있는 Cluster Event의 종류를 `EventsToRegister()`를 통해서 등록하고, Event마다 재시도 여부를 판단하는 QueueingHintFn을 함께 제공한다. kube-scheduler는 Pod가 Scheduling에 실패하면 거부한 Plugin의 이름을 Pod와 함께 기록해두고, 이후 Cluster Event가 발생하면 거부했던 Plugin의 QueueingHintFn만 호출하여 `Queue` 또는 `QueueSkip` 판정을 받는다.

예를 들어 Node Affinity 조건을 만족하는 Node가 없어서 unschedulablePods에 저장된 Pod가 있을 때 새로운 Node가 추가되면, NodeAffinity Plugin의 QueueingHintFn은 추가된 Node의 Label이 Pod의 Node Affinity를 만족하는지 검사한다. 만족하면 `Queue` 판정으로 Pod가 activeQ나 backoffQ로 이동하여 Scheduling이 재시도되고, 만족하지 않으면 `QueueSkip` 판정으로 Pod는 unschedulablePods에 그대로 남는다. QueueingHint가 도입되기 전에는 Event의 종류만으로 Pod의 이동을 결정했기 때문에 성공 가능성이 없는 Scheduling 재시도가 반복되었지만, QueueingHint는 Event의 내용까지 검사하기 때문에 불필요한 재시도가 제거된다.

QueueingHint는 Kubernetes 1.28에 `SchedulerQueueingHints` Feature Gate와 함께 Alpha로 도입되었고, Event 판단을 위한 메모리 사용량 증가 문제로 한동안 기본 비활성화를 거친 뒤에 1.32부터 기본 활성화되었다. 한편 DRA Plugin처럼 외부 Controller의 동작을 기다리기 위해서 Pod를 Pending 상태로 거부하는 Plugin의 경우에는, 거부가 kube-scheduler의 잘못된 판단이 아니기 때문에 `Queue` 판정 시 backoffQ를 거치지 않고 activeQ로 바로 이동하여 대기 시간을 줄인다.

### 1.3. Binding Cycle

**Binding Cycle**은 Scheduling Cycle이 결정한 Node로 Pod를 Bind하는 과정이다. Goroutine을 통해서 비동기로 수행되며, Scheduling Cycle의 Reserve 단계에서 Pod가 사용할 Resource가 kube-scheduler 내부 Cache에 미리 반영되기 때문에 Bind가 완료되기 전에도 다음 Pod의 Scheduling이 시작될 수 있다. Binding Cycle의 Extension Point는 다음과 같다.

* **PreBind** : Bind 전에 필요한 준비 작업을 수행한다. Volume을 Node에 Attach하는 `VolumeBinding` Plugin이 대표적이다.
* **Bind** : kube-apiserver에 Binding 요청을 전송하여 Pod의 `spec.nodeName`을 설정한다. 설정된 Node 정보는 kube-apiserver를 통해서 etcd에 기록되며, 해당 Node의 kubelet이 이를 감지하여 Pod를 실행한다.
* **PostBind** : Bind 완료 후 정리 작업을 수행한다.

### 1.4. Scheduler Extender

```yaml {caption="[File 3] Scheduler Extender 설정 예제", linenos=table}
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

**Scheduler Extender**는 kube-scheduler의 재빌드 없이 Scheduling 동작을 확장하는 HTTP Webhook 방식의 확장 지점이며, [File 3]과 같이 KubeSchedulerConfiguration의 `extenders`에 Webhook 서버를 등록하여 이용한다. Extender는 Node를 선별하는 `filter`, Node의 점수를 계산하는 `prioritize`, Bind를 대신 수행하는 `bind`, Preemption의 축출 대상 선정에 개입하는 `preempt` 네 가지 Verb를 제공하며, kube-scheduler는 각 단계에서 명시된 URL로 HTTP 요청을 전송하여 Extender의 판단을 반영한다. [Figure 1]에서 강조된 Filter, PostFilter, Score, Bind가 네 가지 Verb에 대응하는 Extension Point이다.

Scheduling Framework Plugin 방식과 다르게 개입 지점이 네 가지 Verb에 대응하는 Extension Point로 제한되기 때문에 Reserve나 Permit 같은 나머지 Extension Point에는 개입할 수 없고, 모든 판단이 HTTP 왕복을 거치기 때문에 Scheduling 지연이 커진다. `managedResources`에는 Extender가 담당하는 Resource를 명시하며, 해당 Resource를 요청하는 Pod에만 Extender가 호출된다. `ignoredByScheduler`가 `true`로 설정되어 있으면 해당 Resource는 kube-scheduler의 기본 Resource 검사에서 제외되어 Extender가 할당 가능 여부를 전담한다.

Scheduler Extender는 별도의 Scheduler를 배포하고 Pod의 `spec.schedulerName`으로 해당 Scheduler를 지정하는 **Custom Scheduler** 방식과 함께 이용되기도 한다. GPU 공유 Middleware인 HAMi의 hami-scheduler가 대표적인 예이며, kube-scheduler와 Scheduler Extender를 하나의 Pod로 배포하고 Mutating Webhook을 통해서 vGPU Pod의 `spec.schedulerName`을 hami-scheduler로 변경하는 방식으로 동작한다.

## 2. 참조

* Kubernetes Scheduler : [https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)
* Kubernetes Scheduling Framework : [https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/](https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/)
* Kubernetes Scheduler Configuration : [https://kubernetes.io/docs/reference/scheduling/config/](https://kubernetes.io/docs/reference/scheduling/config/)
* Scheduler Extender Design : [https://github.com/kubernetes/design-proposals-archive/blob/main/scheduling/scheduler_extender.md](https://github.com/kubernetes/design-proposals-archive/blob/main/scheduling/scheduler_extender.md)
* scheduler-plugins : [https://github.com/kubernetes-sigs/scheduler-plugins](https://github.com/kubernetes-sigs/scheduler-plugins)
