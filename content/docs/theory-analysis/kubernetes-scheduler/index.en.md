---
title: "Kubernetes Scheduler"
---

## 1. Kubernetes Scheduler

{{< figure caption="[Figure 1] kube-scheduler Architecture" src="images/scheduler-architecture.png" width="1000px" >}}

**Kubernetes Scheduler** (kube-scheduler) is the Control Plane Component that decides which Node a created Pod runs on. [Figure 1] shows the Architecture of kube-scheduler, and the overall operation is divided into the following four parts.

* **Scheduler Assignment** : When a Pod is created, the name of the Scheduler responsible for the Pod is determined during the Defaulting and Mutating Admission processes of kube-apiserver.
* **Scheduling Cycle** : Pods without a decided Node are detected through the Informer's Watch and stored in the Scheduling Queue, and the Scheduling Cycle pops Pods from the Queue one by one and decides a Node through Scheduling Framework Plugins.
* **Binding Cycle** : Binds the Pod to the decided Node by setting `spec.nodeName`, and is performed asynchronously through a Goroutine.
* **Scheduler Extension** : The Scheduling behavior can be extended through Scheduling Framework Plugins included in kube-scheduler and the HTTP Webhook based Scheduler Extender, and they are also used together with separately deployed Custom Schedulers.

### 1.1. Scheduler Assignment

Each Scheduler running in a Kubernetes Cluster has a unique name, and the Scheduler responsible for a Pod is designated by specifying the Scheduler's name in the Pod's `spec.schedulerName`. Since each Scheduler takes only the Pods that match its own name and performs Scheduling, multiple Schedulers can be operated together in one Kubernetes Cluster based on names. Conversely, a Pod with a nonexistent Scheduler name specified remains in the Pending state because no Scheduler takes it.

```yaml {caption="[File 1] KubeSchedulerConfiguration Profile example identical to the default settings", linenos=table}
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: default-scheduler
```

The name of kube-scheduler, the default Scheduler, is defined in the `profiles` of the KubeSchedulerConfiguration received through the `--config` parameter at startup, and [File 1] shows a Profile setting identical to the default settings. If `profiles` itself is omitted or the Profile's `schedulerName` is omitted, kube-scheduler operates with a single Profile set to the name `default-scheduler`, and because of this default value, the name of the Default Scheduler becomes `default-scheduler`.

```yaml {caption="[File 2] KubeSchedulerConfiguration example defining multiple Profiles", linenos=table}
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: default-scheduler
- schedulerName: no-scoring-scheduler
  plugins:
    preScore:
      disabled:
      - name: '*'
    score:
      disabled:
      - name: '*'
```

[File 2] shows an example of a KubeSchedulerConfiguration defining two Profiles. The `default-scheduler` Profile operates as the Default Scheduler as it is because the Plugin configuration is not changed, and the `no-scoring-scheduler` Profile disables all Plugins of the PreScore and Score stages through the `plugins` setting, providing a Scheduler that decides a Node quickly without score calculation. By defining different Plugin configurations per Profile like this, a single kube-scheduler can operate multiple Schedulers with different Scheduling behaviors.

```yaml {caption="[File 3] Pod creation request with schedulerName omitted and the stored Pod example", linenos=table}
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

[File 3] shows a Pod creation request with schedulerName omitted and the Pod stored in kube-apiserver. Since the omitted `spec.schedulerName` is automatically filled in the **Defaulting** stage of kube-apiserver, every stored Pod always has the name of its responsible Scheduler.

```go {caption="[Code 1] Pod's Defaulting function (abbreviated)", linenos=table}
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

Defaulting is the stage where kube-apiserver fills empty fields with the Defaulting functions registered per API version right after Decoding the request Body into an object, as shown in the Scheduler Assignment area of [Figure 1], and [Code 1] shows the Pod's Defaulting function in abbreviated form. `SetDefaults_PodSpec()` sets `default-scheduler`, the value of the `DefaultSchedulerName` constant, to the empty `schedulerName`, together with the default values of other fields such as `restartPolicy` and `dnsPolicy`.

Since the **Mutating Admission** stage is performed after Defaulting, `schedulerName` is already filled with `default-scheduler` at the time a Mutating Admission Webhook receives the Pod. Therefore, Middleware that wants to send specific Pods to a Custom Scheduler operates by overwriting the filled `schedulerName` with its own Scheduler name in the Mutating Webhook, and since `schedulerName` is a field that cannot be changed after creation, such a change is possible only at creation time.

### 1.2. Scheduling Cycle

**Scheduling Cycle** is a serial process that pops Pods one by one from the Scheduling Queue and decides a Node. kube-scheduler operates with the **Scheduling Framework** structure that divides the Scheduling process into Extension Points, and the basic features of kube-scheduler such as Resource checking and Affinity handling are also all implemented as built-in Plugins operating at each Extension Point.

#### 1.2.1. Scheduling Queue

Pods without a decided Node are first stored in the **Scheduling Queue**, and the Scheduling Queue is internally divided into three areas.

* **activeQ** : A priority Queue storing Pods waiting for Scheduling. The sort order is decided by the QueueSort Plugin, and the default Plugin `PrioritySort` sorts Pods so that Pods with a higher PriorityClass are processed first.
* **backoffQ** : A Queue where Pods scheduled for retry wait during the Backoff time. It is an area to prevent repeatedly failing Pods from continuously occupying the serial Scheduling Cycle, and Pods move to activeQ after the Backoff time that increases exponentially with the number of failures (from 1 second up to 10 seconds by default) passes.
* **unschedulablePods** : An area storing Pods that would get the same result even if retried unless the Cluster's state changes. Unlike backoffQ, which Pods leave as time passes, Pods leave this area only when a Cluster Event that creates a possibility of Scheduling occurs.

Pods that fail Scheduling are stored in unschedulablePods by default. A Pod for which every Node was rejected in Filtering gets the same result no matter how many times it is retried unless the Cluster's state changes, so it leaves unschedulablePods only when a Cluster Event such as Node addition or Pod deletion occurs and creates a possibility of Scheduling. At the time of leaving, if the Backoff time remains, the Pod moves to activeQ via backoffQ, and if it has already passed, the Pod moves directly to activeQ, so backoffQ acts as a buffer section on the way back from unschedulablePods to activeQ.

However, not every failure goes through unschedulablePods. Cluster Events that occurred while Scheduling was in progress may have been missed by the Pod, so kube-scheduler records them separately, and when the Pod fails and returns to the Queue, the recorded Events are examined and, if a possibility of Scheduling has arisen, the Pod moves to backoffQ without going through unschedulablePods. Also, Pods that failed due to temporary errors such as kube-apiserver request errors move to backoffQ because they need retry regardless of Cluster changes, and there is also a safeguard where Pods that have stayed in unschedulablePods longer than a certain time (5 minutes by default) periodically move to backoffQ or activeQ even without an Event.

#### 1.2.2. QueueingHint

```go {caption="[Code 2] QueueingHint implementation of the NodeAffinity Plugin (abbreviated)", linenos=table}
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

The relevance between an Event and a Pod is judged through the **QueueingHint** provided by each Plugin, and [Code 2] shows the QueueingHint implementation of the NodeAffinity Plugin in abbreviated form. Each Plugin registers the kinds of Cluster Events that can affect its judgment through `EventsToRegister()`, and provides a QueueingHintFn that judges whether to retry for each Event. When a Pod fails Scheduling, kube-scheduler records the names of the Plugins that rejected it together with the Pod, and when a Cluster Event occurs afterwards, it calls only the QueueingHintFns of the rejecting Plugins to receive a `Queue` or `QueueSkip` verdict.

For example, when there is a Pod stored in unschedulablePods because no Node satisfies its Node Affinity condition and a new Node is added, the QueueingHintFn of the NodeAffinity Plugin examines whether the added Node's Labels satisfy the Pod's Node Affinity. If satisfied, the Pod moves to activeQ or backoffQ with a `Queue` verdict and Scheduling is retried, and if not, the Pod stays in unschedulablePods with a `QueueSkip` verdict. Before QueueingHint was introduced, Pod movement was decided only by the kind of Event, so Scheduling retries with no possibility of success were repeated, but QueueingHint examines even the content of the Event, so unnecessary retries are eliminated.

QueueingHint was introduced as Alpha in Kubernetes 1.28 with the `SchedulerQueueingHints` Feature Gate, and after a period of being disabled by default due to the increased memory usage for Event judgment, it has been enabled by default since 1.32. Meanwhile, in the case of Plugins that reject Pods in the Pending state to wait for the operation of external Controllers, such as the DRA Plugin, the rejection is not a wrong judgment of kube-scheduler, so on a `Queue` verdict the Pod moves directly to activeQ without going through backoffQ to reduce the waiting time.

#### 1.2.3. Extension Point

The Extension Points of the Scheduling Cycle are as follows.

* **PreFilter** : Preprocesses the Pod's request information and checks preconditions before Filtering.
* **Filter** : Checks whether each Node can run the Pod and excludes impossible Nodes. Representative Plugins are `NodeResourcesFit` which checks the Node's available Resources, `NodeAffinity` which checks Node Affinity, and `TaintToleration` which checks Taints and Tolerations.
* **PostFilter** : Runs only when every Node has been rejected in Filtering. The default Plugin `DefaultPreemption` performs Preemption, which evicts lower-priority Pods to secure placement space.
* **PreScore** : Receives the list of Nodes that passed Filtering before Scoring, and precomputes and stores information commonly needed for score calculation.
* **Score** : Calculates the score of each Node, and selects the Node with the highest score summed with weights applied per Plugin. Representative Plugins are `NodeResourcesBalancedAllocation` which evaluates the balance of Resource utilization, and `ImageLocality` which evaluates whether the Node has the Container Image.
* **Reserve** : Reflects the Resources the Pod will use on the selected Node in kube-scheduler's internal Cache in advance.
* **Permit** : Approves, delays, or rejects the Pod's Bind right before Bind. It is used to implement Gang Scheduling, where multiple Pods must be placed together.

### 1.3. Binding Cycle

**Binding Cycle** is the process of Binding a Pod to the Node decided by the Scheduling Cycle. Since Bind is a slow operation that sends a request to kube-apiserver and waits for the response, kube-scheduler separates the Binding Cycle into a separate Goroutine to perform it asynchronously, and starts the Scheduling of the next Pod immediately without waiting for the Bind to complete.

This asynchronous structure creates a risk of Resources being placed in duplicate. A Node's remaining Resources are calculated by excluding the requests of the Pods whose `spec.nodeName` is set to that Node, but a Pod whose Bind has not finished does not have `spec.nodeName` yet and is missing from this calculation, so the next Pod being Scheduled in the meantime can take the same Resources again. kube-scheduler reflects the Resources the Pod will use in its internal Cache in advance at the Reserve stage of the Scheduling Cycle, and the Scheduling of the next Pod judges based on this Cache, so the decided placement is included in the calculation even before the Bind finishes and duplicate placement is prevented. The Extension Points of the Binding Cycle are as follows.

* **PreBind** : Performs preparation work needed before Bind. The representative Plugin is `VolumeBinding`, which Attaches Volumes to the Node.
* **Bind** : Sends a Binding request to kube-apiserver to set the Pod's `spec.nodeName`. The set Node information is recorded in etcd through kube-apiserver, and the kubelet of that Node detects it and runs the Pod.
* **PostBind** : Performs cleanup work after the Bind completes.

### 1.4. Scheduler Extension

The Scheduling behavior of kube-scheduler can be extended in two ways: Scheduling Framework Plugins and the Scheduler Extender.

#### 1.4.1. Scheduling Framework Plugin

```go {caption="[Code 3] Plugin Interfaces of the Scheduling Framework (abbreviated)", linenos=table}
// pkg/scheduler/framework/interface.go
type Plugin interface {
	Name() string
}

type FilterPlugin interface {
	Plugin
	Filter(ctx context.Context, state *CycleState, pod *v1.Pod, nodeInfo *NodeInfo) *Status
}

type ScorePlugin interface {
	Plugin
	Score(ctx context.Context, state *CycleState, pod *v1.Pod, nodeName string) (int64, *Status)
	ScoreExtensions() ScoreExtensions
}
```

The **Scheduling Framework Plugin** method implements Custom Plugins and registers them at Extension Points, and [Code 3] shows the Plugin Interfaces defined by the Scheduling Framework in abbreviated form. Every Plugin implements the `Plugin` Interface, which returns its name, as the base, and additionally implements the Interfaces corresponding to the Extension Points where it operates, such as `FilterPlugin`, `ScorePlugin`, and `PermitPlugin`. Since Custom Plugins operate in the same way as built-in Plugins, they can implement every Extension Point and even QueueingHint.

```go {caption="[Code 4] Implementation and registration example of a Custom Filter Plugin", linenos=table}
const Name = "ExampleFilter"

type ExampleFilter struct{}

func (pl *ExampleFilter) Name() string { return Name }

// Called per node, excludes nodes under maintenance
func (pl *ExampleFilter) Filter(ctx context.Context, state *framework.CycleState,
	pod *v1.Pod, nodeInfo *framework.NodeInfo) *framework.Status {
	if nodeInfo.Node().Labels["example.io/maintenance"] == "true" {
		return framework.NewStatus(framework.Unschedulable, "node under maintenance")
	}
	return framework.NewStatus(framework.Success)
}

func New(_ context.Context, _ runtime.Object, _ framework.Handle) (framework.Plugin, error) {
	return &ExampleFilter{}, nil
}

// Build a kube-scheduler binary including the custom plugin
func main() {
	command := app.NewSchedulerCommand(app.WithPlugin(Name, New))
	command.Execute()
}
```

[Code 4] shows an implementation and registration example of a Custom Filter Plugin that excludes Nodes with the Maintenance Label set. `Filter()` is called per Node in the Filtering stage and returns a `Success` or `Unschedulable` Status, and the implemented Plugin must be registered with `app.WithPlugin()` and kube-scheduler must be rebuilt. In the rebuilt kube-scheduler, at which Extension Point the Plugin is enabled is designated by specifying the Plugin name in the `plugins` setting of the KubeSchedulerConfiguration's Profile.

The scheduler-plugins Project, the official Kubernetes Plugin collection, uses this method, and the Coscheduling Plugin of scheduler-plugins, which implements Gang Scheduling, is a representative example that uses the QueueSort and Permit Extension Points together.

#### 1.4.2. Scheduler Extender

```yaml {caption="[File 4] Scheduler Extender configuration example", linenos=table}
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

**Scheduler Extender** is an HTTP Webhook based extension point that extends the Scheduling behavior without rebuilding kube-scheduler, and it is used by registering a Webhook server in the `extenders` of KubeSchedulerConfiguration as shown in [File 4]. The Extender provides four Verbs: `filter` which selects Nodes, `prioritize` which calculates Node scores, `bind` which performs Bind on behalf of kube-scheduler, and `preempt` which intervenes in selecting the eviction targets of Preemption, and kube-scheduler sends HTTP requests to the specified URL at each stage to reflect the Extender's judgment. Filter, PostFilter, Score, and Bind highlighted in [Figure 1] are the Extension Points corresponding to the four Verbs.

Unlike the Scheduling Framework Plugin method, the intervention points are limited to these four, so it cannot intervene in the remaining Extension Points such as Reserve or Permit, and since every judgment goes through an HTTP round trip, the Scheduling latency increases. `managedResources` specifies the Resources the Extender is responsible for, and the Extender is called only for Pods requesting those Resources. If `ignoredByScheduler` is set to `true`, the Resource is excluded from kube-scheduler's basic Resource checking, and the Extender takes full charge of judging whether allocation is possible.

The Scheduler Extender is also used together with separately deployed Custom Schedulers. hami-scheduler of HAMi, a GPU sharing Middleware, is a representative example, and it operates by deploying kube-scheduler and the Scheduler Extender as a single Pod and changing the `spec.schedulerName` of vGPU Pods to hami-scheduler through a Mutating Webhook.

## 2. References

* Kubernetes Scheduler : [https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)
* Kubernetes Scheduling Framework : [https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/](https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/)
* Kubernetes Scheduler Configuration : [https://kubernetes.io/docs/reference/scheduling/config/](https://kubernetes.io/docs/reference/scheduling/config/)
* Scheduler Extender Design : [https://github.com/kubernetes/design-proposals-archive/blob/main/scheduling/scheduler_extender.md](https://github.com/kubernetes/design-proposals-archive/blob/main/scheduling/scheduler_extender.md)
* scheduler-plugins : [https://github.com/kubernetes-sigs/scheduler-plugins](https://github.com/kubernetes-sigs/scheduler-plugins)
