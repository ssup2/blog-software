---
title: Controller Development using Kubernetes Kubebuilder
---

This document analyzes Kubebuilder and Controllers through a Memcached example.

## 1. Kubebuilder

Kubebuilder is an SDK that helps develop Kubernetes Controllers. It helps easily define **Kubernetes CRs (Custom Resources)** desired by users and develop **Controllers** that manage the defined Kubernetes CRs. Kubebuilder automatically generates most files related to Kubernetes CRs. Since developers only need to modify the generated Kubernetes CR-related files, they can easily define and use Kubernetes CRs.

Also, Kubebuilder creates Controller Manager Projects that comply with Standard Golang Project Layout. Here, Controller Manager means a component that performs the role of managing multiple Controllers. That is, developers can easily develop Controller Managers containing multiple Controllers using Kubebuilder. Not only Controllers that manage Kubernetes CRs but also Controllers that control Resources (Objects) provided by default in Kubernetes can be developed.

### 1.1. Controller Manager Architecture

{{< figure caption="[Figure 1] Controller Manager Architecture" src="images/controller-manager-architecture.png" width="800px" >}}

[Figure 1] shows the Architecture of a Controller Manager implemented with Kubebuilder. Controller Manager consists of Kubernetes Cache, Kubernetes Client, WorkQueue, and Controller. **Kubernetes Cache** performs the role of Caching information retrieved from Kubernetes API Server to reduce the load on Kubernetes API Server. Informers exist inside Kubernetes Cache. **Informer** performs the role of Watching Objects (Resources) that Controllers must manage and receiving creation/deletion/change Events of Objects. Object Event information received by Informers is extracted as only the Object's Name and Namespace information where the Object is located and Enqueued to the Work Queue.

**Kubernetes Client** performs the role of a Client for Controllers to communicate with Kubernetes APIs. By default, there is one Kubernetes Client Instance in Manager, and multiple Controllers share and use one Kubernetes Client Instance. By default, Object (Resource) Write requests from Kubernetes Client are directly delivered to Kubernetes API Server, but Object Read requests from Kubernetes Client are delivered to Kubernetes Cache instead of Kubernetes API Server. However, developers can configure Kubernetes Client not to use Kubernetes Client through settings.

**Work Queue** stores Name/Namespace information of Objects where Events put by Informers occurred. There is a dedicated Work Queue for each Controller. The **Reconciler** of Controllers Dequeues Name/Namespace information of Objects where Events stored in Work Queue occurred, then performs the role of controlling Objects using Kubernetes Client. Here, Reconciler controlling Objects means the work of matching Object's Spec and Status.

Reconciler discards Object information for Objects that succeeded in control. However, for Objects that Reconciler failed to control, Name/Namespace information of those Objects is Requeued and stored back in Work Queue. After a certain time passes, Reconciler Dequeues Objects that failed control from Work Queue again and attempts control again. If Object control fails again, it is Requeued to Work Queue again, repeating until control succeeds. The time Objects wait in Work Queue increases Exponentially according to the number of times Objects are Requeued and stored in Work Queue.

Due to Kubernetes Cache used by Kubernetes Client, when Reconciler reads Objects changed and stored through Kubernetes Client again through Kubernetes Client, it can get Objects before changes again. To prevent problems caused by this characteristic, Object control Logic performed by Reconciler must satisfy **idempotency** that can obtain the same results even if performed multiple times. That is, Reconciler must have a Stateless characteristic that does not have State.

### 1.2. Controller Manager HA

Since Controller Manager is also a Pod (App) that runs on Kubernetes, it is good to run multiple identical Controller Managers simultaneously for HA of Controller Manager. When running multiple identical Controller Managers, only one Controller Manager actually operates and the remaining Controller Managers maintain a waiting state, operating in **Active-standby** form. You can use Controller Manager HA functionality by setting the 'enable-leader-election' option when running Controller Manager.

### 1.3. Controller Metric, kube-rbac-proxy

Controllers provide Controller Metric information, which is their own Metric information. Access rights to Controller Metric information are determined by kube-rbac-proxy, a Proxy Server that runs together inside Controller Pods. [Figure 1] shows the process of Controller Metric information being transmitted through kube-rbac-proxy.

## 2. Memcached Controller

Define a Memcached CR using Kubebuilder and develop a Memcached Controller that controls the Memcached CR. The complete Code of Controller Manager and Memcached Controller included in Controller Manager can be found at the link below.

* [https://github.com/ssup2/example-k8s-kubebuilder](https://github.com/ssup2/example-k8s-kubebuilder)

### 2.1. Development Environment

The development environment is as follows.
* Ubuntu 18.04 LTS, root user
* Kubernetes 1.23.4
* golang 1.17.6
* kubebuilder 3.3.0

### 2.2. Kubebuilder Installation

```shell {caption="[Shell 1] Kubebuilder Installation"}
$ curl -L -o kubebuilder "https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)"
$ chmod +x kubebuilder && mv kubebuilder /usr/local/bin/
```

Install the Kubebuilder SDK CLI.

### 2.3. Project Creation

```shell {caption="[Shell 2] Project Creation"}
$ export GO111MODULE=on
$ kubebuilder init --domain cache.example.com --repo github.com/ssup2/example-k8s-kubebuilder
$ ls
Dockerfile  Makefile  PROJECT  config  go.mod  go.sum  hack  main.go
```

Create a Memcached Operator Project through the `kubebuilder init` command. [Shell 2] shows the process of creating a Project using Kubebuilder. The domain that comes as an Option with `init` represents the Domain for API Group. The repo that comes as an Option with `init` means Git Repo. `Makefile` helps easily perform operations such as Controller Compile, Install, Image Build through make commands. `Dockerfile` is used when creating Controller Docker Images, and the `config` Directory performs the role of generating Kubernetes Manifests for running Controllers in Kubernetes using **kustomize**.

### 2.4. Memcached CR, Controller File Creation

```shell {caption="[Shell 3] Project Creation"}
$ kubebuilder create api --group memcached --version v1 --kind Memcached
Create Resource [y/n]
$ y
Create Controller [y/n]
$ y
...
$ ls
Dockerfile  Makefile  PROJECT  api  config  controllers  go.mod  go.sum  hack  main.go
```

Create an API using the `kubebuilder create api` command. [Shell 3] shows the process of creating an API using Kubebuilder. You can specify the Group, Version, and type of API. Creating an API in Kubernetes means creating a CR (Object) and creating a Controller that manages the created CR. Golang Code that defines the created CR as a Struct exists in the `api` Directory, and Controller Golang Code exists in the `controllers` Directory.

### 2.5. Memcached CR Definition

```go {caption="[Code 1] api/v1/memcached_types.go", linenos=table}
...
// MemcachedSpec defines the desired state of Memcached
type MemcachedSpec struct {
    // INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
    // Important: Run "make" to regenerate code after modifying this file

    // Memcached pod count
    Size int32 `json:"size"`
}

// MemcachedStatus defines the observed state of Memcached
type MemcachedStatus struct {
    // INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
    // Important: Run "make" to regenerate code after modifying this file

    // Memcached pod status
    Nodes []string `json:"nodes"`
}
...
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// Memcached is the Schema for the memcacheds API
type Memcached struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   MemcachedSpec   `json:"spec,omitempty"`
    Status MemcachedStatus `json:"status,omitempty"`
}
```

Through the API creation process in [Shell 3], Memcached CR is defined as a Struct in `api/v1/memcached_types.go`. As in [Code 1], you must directly add Memcached CR-related information to the `MemcachedSpec` Struct and `MemcachedStatus` Struct of `memcached_types.go`. Spec's `Size` represents the number of Memcached Pods that should operate. Status's `Nodes` represents the names of Pods where Memcached operates.

After changing the Memcached CR Struct, you must reflect the changed Memcached CR to the Kubernetes Cluster (apply Memcached CRD) through the `make install` command. Also, you must generate Code related to Memcached CR used in Memcached Controller through the `make generate` command.

### 2.6. Memcached Controller Development

```go {caption="[Code 2] main.go", linenos=table}
...
    if err = (&controllers.MemcachedReconciler{
        Client: mgr.GetClient(),
        Log:    ctrl.Log.WithName("controllers").WithName("Memcached"),
        Scheme: mgr.GetScheme(),
    }).SetupWithManager(mgr); err != nil {
        setupLog.Error(err, "unable to create controller", "controller", "Memcached")
        os.Exit(1)
    }
    // +kubebuilder:scaffold:builder
...
```

[Code 2] shows part of the Controller's `main()` function. The 3rd line is the part that passes the Kubernetes Client with Cache settings completed by Controller Manager to the Controller's Reconciler. Reconciler communicates with Kubernetes API Server using the Kubernetes Client received from Controller Manager.

```go {caption="[Code 3] controllers/memcached_controller.go", linenos=table}
...
// MemcachedReconciler reconciles a Memcached object
type MemcachedReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=memcached.cache.example.com,resources=memcacheds,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=memcached.cache.example.com,resources=memcacheds/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=memcached.cache.example.com,resources=memcacheds/finalizers,verbs=update
//+kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;delete
//+kubebuilder:rbac:groups="",resources=pods,verbs=list;watch

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the Memcached object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.11.0/pkg/reconcile
func (r *MemcachedReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	reqLogger := log.FromContext(ctx).WithValues("req.Namespace", req.Namespace, "req.Name", req.Name)
	reqLogger.Info("Reconciling Memcached.")

	// Fetch the Memcached instance
	memcached := &memcachedv1.Memcached{}
	err := r.Client.Get(context.TODO(), req.NamespacedName, memcached)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile req.
			// Owned objects are automatically garbage collected. For additional cleanup logic use finalizers.
			// Return and don't requeue
			reqLogger.Info("Memcached resource not found. Ignoring since object must be deleted.")
			return ctrl.Result{}, nil
		}
		// Error reading the object - requeue the req.
		reqLogger.Error(err, "Failed to get Memcached.")
		return ctrl.Result{}, err
	}

	// Check if the Deployment already exists, if not create a new one
	deployment := &appsv1.Deployment{}
	err = r.Client.Get(context.TODO(), types.NamespacedName{Name: memcached.Name, Namespace: memcached.Namespace}, deployment)
	if err != nil && errors.IsNotFound(err) {
		// Define a new Deployment
		dep := r.deploymentForMemcached(memcached)
		reqLogger.Info("Creating a new Deployment.", "Deployment.Namespace", dep.Namespace, "Deployment.Name", dep.Name)
		err = r.Client.Create(context.TODO(), dep)
		if err != nil {
			reqLogger.Error(err, "Failed to create new Deployment.", "Deployment.Namespace", dep.Namespace, "Deployment.Name", dep.Name)
			return ctrl.Result{}, err
		}
		// Deployment created successfully - return and requeue
		return reconcile.Result{Requeue: true}, nil
	} else if err != nil {
		reqLogger.Error(err, "Failed to get Deployment.")
		return ctrl.Result{}, err
	}

	// Ensure the deployment size is the same as the spec
	size := memcached.Spec.Size
	if *deployment.Spec.Replicas != size {
		deployment.Spec.Replicas = &size
		err = r.Client.Update(context.TODO(), deployment)
		if err != nil {
			reqLogger.Error(err, "Failed to update Deployment.", "Deployment.Namespace", deployment.Namespace, "Deployment.Name", deployment.Name)
			return ctrl.Result{}, err
		}
		// Ask to requeue after 1 minute in order to give enough time for the
		// pods be created on the cluster side and the operand be able
		// to do the next update step accurately.
		return ctrl.Result{RequeueAfter: time.Minute}, nil
	}

	// Update the Memcached status with the pod names
	// List the pods for this memcached's deployment
	podList := &corev1.PodList{}
	ls := labelsForMemcached(memcached.Name)
	listOps := []client.ListOption{
		client.InNamespace(req.NamespacedName.Namespace),
		client.MatchingLabels(ls),
	}
	err = r.Client.List(context.TODO(), podList, listOps...)
	if err != nil {
		reqLogger.Error(err, "Failed to list pods.", "Memcached.Namespace", memcached.Namespace, "Memcached.Name", memcached.Name)
		return ctrl.Result{}, err
	}
	podNames := getPodNames(podList.Items)
	reqLogger.Info("test", "podNames", podNames)

	// Update status.Nodes if needed
	if !reflect.DeepEqual(podNames, memcached.Status.Nodes) {
		memcached.Status.Nodes = podNames
		err := r.Client.Status().Update(context.TODO(), memcached)
		if err != nil {
			reqLogger.Error(err, "Failed to update Memcached status.")
			return ctrl.Result{}, err
		}
	}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *MemcachedReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&memcachedv1.Memcached{}).
		Owns(&appsv1.Deployment{}).
		Complete(r)
}

// deploymentForMemcached returns a memcached Deployment object
func (r *MemcachedReconciler) deploymentForMemcached(m *memcachedv1.Memcached) *appsv1.Deployment {
	ls := labelsForMemcached(m.Name)
	replicas := m.Spec.Size

	dep := &appsv1.Deployment{
		ObjectMeta: v1.ObjectMeta{
			Name:      m.Name,
			Namespace: m.Namespace,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: &replicas,
			Selector: &v1.LabelSelector{
				MatchLabels: ls,
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: v1.ObjectMeta{
					Labels: ls,
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Image:   "memcached:1.4.36-alpine",
							Name:    "memcached",
							Command: []string{"memcached", "-m=64", "-o", "modern", "-v"},
							Ports: []corev1.ContainerPort{
								{
									ContainerPort: 11211,
									Name:          "memcached",
								},
							},
						},
					},
				},
			},
		},
	}

	// Set Memcached instance as the owner of the Deployment.
	ctrl.SetControllerReference(m, dep, r.Scheme) //todo check how to get the schema
	return dep
}

// labelsForMemcached returns the labels for selecting the resources
// belonging to the given memcached CR name.
func labelsForMemcached(name string) map[string]string {
	return map[string]string{"app": "memcached", "memcached_cr": name}
}

// getPodNames returns the pod names of the array of pods passed in
func getPodNames(pods []corev1.Pod) []string {
	var podNames []string
	for _, pod := range pods {
		podNames = append(podNames, pod.Name)
	}
	return podNames
}
```

[Code 3] shows the core part of the Memcached Controller. Lines 8~12 are Kubebuilder **Annotations** and represent Roles for Memcached CRs applied to Memcached Controller and Roles for Deployments and Pods necessary for Controller operation. Kubebuilder generates and applies Cluster Role and Cluster Role Binding Manifests necessary for Memcached Controller operation through that Annotation information.

Lines 106~112 are the part that Watches changes to Memcached CRs or Deployment Objects owned (used) by Memcached CRs. When Memcached CRs or Deployment Objects owned by Memcached CRs change, information about the changed Memcached CR is delivered to the `Reconcile()` function.

Line 153 shows a function that stores Memcached CR information that owns that Deployment Object in the Deployment Object. If you check the Meta information of Deployment Objects owned by Memcached CRs, you can see that Memcached CR information that owns that Deployment Object is stored in the `ownerReferences` item. This Owner setting is functionality officially supported by Kubernetes and is necessary for Object GC (Garbage Collection).

Lines 16~29 belonging to the `Reconcile()` function are the part that obtains Memcached CRs using Kubernetes Client based on Name/Namespace information of Memcached CRs retrieved from Work Queue. The part to note here is lines 19~24. If Memcached CR information was attempted to be obtained but does not exist, it means that Memcached CR has been removed. Therefore, Logic to remove Deployment Objects owned by Memcached CRs should exist, but that Logic does not exist in Memcached Controller. This is because Kubernetes knows that the owner of Deployment Objects is the removed Memcached CR and automatically removes them through Object GC process.

Lines 27~60 are the part that obtains Deployment Objects in current state based on Name/Namespace information of Memcached CRs retrieved from Work Queue. Lines 62~75 are the part that performs the operation of matching the number of Replicas of Deployment Objects to Replicas of Memcached CRs if Memcached CR's Replica (Size) differs from the Replica of Deployment Objects in current state. Lines 77~101 are the part that Updates Memcached CR's Status information.

Like this, the `Reconcile()` function repeats the operation of obtaining changed Memcached CRs and controlling Deployment Objects based on the obtained Memcached CRs. You can find parts in the `Reconcile()` function that return with **Requeue** Option after changing Resources through Manager Client. Even if Resource changes are completed, actual reflection takes time, so Requeue Option is used to make the `Reconcile()` function execute again after a certain time passes.

### 2.7. Memcached Controller Local Execution

```shell {caption="[Shell 4] Create Memcached CRD in K8s Cluster and Run Controller Locally"}
$ make run
/root/git/example-k8s-kubebuilder/bin/controller-gen rbac:roleName=manager-role crd webhook paths="./..." output:crd:artifacts:config=config/crd/bases
/root/git/example-k8s-kubebuilder/bin/controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."
go fmt ./...
go vet ./...
go run ./main.go
1.6479643472564068e+09  INFO    controller-runtime.metrics      Metrics server is starting to listen    {"addr": ":8080"}
1.6479643472568e+09     INFO    setup   starting manager
{% endhighlight %}
```

You can run Controllers locally targeting Kubernetes Clusters set in kubeconfig files through the **make run** command. This is useful functionality when developing Controllers. [Shell 4] shows running Memcached Controller locally through the "make run" command.

### 2.8. Memcached Controller Image Build and Push

```makefile {caption="[Code 4] Makefile", linenos=table}
...
# Image URL to use all building/pushing image targets
IMG ?= ssup2/memcached-controller:latest
```

```shell {caption="[Shell 5] Controller Manager Image Creation and Push"}
$ docker login
$ make docker-build
$ make docker-push
```

After specifying the IMG name in Makefile as in [Code 4], you can Build Memcached Controller Images through the **make docker-build** command. Also, you can Push created Images to Docker Hub through the **make docker-push** command. [Shell 5] shows Building and Pushing Memcached Controller Images through "make docker build" and "make docker-push" commands.

### 2.9. Memcached Controller Deployment

```shell {caption="[Shell 6] Controller Manager Deploy"}
$ make deploy
$ kubectl -n example-k8s-kubebuilder-system get pod
NAME                                                         READY   STATUS    RESTARTS   AGE
example-k8s-kubebuilder-controller-manager-c6f85fb5d-zjjx7   2/2     Running   0          3d
```

You can deploy Memcached Controller Images built through the **make deploy** command as Pods to Kubernetes Clusters set in kubeconfig files. At this time, Cluster Role and Cluster Role Binding settings necessary for Memcached Controller operation are also performed. [Shell 6] shows deploying Memcached Controller Images as Pods through the "make deploy" command.

### 2.10. Memcached Operation through Memcached CR Creation

```yaml {caption="[Code 5] config/samples/memcached_v1_memcached.yaml", linenos=table}
apiVersion: memcached.cache.example.com/v1
kind: Memcached
metadata:
  name: memcached-sample
spec:
  size: 3
```

```shell {caption="[Shell 7] Memcached Controller Deploy"}
$ kubectl apply -f config/samples/memcached_v1_memcached.yaml
$ kubectl get pod
NAME                                READY   STATUS    RESTARTS   AGE
memcached-sample-79ccbbbbcb-8w2l7   1/1     Running   0          3m15s
memcached-sample-79ccbbbbcb-vrkmk   1/1     Running   0          3m15s
memcached-sample-79ccbbbbcb-wpgzz   1/1     Running   0          3m15s
```

Create Memcached CRs as in [Code 5] to run Memcached. Since Spec's Size is 3 in [Code 5], 3 Memcached Pods run as can be seen in [Shell 7].

## 3. References

* [https://github.com/dev4devs-com/memcached-kubebuilder](https://github.com/dev4devs-com/memcached-kubebuilder)
* [https://github.com/operator-framework/operator-sdk/issues/1124](https://github.com/operator-framework/operator-sdk/issues/1124)
* [https://book.kubebuilder.io/quick-start.html](https://book.kubebuilder.io/quick-start.html)
* [https://book.kubebuilder.io/cronjob-tutorial/cronjob-tutorial.html](https://book.kubebuilder.io/cronjob-tutorial/cronjob-tutorial.html)
* [https://pkg.go.dev/sigs.k8s.io/controller-runtime](https://pkg.go.dev/sigs.k8s.io/controller-runtime)
* [https://getoutsidedoor.com/2020/05/09/kubernetes-controller-%EA%B5%AC%ED%98%84%ED%95%B4%EB%B3%B4%EA%B8%B0/](https://getoutsidedoor.com/2020/05/09/kubernetes-controller-%EA%B5%AC%ED%98%84%ED%95%B4%EB%B3%B4%EA%B8%B0/)
* [https://stuartleeks.com/posts/kubebuilder-event-filters-part-2-update/](https://stuartleeks.com/posts/kubebuilder-event-filters-part-2-update/)

