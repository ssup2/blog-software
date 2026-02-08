---
title: Argo Rollouts
---

## 1. Argo Rollouts

{{< figure caption="[Figure 1] Argo Rollouts Architecture" src="images/argo-rollouts-architecture.png" width="1100px" >}}

Argo Rollouts is an open-source project that supports Blue/Green, Canary, and Progressive Delivery deployments in Kubernetes environments. In addition to Blue/Green and Canary deployments, it provides various deployment-related features such as Traffic Routing required during deployment, automatic Promotion functionality based on Metrics, and Alerting functionality based on deployment status. [Figure 1] shows the Architecture of Argo Rollouts.

### 1.1. Rollout Object, Rollout Controller

**Rollout Object** is the most core Object for Blue/Green and Canary deployments. Rollout Object contains various settings required for the deployment process and performs the role of controlling the deployment process. Users can directly write and control Rollout Manifests, or control Rollout Objects through the `kubectl argo rollouts` command.

```yaml {caption="[Manifest 1] Rollout Blue/Green Example", linenos=table}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mock-server
  template:
    metadata:
      labels:
        app: mock-server
    spec:
      containers:
      - name: mock-server
        image: ghcr.io/ssup2/mock-go-server:1.0.0
        ports:
        - containerPort: 8080
  strategy:
    blueGreen:
      activeService: mock-server-active
      previewService: mock-server-preview
```

[Manifest 1] shows a Rollout Object for Blue/Green deployment. Lines 35-38 configure Blue/Green deployment. `activeService` specifies the Kubernetes Service connected to the Blue Version, and `previewService` specifies the Kubernetes Service connected to the Green Version. The Image of the Rollout Object can be changed through the `kubectl argo rollouts set image` command, and the Green Version can be promoted to the Blue Version through the `kubectl argo rollouts promote` command.

Rollout creates a **Revision** each time a new deployment is performed, and the Revision number increases by one each time a deployment is performed. **Rollout Controller** creates ReplicaSets for each Revision and manages the number of Pods for Blue/Green Versions through ReplicaSets. It also controls Kubernetes Services specified in `activeService` and `previewService` as needed to manage Traffic for Blue/Green Versions.

```yaml {caption="[Manifest 2] Rollout Canary Example", linenos=table}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 5
  selector:
    matchLabels:
      app: mock-server
  template:
    metadata:
      labels:
        app: mock-server
    spec:
      containers:
      - name: mock-server
        image: ghcr.io/ssup2/mock-go-server:1.0.0
        ports:
        - containerPort: 8080
  strategy:
    canary:
      canaryService: mock-server-canary
      stableService: mock-server-stable
      steps:
      - setWeight: 10
      - pause: {duration: 30s}
      - setWeight: 20
      - pause: {duration: 1m}
      - setWeight: 50
      - pause: {}
      - setWeight: 80
      - pause: {duration: 2m}
      - setWeight: 100
      - pause: {}
```

[Manifest 2] shows a Rollout Object for Canary deployment. Lines 65-79 configure Canary deployment. `canaryService` specifies the Kubernetes Service connected to the Canary Version, and `stableService` specifies the Kubernetes Service connected to the Stable Version. Unlike Blue/Green, Canary deployment can control the **Traffic ratio** between Canary Version and Stable Version through the `steps` section, and in the case of [Manifest 2], it controls the Traffic ratio by controlling the number of Pods for Canary Version and Stable Version.

{{< table caption="[Table 1] Rollout Canary Example Steps" >}}
| Step | Traffic | Stable Pods | Canary Pods | Duration | Description |
|---|---|---|---|---|---|
| 1 | 10% | 5 | 1 | 30s | Monitor with 10% traffic for 30 seconds |
| 2 | 20% | 4 | 1 | 1m | Monitor with 20% traffic for 1 minute |
| 3 | 50% | 2 | 3 | Manual Approval | Manual approval required at 50% |
| 4 | 80% | 1 | 4 | 2m | Monitor with 80% traffic for 2 minutes |
| 5 | 100% | 0 | 5 | Manual Approval | Final approval before 100% rollout |
{{< /table >}}

Using the `pause` syntax in between, it is possible to wait for a certain period of time before changing the Traffic ratio. For example, the `pause: {duration: 30s}` part means waiting for 30 seconds, and the `pause: {}` part means that Manual Approval is required, i.e., Promotion must be performed directly through the `kubectl argo rollouts promote` command. Therefore, Canary deployment is performed in the order shown in [Table 1]. 

```text {caption="[Formula 1] Canary Replicas and Stable Replicas Calculation Formula"}
Canary Replicas = ceil(spec.replicas × setWeight / 100)  
Stable Replicas = spec.replicas - Canary Replicas  
```

The formula for calculating the exact number of Pods for each Step is shown in [Formula 1]. If a problem occurs during the Canary deployment process and you want to go back to the previous Step, you can go back to the previous Step through the `kubectl argo rollouts undo` command, and if you want to abort the deployment when a problem occurs during the Canary deployment process, you can abort the deployment through the `kubectl argo rollouts abort` command.

In the [Manifest 2] example, to distribute Traffic to Canary Version and Stable Version based on Weight, you can create and use a separate Kubernetes Service (`mock-server`) that binds Traffic to Canary Version and Stable Version. However, since it only controls Traffic ratio by the number of Pods, it has the limitation of not being able to accurately control the Traffic ratio. As can be seen in [Table 1], even if you want to send only 10% Traffic to Canary Version, actually 16.7% (1/6) is sent to Canary Version.

### 1.2. Traffic Routing

**Traffic Routing** functionality is provided to overcome the limitation of not being able to accurately control Traffic ratio with only the number of Pods during Canary deployment. Argo Rollouts supports accurate Traffic ratio control by utilizing external Traffic Routing functionality such as Istio and Ingress Nginx. Traffic Routing can be configured using various external Components in addition to Ingress Nginx and Istio.

```yaml {caption="[Manifest 3] Rollout Canary with Traffic Routing Istio Virtual Service Example", linenos=table}
...
  strategy:
    canary:
      canaryService: mock-server-canary
      stableService: mock-server-stable
      trafficRouting:
        istio:
          virtualService:
            name: mock-server
            routes:
            - primary
      steps:
      - setWeight: 10
      - pause: {duration: 30s}
      - setWeight: 20
      - pause: {duration: 1m}
      - setWeight: 50
      - pause: {}
      - setWeight: 80
      - pause: {duration: 2m}
      - setWeight: 100
      - pause: {}
```

[Manifest 3] shows a Rollout Object for Canary deployment configured with Traffic Routing using Istio Virtual Service based on [Manifest 2]. The `trafficRouting` section specifies the Spec for Traffic Routing, and the `istio` section specifies the Istio Virtual Service to use for Traffic Routing. Rollout Controller dynamically changes the Weight of Istio Virtual Service through Traffic Routing Reconciler while proceeding with Canary deployment to control Traffic ratio.

{{< table caption="[Table 2] Rollout Canary with Traffic Routing Istio Virtual Service Example Steps" >}}
| Step | Traffic | Stable Pods | Canary Pods | Duration | Description |
|---|---|---|---|---|---|
| 1 | 10% | 5 | 1 | 30s | Monitor with 10% traffic for 30 seconds |
| 2 | 20% | 5 | 1 | 1m | Monitor with 20% traffic for 1 minute |
| 3 | 50% | 5 | 3 | Manual Approval | Manual approval required at 50% |
| 4 | 80% | 5 | 4 | 2m | Monitor with 80% traffic for 2 minutes |
| 5 | 100% | 0 | 5 | Manual Approval | Final approval before 100% rollout |
{{< /table >}}

```text {caption="[Formula 2] Canary Replicas and Stable Replicas Calculation Formula with Traffic Routing"}
Canary Replicas = ceil(spec.replicas * setWeight / 100) 
Stable Replicas = spec.replicas
```

When Traffic Routing functionality is enabled, each Step has a different number of Pods as shown in [Table 2]. The biggest difference is that the number of Pods for Stable Version is fixed at 5, and only the number of Pods for Canary Version changes. The number of Pods is calculated as shown in [Formula 2].

### 1.3. AnalysisTemplate/AnalysisRun Object and Analysis Controller

**AnalysisTemplate/AnalysisRun Object** is an Object for Progressive Delivery deployment in Argo Rollouts. Through AnalysisTemplate/AnalysisRun Object, external Metrics and Data can be queried, and based on this, it can be decided whether to continue the deployment or abort it. AnalysisTemplate Object, as the name suggests, is an Object that defines a Template for creating AnalysisRun Objects, and AnalysisRun Object is an Object that is dynamically created based on AnalysisTemplate each time actual analysis is performed.

When AnalysisRun Object is created, actual Analysis is performed by **Analysis Controller** and results are returned. Analysis can be performed by integrating with various external systems including Prometheus.

```yaml {caption="[Manifest 4] AnalysisTemplate Object Prometheus Example", linenos=table}
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
  - name: success-rate
    interval: 30s
    count: 3
    successCondition: result >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.istio-system.svc.cluster.local:9090
        query: |
          scalar(
            sum(rate(istio_requests_total{destination_service_name="mock-server-canary",response_code=~"2.."}[1m])) 
            / 
            sum(rate(istio_requests_total{destination_service_name="mock-server-canary"}[1m]))
          )
```

[Manifest 4] shows an AnalysisTemplate Object that performs Analysis using Prometheus. The `metrics` section specifies the Metric to perform Analysis on, and specifies the execution interval, execution count, success condition, and failure limit. In the case of [Manifest 4], it performs 3 Queries at 30-second intervals, and since 2 failures are allowed, Analysis is considered successful if 1 out of 3 Queries succeeds. Query results are considered successful if they are 0.95 or higher. The `provider` section specifies which external system to integrate with to perform Analysis. The `prometheus` section specifies the Prometheus Endpoint and Query to integrate with. 

```yaml {caption="[File 5] Rollouts Canary with AnalysisTemplate Prometheus Example", linenos=table}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 5
  selector:
    matchLabels:
      app: mock-server
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 30s}
        - analysis:
            templates:
              - templateName: success-rate
```

[Manifest 5] shows a Rollout Object that performs Progressive Delivery deployment using the AnalysisTemplate from [Manifest 4]. The `analysis` section specifies the AnalysisTemplate to perform Analysis. It distributes 20% Traffic to Canary Version and performs Analysis after waiting 30 seconds.

### 1.4. Experiment Object, Experiment Controller

```yaml {caption="[Manifest 6] Experiment Object Example", linenos=table}
apiVersion: argoproj.io/v1alpha1
kind: Experiment
metadata:
  name: mock-server-experiment
spec:
  duration: 5m
  templates:
  - name: baseline
    replicas: 1
    template:
      metadata:
        labels:
          app: mock-server
          experiment: baseline
      spec:
        containers:
        - name: mock-server
          image: ghcr.io/ssup2/mock-go-server:1.0.0
          ports:
          - containerPort: 8080
  - name: canary
    replicas: 1
    template:
      metadata:
        labels:
          app: mock-server
          experiment: canary
      spec:
        containers:
        - name: mock-server
          image: ghcr.io/ssup2/mock-go-server:2.0.0
          ports:
          - containerPort: 8080
  - name: experimental
    replicas: 1
    template:
      metadata:
        labels:
          app: mock-server
          experiment: experimental
      spec:
        containers:
        - name: mock-server
          image: ghcr.io/ssup2/mock-go-server:3.0.0
          ports:
          - containerPort: 8080
```

**Experiment** Object, as the name suggests, is an Object used when performing deployments for temporary testing. It is similar to Rollout Object but can specify when deployed Pods are removed by specifying Duration, and provides the ability to deploy multiple Versions simultaneously in a single Experiment Object. [Manifest 6] shows an Experiment Object example. The `duration` section specifies that Pods will be removed after 5 minutes. Also, through the `templates` section, it can be confirmed that 3 Versions (`baseline`, `canary`, `experimental`) can be deployed simultaneously.

```yaml {caption="[Manifest 7] Rollouts Canary with Experiment Object Example", linenos=table}
...
  strategy:
    canary:
      canaryService: mock-server-canary
      stableService: mock-server-stable
      trafficRouting:
        istio:
          virtualService:
            name: mock-server
            routes:
            - primary
      steps:
      - setWeight: 10
      - pause: {duration: 30s}
      - experiment:
          duration: 2m
          templates:
          - name: stable
            specRef: stable
            replicas: 2
            weight: 50
            service:
              name: mock-server-experiment-stable
          - name: canary
            specRef: canary
            replicas: 2
            weight: 50
            service:
              name: mock-server-experiment-canary
          analyses:
          - name: stable-vs-canary
            templateName: compare-success-rate
            args:
            - name: stable-hash
              value: "{{templates.stable.podTemplateHash}}"
            - name: canary-hash
              value: "{{templates.canary.podTemplateHash}}"
      - setWeight: 20
      - pause: {duration: 1m}
      - setWeight: 50
      - pause: {}
      - setWeight: 80
      - pause: {duration: 2m}
      - setWeight: 100
      - pause: {}
```

Another use of Experiment Object is that it can perform Netflix's **Kayenta-style** analysis by integrating with Rollouts Objects. Kayenta-style analysis differs from general Canary deployment in that it performs deployment and analysis by dividing into three Versions: **Production**, **Baseline**, and **Canary**.

* **Production Version**: Version deployed to the actual production environment
* **Baseline Version**: Version identical to Production Version
* **Canary Version**: New Version to be changed

The reason Production and Baseline Versions are the same Version but operated separately is to distribute and analyze the same amount of Traffic as Canary Version. Kayenta-style analysis is an analysis method that improves the disadvantage of general Canary analysis methods, which have difficulty satisfying equal analysis conditions because Canary Version and Stable Version receive different amounts of Traffic. When using Experiment Object in Argo Rollouts, Experiment Object performs the role of Baseline Version and Canary Version. [Manifest 7] shows a Rollouts Object example that performs Kayenta-style analysis using Experiment Object, where Experiment's Stable performs the role of Baseline Version and Experiment's Canary performs the role of Canary Version.

**Experiment Controller** creates and controls ReplicaSets similar to Rollout Controller according to Experiment Object definitions, and creates AnalysisRuns by referencing AnalysisTemplate Objects and references analysis results.

### 1.5. Notification Controller

```yaml {caption="[Manifest 8] Notification Controller Example", linenos=table}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
  annotations:
    notifications.argoproj.io/subscribe.on-rollout-completed.slack: deployments
...
```

**Notification Controller** is a Controller that performs Notification functionality provided by Argo Rollouts. Notification Controller provides functionality to send notifications of deployment results via email, Slack, Webhook, etc. [Manifest 8] shows an example of notifying deployment results to Slack using Notification Controller. It can be confirmed that deployment results are notified to Slack Channel through Annotations. It provides functionality to send notifications in various ways including Email and Webhook in addition to Slack.

## 2. Argo Rollouts Test Cases

Various Test Cases for Argo Rollouts are used to verify Argo Rollouts functionality.

### 2.1. Test Environment Configuration

```shell {caption="[Shell 1] Test Environment Configuration"}
# Create kubernetes cluster with kind
$ kind create cluster --config=- <<EOF                           
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Install argo rollouts
$ kubectl create namespace argo-rollouts
$ kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install istio
$ istioctl install --set profile=demo -y

# Enable sidecar injection to default namespace
$ kubectl label namespace default istio-injection=enabled

# Install prometheus
$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/prometheus.yaml
```

[Shell 1] shows a script that configures the Test environment. It configures a Kubernetes Cluster using `kind` and installs Argo Rollouts. It installs Istio for Traffic Routing and enables Sidecar Injection in the default Namespace. It also installs Prometheus for testing AnalysisTemplate/AnalysisRun.

```yaml {caption="[Manifest 9] shell Pod Manifest", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: shell
  labels:
    app: shell
spec:
  containers:
  - name: shell
    image: nicolaka/netshoot
    command: ["sleep", "infinity"]
```

[Manifest 9] shows the Manifest for the `shell` Pod. It creates a `shell` Pod using the `netshoot` Container Image and is used to access Services configured with Argo Rollout to generate Istio Metrics.

### 2.2. Test Cases

#### 2.2.1. Blue/Green

{{< figure caption="[Figure 2] Argo Rollouts Blue/Green Case" src="images/argo-rollouts-case-bluegreen.png" width="800px" >}}

[Figure 2] diagrams a Test Case for Argo Rollouts Blue/Green deployment. After changing the Container Image twice, Promotion is performed, skipping `Revision 2` and performing Promotion to `Revision 3` at once. Because it is a Blue/Green deployment, the number of Pods for Green Version is maintained at 5, the same as the number of Pods for Blue Version. The `Preview` Kubernetes Service points to `Revision 1`, `Revision 2`, and `Revision 3` in order, and the `Active` Kubernetes Service points to `Revision 1` and then points to `Revision 3` after Promotion is completed.

```yaml {caption="[Manifest 10] Blue/Green Test Case", linenos=table}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mock-server
  strategy:
    blueGreen:
      activeService: mock-server-active
      previewService: mock-server-preview
      autoPromotionEnabled: false
  template:
    metadata:
      labels:
        app: mock-server
    spec:
      containers:
      - name: mock-server
        image: ghcr.io/ssup2/mock-go-server:1.0.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-active
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-preview
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
```

```shell {caption="[Shell 2] Blue/Green Test Case"}
# Deploy mock-server blue/green rollout and check status
$ kubectl apply -f mock-server-bluegreen.yaml
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        BlueGreen
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, active)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ✔ Healthy  15s  
└──# revision:1                                                                
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  15s  stable,active
      ├──□ mock-server-6579c6cc98-76zf2  Pod         ✔ Running  15s  ready:1/1
      ├──□ mock-server-6579c6cc98-7bwhd  Pod         ✔ Running  15s  ready:1/1
      ├──□ mock-server-6579c6cc98-khls8  Pod         ✔ Running  15s  ready:1/1
      ├──□ mock-server-6579c6cc98-pwdf9  Pod         ✔ Running  15s  ready:1/1
      └──□ mock-server-6579c6cc98-qj7qx  Pod         ✔ Running  15s  ready:1/1

$ kubectl describe service mock-server-active
Name:                     mock-server-active
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-preview
Name:                     mock-server-preview
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

# Set mock-server image to 2.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:2.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         BlueGreenPause
Strategy:        BlueGreen
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, active)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (preview)
Replicas:
  Desired:       5
  Current:       10
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ॥ Paused   72s  
├──# revision:2                                                                
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy  6s   preview
│     ├──□ mock-server-7c6fcfb847-cdws6  Pod         ✔ Running  6s   ready:1/1
│     ├──□ mock-server-7c6fcfb847-gmq45  Pod         ✔ Running  6s   ready:1/1
│     ├──□ mock-server-7c6fcfb847-gzvk5  Pod         ✔ Running  6s   ready:1/1
│     ├──□ mock-server-7c6fcfb847-vcfw4  Pod         ✔ Running  6s   ready:1/1
│     └──□ mock-server-7c6fcfb847-zr7zd  Pod         ✔ Running  6s   ready:1/1
└──# revision:1                                                                
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  72s  stable,active
      ├──□ mock-server-6579c6cc98-76zf2  Pod         ✔ Running  72s  ready:1/1
      ├──□ mock-server-6579c6cc98-7bwhd  Pod         ✔ Running  72s  ready:1/1
      ├──□ mock-server-6579c6cc98-khls8  Pod         ✔ Running  72s  ready:1/1
      ├──□ mock-server-6579c6cc98-pwdf9  Pod         ✔ Running  72s  ready:1/1
      └──□ mock-server-6579c6cc98-qj7qx  Pod         ✔ Running  72s  ready:1/1

$ kubectl describe service mock-server-active
Name:                     mock-server-active
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-preview
Name:                     mock-server-preview
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=7c6fcfb847
...

$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:3.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         BlueGreenPause
Strategy:        BlueGreen
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, active)
                 ghcr.io/ssup2/mock-go-server:3.0.0 (preview)
Replicas:
  Desired:       5
  Current:       10
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS        AGE    INFO
⟳ mock-server                            Rollout     ॥ Paused      2m52s  
├──# revision:3                                                                     
│  └──⧉ mock-server-6fcb56df9b           ReplicaSet  ✔ Healthy     40s    preview
│     ├──□ mock-server-6fcb56df9b-9ws9k  Pod         ✔ Running     39s    ready:1/1
│     ├──□ mock-server-6fcb56df9b-sznrj  Pod         ✔ Running     39s    ready:1/1
│     ├──□ mock-server-6fcb56df9b-t7mxx  Pod         ✔ Running     39s    ready:1/1
│     ├──□ mock-server-6fcb56df9b-x7v48  Pod         ✔ Running     39s    ready:1/1
│     └──□ mock-server-6fcb56df9b-xclfh  Pod         ✔ Running     39s    ready:1/1
├──# revision:2                                                                     
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  • ScaledDown  106s   
└──# revision:1                                                                     
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy     2m52s  stable,active
      ├──□ mock-server-6579c6cc98-76zf2  Pod         ✔ Running     2m52s  ready:1/1
      ├──□ mock-server-6579c6cc98-7bwhd  Pod         ✔ Running     2m52s  ready:1/1
      ├──□ mock-server-6579c6cc98-khls8  Pod         ✔ Running     2m52s  ready:1/1
      ├──□ mock-server-6579c6cc98-pwdf9  Pod         ✔ Running     2m52s  ready:1/1
      └──□ mock-server-6579c6cc98-qj7qx  Pod         ✔ Running     2m52s  ready:1/1

$ kubectl describe service mock-server-active
Name:                     mock-server-active
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-preview
Name:                     mock-server-preview
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b

# Promote mock-server rollout
$ kubectl argo rollouts promote mock-server
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        BlueGreen
Images:          ghcr.io/ssup2/mock-go-server:3.0.0 (stable, active)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS        AGE   INFO
⟳ mock-server                            Rollout     ✔ Healthy     4m7s  
├──# revision:3                                                                    
│  └──⧉ mock-server-6fcb56df9b           ReplicaSet  ✔ Healthy     115s  stable,active
│     ├──□ mock-server-6fcb56df9b-9ws9k  Pod         ✔ Running     114s  ready:1/1
│     ├──□ mock-server-6fcb56df9b-sznrj  Pod         ✔ Running     114s  ready:1/1
│     ├──□ mock-server-6fcb56df9b-t7mxx  Pod         ✔ Running     114s  ready:1/1
│     ├──□ mock-server-6fcb56df9b-x7v48  Pod         ✔ Running     114s  ready:1/1
│     └──□ mock-server-6fcb56df9b-xclfh  Pod         ✔ Running     114s  ready:1/1
├──# revision:2                                                                    
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  • ScaledDown  3m1s  
└──# revision:1                                                                    
   └──⧉ mock-server-6579c6cc98           ReplicaSet  • ScaledDown  4m7s  

$ kubectl describe service mock-server-active
Name:                     mock-server-active
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b

$ kubectl describe service mock-server-preview 
Name:                     mock-server-preview
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b
```

[Manifest 10] shows the Manifest for the Blue/Green deployment Test Case, and [Shell 2] shows the process of performing that Test Case. The `mock-server-active` Kubernetes Service and `mock-server-preview` Kubernetes Service in [Manifest 10] are configured with the same Selector `app=mock-server`, but when actual Blue/Green deployment is performed, they point to specific Revisions through the `rollouts-pod-template-hash` Selector, and this Revision designation is performed by Rollout Controller.

#### 2.2.2. Canary Success

{{< figure caption="[Figure 3] Canary Success Test Case" src="images/argo-rollouts-case-canary-success.png" width="1100px" >}}

[Figure 3] diagrams a successful Test Case for Argo Rollouts Canary deployment. After changing the Container Image twice, Promotion is performed, skipping `Revision 2` and performing Promotion to `Revision 3` at once. Immediately after changing the Image, one Pod is created immediately due to Weight 20% setting, after Promotion is performed, Pods increase to 2 due to Weight 40% setting, and after 30 seconds, Pods increase to 5 due to Weight 100% setting.

The `Canary` Kubernetes Service points to `Revision 1`, `Revision 2`, and `Revision 3` in order, and the `Stable` Kubernetes Service points to `Revision 1` and then points to `Revision 3` after Promotion is completed. The `Main` Service always points to all Revisions and distributes Traffic to Stable and Canary Versions.

```yaml {caption="[Manifest 11] Canary Success Test Case"}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 5
  selector:
    matchLabels:
      app: mock-server
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {}
      - setWeight: 40
      - pause: {duration: 30s}
      - setWeight: 100
      canaryService: mock-server-canary
      stableService: mock-server-stable
  template:
    metadata:
      labels:
        app: mock-server
    spec:
      containers:
      - name: mock-server
        image: ghcr.io/ssup2/mock-go-server:1.0.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-stable
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-canary
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
```

```shell {caption="[Shell 3] Canary Success Test Case"}
# Deploy mock-server canary rollout and check status
$ kubectl apply -f mock-server-canary-success.yaml
$ kubectl argo rollouts get rollout mock-server   
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ✔ Healthy  23s  
└──# revision:1                                                             
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  22s  stable
      ├──□ mock-server-6579c6cc98-9p7g5  Pod         ✔ Running  22s  ready:1/1
      ├──□ mock-server-6579c6cc98-gtnbn  Pod         ✔ Running  22s  ready:1/1
      ├──□ mock-server-6579c6cc98-p6tkk  Pod         ✔ Running  22s  ready:1/1
      ├──□ mock-server-6579c6cc98-qk4l4  Pod         ✔ Running  22s  ready:1/1
      └──□ mock-server-6579c6cc98-xsprx  Pod         ✔ Running  22s  ready:1/1

$ kubectl describe service mock-server-stable
Name:                     mock-server-stable
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

# Set mock-server image to 2.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:2.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       1
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS     AGE    INFO
⟳ mock-server                            Rollout     ॥ Paused   6m15s  
├──# revision:2                                                               
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy  34s    canary
│     └──□ mock-server-7c6fcfb847-4bn54  Pod         ✔ Running  34s    ready:1/1
└──# revision:1                                                               
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  6m14s  stable
      ├──□ mock-server-6579c6cc98-9p7g5  Pod         ✔ Running  6m14s  ready:1/1
      ├──□ mock-server-6579c6cc98-gtnbn  Pod         ✔ Running  6m14s  ready:1/1
      ├──□ mock-server-6579c6cc98-p6tkk  Pod         ✔ Running  6m14s  ready:1/1
      └──□ mock-server-6579c6cc98-qk4l4  Pod         ✔ Running  6m14s  ready:1/1

$ kubectl describe service mock-server-stable
Name:                     mock-server-stable
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-canary
Name:                     mock-server
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=7c6fcfb847
...

# Set mock-server image to 3.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:3.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:3.0.0 (canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       1
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS        AGE    INFO
⟳ mock-server                            Rollout     ॥ Paused      19m    
├──# revision:3                                                                  
│  └──⧉ mock-server-6fcb56df9b           ReplicaSet  ✔ Healthy     2m24s  canary
│     └──□ mock-server-6fcb56df9b-njv7k  Pod         ✔ Running     2m24s  ready:1/1
├──# revision:2                                                                  
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  • ScaledDown  13m    
└──# revision:1                                                                  
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy     18m    stable
      ├──□ mock-server-6579c6cc98-9p7g5  Pod         ✔ Running     18m    ready:1/1
      ├──□ mock-server-6579c6cc98-gtnbn  Pod         ✔ Running     18m    ready:1/1
      ├──□ mock-server-6579c6cc98-p6tkk  Pod         ✔ Running     18m    ready:1/1
      └──□ mock-server-6579c6cc98-qk4l4  Pod         ✔ Running     18m    ready:1/1

$ kubectl describe service mock-server-stable
Name:                     mock-server-stable
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b
...

# Promote mock-server rollout
$ kubectl argo rollouts promote mock-server
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          3/5
  SetWeight:     40
  ActualWeight:  40
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:3.0.0 (canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       2
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS        AGE  INFO
⟳ mock-server                            Rollout     ॥ Paused      27m  
├──# revision:3                                                                
│  └──⧉ mock-server-6fcb56df9b           ReplicaSet  ✔ Healthy     10m  canary
│     ├──□ mock-server-6fcb56df9b-njv7k  Pod         ✔ Running     10m  ready:1/1
│     └──□ mock-server-6fcb56df9b-6hhfh  Pod         ✔ Running     7s   ready:1/1
├──# revision:2                                                                
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  • ScaledDown  21m  
└──# revision:1                                                                
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy     27m  stable
      ├──□ mock-server-6579c6cc98-9p7g5  Pod         ✔ Running     27m  ready:1/1
      ├──□ mock-server-6579c6cc98-gtnbn  Pod         ✔ Running     27m  ready:1/1
      └──□ mock-server-6579c6cc98-qk4l4  Pod         ✔ Running     27m  ready:1/1

$ kubectl describe service mock-server-stable         
Name:                     mock-server-stable
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b
...

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:3.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS        AGE  INFO
⟳ mock-server                            Rollout     ✔ Healthy     27m  
├──# revision:3                                                                
│  └──⧉ mock-server-6fcb56df9b           ReplicaSet  ✔ Healthy     11m  stable
│     ├──□ mock-server-6fcb56df9b-njv7k  Pod         ✔ Running     11m  ready:1/1
│     ├──□ mock-server-6fcb56df9b-6hhfh  Pod         ✔ Running     58s  ready:1/1
│     ├──□ mock-server-6fcb56df9b-9xnsb  Pod         ✔ Running     22s  ready:1/1
│     ├──□ mock-server-6fcb56df9b-b928v  Pod         ✔ Running     22s  ready:1/1
│     └──□ mock-server-6fcb56df9b-v8gjd  Pod         ✔ Running     22s  ready:1/1
├──# revision:2                                                                
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  • ScaledDown  22m  
└──# revision:1                                                                
   └──⧉ mock-server-6579c6cc98           ReplicaSet  • ScaledDown  27m

$ kubectl describe service mock-server-stable
Name:                     mock-server-stable
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b
...

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b
...
```

[Manifest 11] shows the Manifest for the Canary deployment success Test Case, and [Shell 3] shows the process of performing that Test Case. It can be confirmed that it operates identically to [Figure 3]. The `mock-server-stable` Kubernetes Service and `mock-server-canary` Kubernetes Service in [Manifest 11] are configured with the same Selector `app=mock-server`, but when actual Canary deployment is performed, they point to specific Revisions through the `rollouts-pod-template-hash` Selector, and this Revision designation is performed by Rollout Controller.

#### 2.2.3. Canary with Undo and Abort

{{< figure caption="[Figure 4] Canary with Undo and Abort Test Case" src="images/argo-rollouts-case-canary-undo-abort.png" width="1100px" >}}

[Figure 4] diagrams an Undo and Abort Test Case for Argo Rollouts Canary deployment. After changing the Container Image three times, Undo is performed twice, and finally Abort is performed. The notable point is that when performing the first Undo, it does not go back to `Revision 2`, but a new `Revision 4` is created and only the Container Image is changed to Version `2.0.0`, and when performing the second Undo, a new `Revision 5` is created and only the Container Image is changed to Version `3.0.0`. That is, when performing Undo, it can be confirmed that it does not use the previous Revision but creates a new Revision and only changes the Container Image to the previous Version.

```yaml {caption="[Manifest 12] Canary with Undo and Abort Test Case"}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 5
  selector:
    matchLabels:
      app: mock-server
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {}
      - setWeight: 40
      - pause: {}
      - setWeight: 100
      canaryService: mock-server-canary
      stableService: mock-server-stable
  template:
    metadata:
      labels:
        app: mock-server
    spec:
      containers:
      - name: mock-server
        image: ghcr.io/ssup2/mock-go-server:1.0.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-stable
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-canary
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
```

```shell {caption="[Shell 4] Canary with Undo and Abort Test Case"}
# Deploy mock-server canary rollout and check status
$ kubectl apply -f mock-server-canary-undo-abort.yaml
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ✔ Healthy  41s  
└──# revision:1                                                      
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  41s  stable
      ├──□ mock-server-6579c6cc98-7r42g  Pod         ✔ Running  41s  ready:1/1
      ├──□ mock-server-6579c6cc98-fl52c  Pod         ✔ Running  41s  ready:1/1
      ├──□ mock-server-6579c6cc98-jp6f5  Pod         ✔ Running  41s  ready:1/1
      ├──□ mock-server-6579c6cc98-vdjpj  Pod         ✔ Running  41s  ready:1/1
      └──□ mock-server-6579c6cc98-wxkhx  Pod         ✔ Running  41s  ready:1/1

# Set mock-server image to 2.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:2.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       1
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS     AGE    INFO
⟳ mock-server                            Rollout     ॥ Paused   10m    
├──# revision:2                                                        
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy  2m17s  canary
│     └──□ mock-server-7c6fcfb847-9kq78  Pod         ✔ Running  2m16s  ready:1/1
└──# revision:1                                                        
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  10m    stable
      ├──□ mock-server-6579c6cc98-7r42g  Pod         ✔ Running  10m    ready:1/1
      ├──□ mock-server-6579c6cc98-fl52c  Pod         ✔ Running  10m    ready:1/1
      ├──□ mock-server-6579c6cc98-jp6f5  Pod         ✔ Running  10m    ready:1/1
      └──□ mock-server-6579c6cc98-vdjpj  Pod         ✔ Running  10m    ready:1/1

# Set mock-server image to 3.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:3.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:3.0.0 (canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       1
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS        AGE    INFO
⟳ mock-server                            Rollout     ॥ Paused      12m    
├──# revision:3                                                           
│  └──⧉ mock-server-6fcb56df9b           ReplicaSet  ✔ Healthy     72s    canary
│     └──□ mock-server-6fcb56df9b-2h9lx  Pod         ✔ Running     72s    ready:1/1
├──# revision:2                                                           
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  • ScaledDown  4m32s  
└──# revision:1                                                           
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy     12m    stable
      ├──□ mock-server-6579c6cc98-7r42g  Pod         ✔ Running     12m    ready:1/1
      ├──□ mock-server-6579c6cc98-fl52c  Pod         ✔ Running     12m    ready:1/1
      ├──□ mock-server-6579c6cc98-jp6f5  Pod         ✔ Running     12m    ready:1/1
      └──□ mock-server-6579c6cc98-vdjpj  Pod         ✔ Running     12m    ready:1/1

# Undo mock-server rollout
$ kubectl argo rollouts undo mock-server
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       1
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS        AGE  INFO
⟳ mock-server                            Rollout     ॥ Paused      30m  
├──# revision:4                                                         
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy     22m  canary
│     └──□ mock-server-7c6fcfb847-fwglc  Pod         ✔ Running     41s  ready:1/1
├──# revision:3                                                         
│  └──⧉ mock-server-6fcb56df9b           ReplicaSet  • ScaledDown  19m  
└──# revision:1                                                         
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy     30m  stable
      ├──□ mock-server-6579c6cc98-7r42g  Pod         ✔ Running     30m  ready:1/1
      ├──□ mock-server-6579c6cc98-fl52c  Pod         ✔ Running     30m  ready:1/1
      ├──□ mock-server-6579c6cc98-jp6f5  Pod         ✔ Running     30m  ready:1/1
      └──□ mock-server-6579c6cc98-vdjpj  Pod         ✔ Running     30m  ready:1/1

# Undo mock-server rollout
$ kubectl argo rollouts undo mock-server
$ kubectl argo rollouts get rollout mock-server
kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:3.0.0 (canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       1
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS        AGE  INFO
⟳ mock-server                            Rollout     ॥ Paused      76m  
├──# revision:5                                                         
│  └──⧉ mock-server-6fcb56df9b           ReplicaSet  ✔ Healthy     64m  canary
│     └──□ mock-server-6fcb56df9b-qq7st  Pod         ✔ Running     13s  ready:1/1
├──# revision:4                                                         
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  • ScaledDown  68m  
└──# revision:1                                                         
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy     76m  stable
      ├──□ mock-server-6579c6cc98-7r42g  Pod         ✔ Running     76m  ready:1/1
      ├──□ mock-server-6579c6cc98-fl52c  Pod         ✔ Running     76m  ready:1/1
      ├──□ mock-server-6579c6cc98-jp6f5  Pod         ✔ Running     76m  ready:1/1
      └──□ mock-server-6579c6cc98-vdjpj  Pod         ✔ Running     76m  ready:1/1

# Abort mock-server rollout
$ kubectl argo rollouts abort mock-server
$ kubectl argo rollouts get rollout mock-server
kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 5
Strategy:        Canary
  Step:          0/5
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS        AGE  INFO
⟳ mock-server                            Rollout     ✖ Degraded    78m  
├──# revision:5                                                         
│  └──⧉ mock-server-6fcb56df9b           ReplicaSet  • ScaledDown  67m  canary
├──# revision:4                                                         
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  • ScaledDown  71m  
└──# revision:1                                                         
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy     78m  stable
      ├──□ mock-server-6579c6cc98-7r42g  Pod         ✔ Running     78m  ready:1/1
      ├──□ mock-server-6579c6cc98-fl52c  Pod         ✔ Running     78m  ready:1/1
      ├──□ mock-server-6579c6cc98-jp6f5  Pod         ✔ Running     78m  ready:1/1
      ├──□ mock-server-6579c6cc98-vdjpj  Pod         ✔ Running     78m  ready:1/1
      └──□ mock-server-6579c6cc98-wx576  Pod         ✔ Running     25s  ready:1/1
```

[Manifest 12] shows the Manifest for the Canary deployment Undo and Abort Test Case, and [Shell 4] shows the process of performing that Test Case.

#### 2.2.4. Canary with Istio Virtual Service

{{< figure caption="[Figure 5] Canary with Istio Virtual Service Test Case" src="images/argo-rollouts-case-canary-istio-virtualservice.png" width="800px" >}}

[Figure 5] diagrams a Traffic Routing Test Case using Istio Virtual Service. After changing the Container Image once, two Promotions are performed. Immediately after changing the Container Image, one Canary Version Pod is created immediately due to Weight 20% setting, after Promotion is performed, Canary Version Pods increase to 2 due to Weight 40% setting, and after performing Promotion once more, Canary Version Pods increase to 5 due to Weight 100% setting.

And as the **Virtual Service's Weight** changes according to Weight, Traffic is distributed to Canary Version and Stable Version. The `Canary` Kubernetes Service points to `Revision 1` and `Revision 2` in order, and the `Stable` Kubernetes Service points to `Revision 1` and then points to `Revision 2` after Promotion is completed. Since Istio Virtual Service is used for Traffic Routing, the number of Pods for Stable Version is maintained at 5 in all steps.

```yaml {caption="[Manifest 13] Canary with Istio Virtual Service Test Case"}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 5
  selector:
    matchLabels:
      app: mock-server
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {}
      - setWeight: 40
      - pause: {}
      - setWeight: 100
      stableService: mock-server-stable
      canaryService: mock-server-canary
      trafficRouting:
        istio:
          virtualService:
            name: mock-server
            routes:
            - primary
  template:
    metadata:
      labels:
        app: mock-server
    spec:
      containers:
      - name: mock-server
        image: ghcr.io/ssup2/mock-go-server:1.0.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-stable
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-canary
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mock-server
spec:
  hosts:
  - mock-server-stable
  http:
  - name: primary
    route:
    - destination:
        host: mock-server-stable
      weight: 100
    - destination:
        host: mock-server-canary
      weight: 0
```

```shell {caption="[Shell 5] Canary with Istio Virtual Service Test Case"}
# Deploy mock-server canary rollout and check status
$ kubectl apply -f mock-server-canary-istio-virtualservice.yaml
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS     AGE    INFO
⟳ mock-server                            Rollout     ✔ Healthy  9m22s  
└──# revision:1                                                               
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  9m22s  stable
      ├──□ mock-server-6579c6cc98-cp2cl  Pod         ✔ Running  9m22s  ready:1/1
      ├──□ mock-server-6579c6cc98-fjgw4  Pod         ✔ Running  9m22s  ready:1/1
      ├──□ mock-server-6579c6cc98-fzk7d  Pod         ✔ Running  9m22s  ready:1/1
      ├──□ mock-server-6579c6cc98-g4lz4  Pod         ✔ Running  9m22s  ready:1/1
      └──□ mock-server-6579c6cc98-s52sn  Pod         ✔ Running  9m22s  ready:1/1

$ kubectl describe virtualservices mock-server
...
Spec:
  Hosts:
    mock-server-stable
  Http:
    Name:  primary
    Route:
      Destination:
        Host:  mock-server-stable
      Weight:  100
      Destination:
        Host:  mock-server-canary
      Weight:  0

$ kubectl describe service mock-server-stable
Name:                     mock-server-stable
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

# Set mock-server image to 2.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:2.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                     KIND        STATUS     AGE   INFO
⟳ mock-server                            Rollout     ॥ Paused   32m   
├──# revision:2                                                              
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy  7m8s  canary
│     └──□ mock-server-7c6fcfb847-njld5  Pod         ✔ Running  7m8s  ready:1/1
└──# revision:1                                                              
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  32m   stable
      ├──□ mock-server-6579c6cc98-cp2cl  Pod         ✔ Running  32m   ready:1/1
      ├──□ mock-server-6579c6cc98-fjgw4  Pod         ✔ Running  32m   ready:1/1
      ├──□ mock-server-6579c6cc98-fzk7d  Pod         ✔ Running  32m   ready:1/1
      ├──□ mock-server-6579c6cc98-g4lz4  Pod         ✔ Running  32m   ready:1/1
      └──□ mock-server-6579c6cc98-s52sn  Pod         ✔ Running  32m   ready:1/1

$ kubectl describe virtualservices mock-server
...
Spec:
  Hosts:
    mock-server-stable
  Http:
    Name:  primary
    Route:
      Destination:
        Host:  mock-server-stable
      Weight:  80
      Destination:
        Host:  mock-server-canary
      Weight:  20

$ kubectl describe service mock-server-stable
Name:                     mock-server-stable
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=7c6fcfb847
...

# Promote mock-server rollout
$ kubectl argo rollouts promote mock-server
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          3/5
  SetWeight:     40
  ActualWeight:  40
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       7
  Updated:       2
  Ready:         7
  Available:     7

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ॥ Paused   35m  
├──# revision:2                                                             
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy  10m  canary
│     ├──□ mock-server-7c6fcfb847-njld5  Pod         ✔ Running  10m  ready:1/1
│     └──□ mock-server-7c6fcfb847-skbbf  Pod         ✔ Running  12s  ready:1/1
└──# revision:1                                                             
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  35m  stable
      ├──□ mock-server-6579c6cc98-cp2cl  Pod         ✔ Running  35m  ready:1/1
      ├──□ mock-server-6579c6cc98-fjgw4  Pod         ✔ Running  35m  ready:1/1
      ├──□ mock-server-6579c6cc98-fzk7d  Pod         ✔ Running  35m  ready:1/1
      ├──□ mock-server-6579c6cc98-g4lz4  Pod         ✔ Running  35m  ready:1/1
      └──□ mock-server-6579c6cc98-s52sn  Pod         ✔ Running  35m  ready:1/1

$ kubectl describe virtualservices mock-server
...
Spec:
  Hosts:
    mock-server-stable
  Http:
    Name:  primary
    Route:
      Destination:
        Host:  mock-server-stable
      Weight:  60
      Destination:
        Host:  mock-server-canary
      Weight:  40

$ kubectl describe service mock-server-stable
Name:                     mock-server-stable
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=7c6fcfb847
...

# Promote mock-server rollout again
$ kubectl argo rollouts promote mock-server
$ kubectl argo rollouts get rollout mock-server 
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:2.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS        AGE    INFO
⟳ mock-server                            Rollout     ✔ Healthy     38m    
├──# revision:2                                                                  
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy     13m    stable
│     ├──□ mock-server-7c6fcfb847-njld5  Pod         ✔ Running     13m    ready:1/1
│     ├──□ mock-server-7c6fcfb847-skbbf  Pod         ✔ Running     3m31s  ready:1/1
│     ├──□ mock-server-7c6fcfb847-g67vk  Pod         ✔ Running     97s    ready:1/1
│     ├──□ mock-server-7c6fcfb847-ggd22  Pod         ✔ Running     97s    ready:1/1
│     └──□ mock-server-7c6fcfb847-wfx9k  Pod         ✔ Running     97s    ready:1/1
└──# revision:1                                                                  
   └──⧉ mock-server-6579c6cc98           ReplicaSet  • ScaledDown  38m  

$ kubectl describe virtualservices mock-server
...
Spec:
  Hosts:
    mock-server-stable
  Http:
    Name:  primary
    Route:
      Destination:
        Host:  mock-server-stable
      Weight:  100
      Destination:
        Host:  mock-server-canary
      Weight:  0

$ kubectl describe service mock-server-stable
Name:                     mock-server-stable
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=7c6fcfb847
...

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=7c6fcfb847
...
```

[Manifest 13] shows the Manifest for the Traffic Routing Test Case using Istio Virtual Service, and [Shell 5] shows the process of performing that Test Case. It can be confirmed that the weight of the `mock-server` Virtual Service increases to `mock-server-canary` and then changes back to 0 after the final Promotion.

#### 2.2.5. Canary with Istio Virtual Service and AnalysisTemplate

{{< figure caption="[Figure 6] Canary with Istio Virtual Service and Analysis Test Case" src="images/argo-rollouts-case-canary-istio-virtualservice-analysistemplate.png" width="1100px" >}}

[Figure 6] diagrams a Traffic Routing Test Case using Istio Virtual Service and AnalysisTemplate. Immediately after changing the Container Image, one Canary Version Pod is created immediately due to Weight 20% setting, and analysis is performed after 30 seconds. The first analysis fails and Promotion is aborted, and the second analysis succeeds and Promotion is completed, causing Canary Version Pods to increase to 5 due to Weight 100% setting.

```yaml {caption="[Manifest 14] Canary with Istio Virtual Service and AnalysisTemplate Test Case"}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 5
  selector:
    matchLabels:
      app: mock-server
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 30s}
      - analysis:
          templates:
          - templateName: success-rate
      - setWeight: 100
      stableService: mock-server-stable
      canaryService: mock-server-canary
      trafficRouting:
        istio:
          virtualService:
            name: mock-server
            routes:
            - primary
  template:
    metadata:
      labels:
        app: mock-server
    spec:
      containers:
      - name: mock-server
        image: ghcr.io/ssup2/mock-go-server:1.0.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-stable
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-canary
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mock-server
spec:
  hosts:
  - mock-server-stable
  http:
  - name: primary
    route:
    - destination:
        host: mock-server-stable
      weight: 100
    - destination:
        host: mock-server-canary
      weight: 0
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
  - name: success-rate
    interval: 30s
    count: 3
    successCondition: result >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.istio-system.svc.cluster.local:9090
        query: |
          scalar(
            sum(rate(istio_requests_total{destination_service_name="mock-server-canary",response_code=~"2.."}[1m])) 
            / 
            sum(rate(istio_requests_total{destination_service_name="mock-server-canary"}[1m]))
          )
```

```shell {caption="[Shell 6] Canary with Istio Virtual Service and AnalysisTemplate Test Case"}
$ kubectl apply -f mock-server-canary-istio-virtualservice-analysis.yaml
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          4/4
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ✔ Healthy  7s   
└──# revision:1                                                      
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  7s   stable
      ├──□ mock-server-6579c6cc98-fvgp4  Pod         ✔ Running  7s   ready:1/1
      ├──□ mock-server-6579c6cc98-krkhs  Pod         ✔ Running  7s   ready:1/1
      ├──□ mock-server-6579c6cc98-kz6f7  Pod         ✔ Running  7s   ready:1/1
      ├──□ mock-server-6579c6cc98-xplk5  Pod         ✔ Running  7s   ready:1/1
      └──□ mock-server-6579c6cc98-xvb8s  Pod         ✔ Running  7s   ready:1/1

# set mock-server image to 2.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:2.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/4
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ॥ Paused   30s  
├──# revision:2                                                      
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy  9s   canary
│     └──□ mock-server-7c6fcfb847-4tzhx  Pod         ✔ Running  9s   ready:1/1
└──# revision:1                                                      
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  30s  stable
      ├──□ mock-server-6579c6cc98-fvgp4  Pod         ✔ Running  30s  ready:1/1
      ├──□ mock-server-6579c6cc98-krkhs  Pod         ✔ Running  30s  ready:1/1
      ├──□ mock-server-6579c6cc98-kz6f7  Pod         ✔ Running  30s  ready:1/1
      ├──□ mock-server-6579c6cc98-xplk5  Pod         ✔ Running  30s  ready:1/1
      └──□ mock-server-6579c6cc98-xvb8s  Pod         ✔ Running  30s  ready:1/1

# Failed promotion
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          2/4
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                     KIND         STATUS         AGE  INFO
⟳ mock-server                            Rollout      ◌ Progressing  64s  
├──# revision:2                                                           
│  ├──⧉ mock-server-7c6fcfb847           ReplicaSet   ✔ Healthy      43s  canary
│  │  └──□ mock-server-7c6fcfb847-4tzhx  Pod          ✔ Running      43s  ready:1/1
│  └──α mock-server-7c6fcfb847-2-2       AnalysisRun  ◌ Running      9s   ✖ 1
└──# revision:1                                                           
   └──⧉ mock-server-6579c6cc98           ReplicaSet   ✔ Healthy      64s  stable
      ├──□ mock-server-6579c6cc98-fvgp4  Pod          ✔ Running      64s  ready:1/1
      ├──□ mock-server-6579c6cc98-krkhs  Pod          ✔ Running      64s  ready:1/1
      ├──□ mock-server-6579c6cc98-kz6f7  Pod          ✔ Running      64s  ready:1/1
      ├──□ mock-server-6579c6cc98-xplk5  Pod          ✔ Running      64s  ready:1/1
      └──□ mock-server-6579c6cc98-xvb8s  Pod          ✔ Running      64s  ready:1/1

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 2: Metric "success-rate" assessed Failed due to failed (3) > failureLimit (2)
Strategy:        Canary
  Step:          0/4
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                     KIND         STATUS      AGE   INFO
⟳ mock-server                            Rollout      ✖ Degraded  2m1s  
├──# revision:2                                                         
│  ├──⧉ mock-server-7c6fcfb847           ReplicaSet   ✔ Healthy   100s  canary,delay:23s
│  │  └──□ mock-server-7c6fcfb847-4tzhx  Pod          ✔ Running   100s  ready:1/1
│  └──α mock-server-7c6fcfb847-2-2       AnalysisRun  ✖ Failed    66s   ✖ 3
└──# revision:1                                                         
   └──⧉ mock-server-6579c6cc98           ReplicaSet   ✔ Healthy   2m1s  stable
      ├──□ mock-server-6579c6cc98-fvgp4  Pod          ✔ Running   2m1s  ready:1/1
      ├──□ mock-server-6579c6cc98-krkhs  Pod          ✔ Running   2m1s  ready:1/1
      ├──□ mock-server-6579c6cc98-kz6f7  Pod          ✔ Running   2m1s  ready:1/1
      ├──□ mock-server-6579c6cc98-xplk5  Pod          ✔ Running   2m1s  ready:1/1
      └──□ mock-server-6579c6cc98-xvb8s  Pod          ✔ Running   2m1s  ready:1/1

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 2: Metric "success-rate" assessed Failed due to failed (3) > failureLimit (2)
Strategy:        Canary
  Step:          0/4
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                     KIND         STATUS        AGE    INFO
⟳ mock-server                            Rollout      ✖ Degraded    2m27s  
├──# revision:2                                                            
│  ├──⧉ mock-server-7c6fcfb847           ReplicaSet   • ScaledDown  2m6s   canary,delay:passed
│  └──α mock-server-7c6fcfb847-2-2       AnalysisRun  ✖ Failed      92s    ✖ 3
└──# revision:1                                                            
   └──⧉ mock-server-6579c6cc98           ReplicaSet   ✔ Healthy     2m27s  stable
      ├──□ mock-server-6579c6cc98-fvgp4  Pod          ✔ Running     2m27s  ready:1/1
      ├──□ mock-server-6579c6cc98-krkhs  Pod          ✔ Running     2m27s  ready:1/1
      ├──□ mock-server-6579c6cc98-kz6f7  Pod          ✔ Running     2m27s  ready:1/1
      ├──□ mock-server-6579c6cc98-xplk5  Pod          ✔ Running     2m27s  ready:1/1
      └──□ mock-server-6579c6cc98-xvb8s  Pod          ✔ Running     2m27s  ready:1/1

# Successful promotion
$ kubectl argo rollouts retry rollout mock-server
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          2/4
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                     KIND         STATUS         AGE    INFO
⟳ mock-server                            Rollout      ◌ Progressing  3m31s  
├──# revision:2                                                             
│  ├──⧉ mock-server-7c6fcfb847           ReplicaSet   ✔ Healthy      3m10s  canary
│  │  └──□ mock-server-7c6fcfb847-9nhrs  Pod          ✔ Running      38s    ready:1/1
│  ├──α mock-server-7c6fcfb847-2-2       AnalysisRun  ✖ Failed       2m36s  ✖ 3
│  └──α mock-server-7c6fcfb847-2-2.1     AnalysisRun  ◌ Running      3s     ✖ 1
└──# revision:1                                                             
   └──⧉ mock-server-6579c6cc98           ReplicaSet   ✔ Healthy      3m31s  stable
      ├──□ mock-server-6579c6cc98-fvgp4  Pod          ✔ Running      3m31s  ready:1/1
      ├──□ mock-server-6579c6cc98-krkhs  Pod          ✔ Running      3m31s  ready:1/1
      ├──□ mock-server-6579c6cc98-kz6f7  Pod          ✔ Running      3m31s  ready:1/1
      ├──□ mock-server-6579c6cc98-xplk5  Pod          ✔ Running      3m31s  ready:1/1
      └──□ mock-server-6579c6cc98-xvb8s  Pod          ✔ Running      3m31s  ready:1/1

$ kubectl exec -it shell -- curl -s mock-server-stable:80/status/200
$ kubectl exec -it shell -- curl -s mock-server-stable:80/status/200
...

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          4/4
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:1.0.0
                 ghcr.io/ssup2/mock-go-server:2.0.0 (stable)
Replicas:
  Desired:       5
  Current:       10
  Updated:       5
  Ready:         10
  Available:     10

NAME                                     KIND         STATUS        AGE    INFO
⟳ mock-server                            Rollout      ✔ Healthy     4m57s  
├──# revision:2                                                            
│  ├──⧉ mock-server-7c6fcfb847           ReplicaSet   ✔ Healthy     4m36s  stable
│  │  ├──□ mock-server-7c6fcfb847-9nhrs  Pod          ✔ Running     2m4s   ready:1/1
│  │  ├──□ mock-server-7c6fcfb847-bdwzm  Pod          ✔ Running     29s    ready:1/1
│  │  ├──□ mock-server-7c6fcfb847-k7g4h  Pod          ✔ Running     29s    ready:1/1
│  │  ├──□ mock-server-7c6fcfb847-ktk2v  Pod          ✔ Running     29s    ready:1/1
│  │  └──□ mock-server-7c6fcfb847-rj7gn  Pod          ✔ Running     29s    ready:1/1
│  ├──α mock-server-7c6fcfb847-2-2       AnalysisRun  ✖ Failed      4m2s   ✖ 3
│  └──α mock-server-7c6fcfb847-2-2.1     AnalysisRun  ✔ Successful  89s    ✔ 2,✖ 1
└──# revision:1                                                            
   └──⧉ mock-server-6579c6cc98           ReplicaSet   ✔ Healthy     4m57s  delay:4s
      ├──□ mock-server-6579c6cc98-fvgp4  Pod          ✔ Running     4m57s  ready:1/1
      ├──□ mock-server-6579c6cc98-krkhs  Pod          ✔ Running     4m57s  ready:1/1
      ├──□ mock-server-6579c6cc98-kz6f7  Pod          ✔ Running     4m57s  ready:1/1
      ├──□ mock-server-6579c6cc98-xplk5  Pod          ✔ Running     4m57s  ready:1/1
      └──□ mock-server-6579c6cc98-xvb8s  Pod          ✔ Running     4m57s  ready:1/1
```

[Manifest 14] shows the Manifest for the Traffic Routing Test Case using Istio Virtual Service and AnalysisTemplate, and [Shell 6] shows the process of performing that Test Case. AnalysisTemplate is configured using Istio's `istio_requests_total` Metric, and it can be confirmed that analysis proceeds as AnalysisRun Object is created.

#### 2.2.6. Canary with Istio Virtual Service, AnalysisTemplate and Experiment

{{< figure caption="[Figure 7] Canary with Istio Virtual Service, AnalysisTemplate and Experiment Test Case" src="images/argo-rollouts-case-canary-istio-virtualservice-analysistemplate-experiment.png" width="1000px" >}}

[Figure 7] diagrams a Traffic Routing Test Case using Istio Virtual Service, AnalysisTemplate, and Experiment. Through Experiment, Experiment Stable (Baseline) Version and Experiment Canary Version are deployed, and analysis is performed by distributing Traffic in a 3:1:1 ratio for 2 minutes. If analysis succeeds, Experiment is changed to success status, and according to the next step, one Pod of Canary Version is increased to distribute Traffic in a 4:1 ratio. After that, the same process as [Figure 6] is performed.

```yaml {caption="[Manifest 15] Canary with Istio Virtual Service, AnalysisTemplate and Experiment Test Case"}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 5
  selector:
    matchLabels:
      app: mock-server
  strategy:
    canary:
      steps:
      - experiment:
          duration: 2m
          templates:
          - name: stable
            specRef: stable
            weight: 20
            service:
              name: mock-server-experiment-stable
          - name: canary
            specRef: canary
            weight: 20
            service:
              name: mock-server-experiment-canary
          analyses:
          - name: stable-canary-comparison
            templateName: stable-canary-comparison
            args:
            - name: stable-replicaset
              value: "{{templates.stable.replicaset.name}}"
            - name: canary-replicaset
              value: "{{templates.canary.replicaset.name}}"
      - setWeight: 20
      - pause: {duration: 30s}
      - analysis:
          templates:
          - templateName: success-rate
      - setWeight: 100
      stableService: mock-server-stable
      canaryService: mock-server-canary
      trafficRouting:
        istio:
          virtualService:
            name: mock-server
            routes:
            - primary
  template:
    metadata:
      labels:
        app: mock-server
    spec:
      containers:
      - name: mock-server
        image: ghcr.io/ssup2/mock-go-server:1.0.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-stable
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server-canary
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mock-server
spec:
  hosts:
  - mock-server-stable
  http:
  - name: primary
    route:
    - destination:
        host: mock-server-stable
      weight: 100
    - destination:
        host: mock-server-canary
      weight: 0
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
  - name: success-rate
    interval: 30s
    count: 3
    successCondition: result >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.istio-system.svc.cluster.local:9090
        query: |
          scalar(
            sum(rate(istio_requests_total{destination_service_name="mock-server-canary",response_code=~"2.."}[1m])) 
            / 
            sum(rate(istio_requests_total{destination_service_name="mock-server-canary"}[1m]))
          )
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: stable-canary-comparison
spec:
  args:
  - name: stable-replicaset
  - name: canary-replicaset
  metrics:
  - name: stable-success-rate
    interval: 30s
    count: 3
    successCondition: result >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.istio-system.svc.cluster.local:9090
        query: |
          scalar(
            sum(rate(istio_requests_total{
              destination_service_name="mock-server-experiment-stable",
              destination_workload="{{args.stable-replicaset}}",
              response_code=~"2.."
            }[1m])) 
            / 
            sum(rate(istio_requests_total{
              destination_service_name="mock-server-experiment-stable,
              destination_workload="{{args.stable-replicaset}}"
            }[1m]))
          )
  - name: canary-success-rate
    interval: 30s
    count: 3
    successCondition: result >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.istio-system.svc.cluster.local:9090
        query: |
          scalar(
            sum(rate(istio_requests_total{
              destination_service_name="mock-server-experiment-canary",
              destination_workload="{{args.canary-replicaset}}",
              response_code=~"2.."
            }[1m])) 
            / 
            sum(rate(istio_requests_total{
              destination_service_name="mock-server-experiment-canary",
              destination_workload="{{args.canary-replicaset}}"
            }[1m]))
          )
```

```shell {caption="[Shell 7] Canary with Istio Virtual Service, AnalysisTemplate and Experiment Test Case"}
# Deploy mock-server canary rollout and check status
$ kubectl apply -f mock-server-canary-istio-virtualservice-analysis-experiment.yaml
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ✔ Healthy  4s   
└──# revision:1                                                      
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  4s   stable
      ├──□ mock-server-6579c6cc98-45cmf  Pod         ✔ Running  4s   ready:1/1
      ├──□ mock-server-6579c6cc98-4rz7c  Pod         ✔ Running  4s   ready:1/1
      ├──□ mock-server-6579c6cc98-c9f7l  Pod         ✔ Running  4s   ready:1/1
      ├──□ mock-server-6579c6cc98-f2zzr  Pod         ✔ Running  4s   ready:1/1
      └──□ mock-server-6579c6cc98-mgwzp  Pod         ✔ Running  4s   ready:1/1

# set mock-server image to 2.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:2.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          0/5
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, Σ:stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (Σ:canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                                            KIND         STATUS         AGE  INFO
⟳ mock-server                                                   Rollout      ◌ Progressing  24s  
├──# revision:2                                                                                  
│  ├──⧉ mock-server-7c6fcfb847                                  ReplicaSet   • ScaledDown   5s   canary
│  └──Σ mock-server-7c6fcfb847-2-0                              Experiment   ◌ Running      5s   
│     ├──⧉ mock-server-7c6fcfb847-2-0-canary                    ReplicaSet   ✔ Healthy      5s   
│     │  └──□ mock-server-7c6fcfb847-2-0-canary-4rhbp           Pod          ✔ Running      5s   ready:1/1
│     ├──⧉ mock-server-7c6fcfb847-2-0-stable                    ReplicaSet   ✔ Healthy      5s   
│     │  └──□ mock-server-7c6fcfb847-2-0-stable-2bjk6           Pod          ✔ Running      5s   ready:1/1
│     └──α mock-server-7c6fcfb847-2-0-stable-canary-comparison  AnalysisRun  ◌ Running      1s   ✖ 2
└──# revision:1                                                                                  
   └──⧉ mock-server-6579c6cc98                                  ReplicaSet   ✔ Healthy      24s  stable
      ├──□ mock-server-6579c6cc98-45cmf                         Pod          ✔ Running      24s  ready:1/1
      ├──□ mock-server-6579c6cc98-4rz7c                         Pod          ✔ Running      24s  ready:1/1
      ├──□ mock-server-6579c6cc98-c9f7l                         Pod          ✔ Running      24s  ready:1/1
      ├──□ mock-server-6579c6cc98-f2zzr                         Pod          ✔ Running      24s  ready:1/1
      └──□ mock-server-6579c6cc98-mgwzp                         Pod          ✔ Running      24s  ready:1/1

$ kubectl describe virtualservice mock-server
...
Spec:
  Hosts:
    mock-server-stable
  Http:
    Name:  primary
    Route:
      Destination:
        Host:  mock-server-stable
      Weight:  60
      Destination:
        Host:  mock-server-canary
      Weight:  0
      Destination:
        Host:  mock-server-experiment-stable
      Weight:  20
      Destination:
        Host:  mock-server-experiment-canary
      Weight:  20

$ kubectl get service
NAME                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes                      ClusterIP   10.96.0.1       <none>        443/TCP    3d23h
mock-server-canary              ClusterIP   10.96.247.219   <none>        8080/TCP   75s
mock-server-experiment-canary   ClusterIP   10.96.103.47    <none>        8080/TCP   42s
mock-server-experiment-stable   ClusterIP   10.96.154.68    <none>        8080/TCP   42s
mock-server-stable              ClusterIP   10.96.63.99     <none>        8080/TCP   75s

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 2: Metric "stable-success-rate" assessed Failed due to failed (3) > failureLimit (2)
Strategy:        Canary
  Step:          0/5
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                                            KIND         STATUS        AGE   INFO
⟳ mock-server                                                   Rollout      ✖ Degraded    2m2s  
├──# revision:2                                                                                  
│  ├──⧉ mock-server-7c6fcfb847                                  ReplicaSet   • ScaledDown  103s  canary,delay:passed
│  └──Σ mock-server-7c6fcfb847-2-0                              Experiment   ✖ Failed      103s  
│     ├──⧉ mock-server-7c6fcfb847-2-0-canary                    ReplicaSet   • ScaledDown  103s  delay:passed
│     ├──⧉ mock-server-7c6fcfb847-2-0-stable                    ReplicaSet   • ScaledDown  103s  delay:passed
│     └──α mock-server-7c6fcfb847-2-0-stable-canary-comparison  AnalysisRun  ✖ Failed      99s   ✖ 6
└──# revision:1                                                                                  
   └──⧉ mock-server-6579c6cc98                                  ReplicaSet   ✔ Healthy     2m2s  stable
      ├──□ mock-server-6579c6cc98-45cmf                         Pod          ✔ Running     2m2s  ready:1/1
      ├──□ mock-server-6579c6cc98-4rz7c                         Pod          ✔ Running     2m2s  ready:1/1
      ├──□ mock-server-6579c6cc98-c9f7l                         Pod          ✔ Running     2m2s  ready:1/1
      ├──□ mock-server-6579c6cc98-f2zzr                         Pod          ✔ Running     2m2s  ready:1/1
      └──□ mock-server-6579c6cc98-mgwzp                         Pod          ✔ Running     2m2s  ready:1/1

# Retry mock-server rollout
$ kubectl argo rollouts retry rollout mock-server
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          0/5
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, Σ:stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (Σ:canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                                              KIND         STATUS         AGE    INFO
⟳ mock-server                                                     Rollout      ◌ Progressing  2m42s  
├──# revision:2                                                                                      
│  ├──⧉ mock-server-7c6fcfb847                                    ReplicaSet   • ScaledDown   2m23s  canary
│  ├──Σ mock-server-7c6fcfb847-2-0                                Experiment   ✖ Failed       2m23s  
│  │  ├──⧉ mock-server-7c6fcfb847-2-0-canary                      ReplicaSet   • ScaledDown   2m23s  delay:passed
│  │  ├──⧉ mock-server-7c6fcfb847-2-0-stable                      ReplicaSet   • ScaledDown   2m23s  delay:passed
│  │  └──α mock-server-7c6fcfb847-2-0-stable-canary-comparison    AnalysisRun  ✖ Failed       2m19s  ✖ 6
│  └──Σ mock-server-7c6fcfb847-2-0-1                              Experiment   ◌ Running      18s    
│     ├──⧉ mock-server-7c6fcfb847-2-0-1-canary                    ReplicaSet   ✔ Healthy      18s    
│     │  └──□ mock-server-7c6fcfb847-2-0-1-canary-4sj6l           Pod          ✔ Running      17s    ready:1/1
│     ├──⧉ mock-server-7c6fcfb847-2-0-1-stable                    ReplicaSet   ✔ Healthy      18s    
│     │  └──□ mock-server-7c6fcfb847-2-0-1-stable-xhqgp           Pod          ✔ Running      17s    ready:1/1
│     └──α mock-server-7c6fcfb847-2-0-1-stable-canary-comparison  AnalysisRun  ◌ Running      13s    ✖ 2
└──# revision:1                                                                                      
   └──⧉ mock-server-6579c6cc98                                    ReplicaSet   ✔ Healthy      2m42s  stable
      ├──□ mock-server-6579c6cc98-45cmf                           Pod          ✔ Running      2m42s  ready:1/1
      ├──□ mock-server-6579c6cc98-4rz7c                           Pod          ✔ Running      2m42s  ready:1/1
      ├──□ mock-server-6579c6cc98-c9f7l                           Pod          ✔ Running      2m42s  ready:1/1
      ├──□ mock-server-6579c6cc98-f2zzr                           Pod          ✔ Running      2m42s  ready:1/1
      └──□ mock-server-6579c6cc98-mgwzp                           Pod          ✔ Running      2m42s  ready:1/1

$ kubectl exec -it shell -- curl -s mock-server-stable:8080/status/200
$ kubectl exec -it shell -- curl -s mock-server-canary:8080/status/200
...

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          0/5
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, Σ:stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (Σ:canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                                              KIND         STATUS         AGE    INFO
⟳ mock-server                                                     Rollout      ◌ Progressing  3m43s  
├──# revision:2                                                                                      
│  ├──⧉ mock-server-7c6fcfb847                                    ReplicaSet   • ScaledDown   3m24s  canary
│  ├──Σ mock-server-7c6fcfb847-2-0                                Experiment   ✖ Failed       3m24s  
│  │  ├──⧉ mock-server-7c6fcfb847-2-0-canary                      ReplicaSet   • ScaledDown   3m24s  delay:passed
│  │  ├──⧉ mock-server-7c6fcfb847-2-0-stable                      ReplicaSet   • ScaledDown   3m24s  delay:passed
│  │  └──α mock-server-7c6fcfb847-2-0-stable-canary-comparison    AnalysisRun  ✖ Failed       3m20s  ✖ 6
│  └──Σ mock-server-7c6fcfb847-2-0-1                              Experiment   ◌ Running      79s    
│     ├──⧉ mock-server-7c6fcfb847-2-0-1-canary                    ReplicaSet   ✔ Healthy      79s    
│     │  └──□ mock-server-7c6fcfb847-2-0-1-canary-4sj6l           Pod          ✔ Running      78s    ready:1/1
│     ├──⧉ mock-server-7c6fcfb847-2-0-1-stable                    ReplicaSet   ✔ Healthy      79s    
│     │  └──□ mock-server-7c6fcfb847-2-0-1-stable-xhqgp           Pod          ✔ Running      78s    ready:1/1
│     └──α mock-server-7c6fcfb847-2-0-1-stable-canary-comparison  AnalysisRun  ✔ Successful   74s    ✔ 2,✖ 4
└──# revision:1                                                                                      
   └──⧉ mock-server-6579c6cc98                                    ReplicaSet   ✔ Healthy      3m43s  stable
      ├──□ mock-server-6579c6cc98-45cmf                           Pod          ✔ Running      3m43s  ready:1/1
      ├──□ mock-server-6579c6cc98-4rz7c                           Pod          ✔ Running      3m43s  ready:1/1
      ├──□ mock-server-6579c6cc98-c9f7l                           Pod          ✔ Running      3m43s  ready:1/1
      ├──□ mock-server-6579c6cc98-f2zzr                           Pod          ✔ Running      3m43s  ready:1/1
      └──□ mock-server-6579c6cc98-mgwzp                           Pod          ✔ Running      3m43s  ready:1/1

# Continue mock-server rollout
$ kubectl get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          2/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, Σ:stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary, Σ:canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                                              KIND         STATUS        AGE    INFO
⟳ mock-server                                                     Rollout      ॥ Paused      4m54s  
├──# revision:2                                                                                     
│  ├──⧉ mock-server-7c6fcfb847                                    ReplicaSet   ✔ Healthy     4m35s  canary
│  │  └──□ mock-server-7c6fcfb847-6jrmj                           Pod          ✔ Running     25s    ready:1/1
│  ├──Σ mock-server-7c6fcfb847-2-0                                Experiment   ✖ Failed      4m35s  
│  │  ├──⧉ mock-server-7c6fcfb847-2-0-canary                      ReplicaSet   • ScaledDown  4m35s  delay:passed
│  │  ├──⧉ mock-server-7c6fcfb847-2-0-stable                      ReplicaSet   • ScaledDown  4m35s  delay:passed
│  │  └──α mock-server-7c6fcfb847-2-0-stable-canary-comparison    AnalysisRun  ✖ Failed      4m31s  ✖ 6
│  └──Σ mock-server-7c6fcfb847-2-0-1                              Experiment   ✔ Successful  2m30s  
│     ├──⧉ mock-server-7c6fcfb847-2-0-1-canary                    ReplicaSet   ✔ Healthy     2m30s  delay:4s
│     │  └──□ mock-server-7c6fcfb847-2-0-1-canary-4sj6l           Pod          ✔ Running     2m29s  ready:1/1
│     ├──⧉ mock-server-7c6fcfb847-2-0-1-stable                    ReplicaSet   ✔ Healthy     2m30s  delay:4s
│     │  └──□ mock-server-7c6fcfb847-2-0-1-stable-xhqgp           Pod          ✔ Running     2m29s  ready:1/1
│     └──α mock-server-7c6fcfb847-2-0-1-stable-canary-comparison  AnalysisRun  ✔ Successful  2m25s  ✔ 2,✖ 4
└──# revision:1                                                                                     
   └──⧉ mock-server-6579c6cc98                                    ReplicaSet   ✔ Healthy     4m54s  stable
      ├──□ mock-server-6579c6cc98-45cmf                           Pod          ✔ Running     4m54s  ready:1/1
      ├──□ mock-server-6579c6cc98-4rz7c                           Pod          ✔ Running     4m54s  ready:1/1
      ├──□ mock-server-6579c6cc98-c9f7l                           Pod          ✔ Running     4m54s  ready:1/1
      ├──□ mock-server-6579c6cc98-f2zzr                           Pod          ✔ Running     4m54s  ready:1/1
      └──□ mock-server-6579c6cc98-mgwzp                           Pod          ✔ Running     4m54s  ready:1/1

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          3/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                                              KIND         STATUS         AGE    INFO
⟳ mock-server                                                     Rollout      ◌ Progressing  5m20s  
├──# revision:2                                                                                      
│  ├──⧉ mock-server-7c6fcfb847                                    ReplicaSet   ✔ Healthy      5m1s   canary
│  │  └──□ mock-server-7c6fcfb847-6jrmj                           Pod          ✔ Running      51s    ready:1/1
│  ├──Σ mock-server-7c6fcfb847-2-0                                Experiment   ✖ Failed       5m1s   
│  │  ├──⧉ mock-server-7c6fcfb847-2-0-canary                      ReplicaSet   • ScaledDown   5m1s   delay:passed
│  │  ├──⧉ mock-server-7c6fcfb847-2-0-stable                      ReplicaSet   • ScaledDown   5m1s   delay:passed
│  │  └──α mock-server-7c6fcfb847-2-0-stable-canary-comparison    AnalysisRun  ✖ Failed       4m57s  ✖ 6
│  ├──Σ mock-server-7c6fcfb847-2-0-1                              Experiment   ✔ Successful   2m56s  
│  │  ├──⧉ mock-server-7c6fcfb847-2-0-1-canary                    ReplicaSet   • ScaledDown   2m56s  delay:passed
│  │  ├──⧉ mock-server-7c6fcfb847-2-0-1-stable                    ReplicaSet   • ScaledDown   2m56s  delay:passed
│  │  └──α mock-server-7c6fcfb847-2-0-1-stable-canary-comparison  AnalysisRun  ✔ Successful   2m51s  ✔ 2,✖ 4
│  └──α mock-server-7c6fcfb847-2-3                                AnalysisRun  ◌ Running      17s    ✖ 1
└──# revision:1                                                                                      
   └──⧉ mock-server-6579c6cc98                                    ReplicaSet   ✔ Healthy      5m20s  stable
      ├──□ mock-server-6579c6cc98-45cmf                           Pod          ✔ Running      5m20s  ready:1/1
      ├──□ mock-server-6579c6cc98-4rz7c                           Pod          ✔ Running      5m20s  ready:1/1
      ├──□ mock-server-6579c6cc98-c9f7l                           Pod          ✔ Running      5m20s  ready:1/1
      ├──□ mock-server-6579c6cc98-f2zzr                           Pod          ✔ Running      5m20s  ready:1/1
      └──□ mock-server-6579c6cc98-mgwzp                           Pod          ✔ Running      5m20s  ready:1/1
```

[Manifest 15] shows the Manifest for the Traffic Routing Test Case using Istio Virtual Service, AnalysisTemplate, and Experiment, and [Shell 7] shows the process of performing that Test Case. AnalysisTemplate is configured using Istio's `istio_requests_total` Metric, and it can be confirmed that analysis proceeds as AnalysisRun Object is created.

#### 2.2.7. Canary with Istio Destination Rule

{{< figure caption="[Figure 8] Canary with Istio Destination Rule Test Case" src="images/argo-rollouts-case-canary-istio-destinationrule.png" width="800px" >}}

[Figure 8] diagrams a Traffic Routing Test Case using Istio Destination Rule. Argo Rollouts also supports Traffic Routing using Istio's Destination Rule Subsets. Except for the part of using Destination Rule, it performs the same process as [Figure 5].

```yaml {caption="[Manifest 16] Canary with Istio Destination Rule Test Case"}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 5
  selector:
    matchLabels:
      app: mock-server
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {}
      - setWeight: 40
      - pause: {}
      - setWeight: 100
      trafficRouting:
        istio:
          virtualService:
            name: mock-server
            routes:
            - primary
          destinationRule:
            name: mock-server
            stableSubsetName: stable
            canarySubsetName: canary
  template:
    metadata:
      labels:
        app: mock-server
    spec:
      containers:
      - name: mock-server
        image: ghcr.io/ssup2/mock-go-server:1.0.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mock-server
spec:
  hosts:
  - mock-server
  http:
  - name: primary
    route:
    - destination:
        host: mock-server
        subset: stable
      weight: 100
    - destination:
        host: mock-server
        subset: canary
      weight: 0
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: mock-server
spec:
  host: mock-server
  subsets:
  - name: stable
    labels:
      app: mock-server
  - name: canary
    labels:
      app: mock-server
```

```shell {caption="[Shell 8] Canary with Istio Destination Rule Test Case"}
# Deploy mock-server canary rollout and check status
$ kubectl apply -f mock-server-canary-istio-virtualservice.yaml
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ✔ Healthy  6s   
└──# revision:1                                                      
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  6s   stable
      ├──□ mock-server-6579c6cc98-57kmd  Pod         ✔ Running  6s   ready:1/1
      ├──□ mock-server-6579c6cc98-7w5k4  Pod         ✔ Running  6s   ready:1/1
      ├──□ mock-server-6579c6cc98-gxkjw  Pod         ✔ Running  6s   ready:1/1
      ├──□ mock-server-6579c6cc98-rfzmb  Pod         ✔ Running  6s   ready:1/1
      └──□ mock-server-6579c6cc98-xp4c4  Pod         ✔ Running  6s   ready:1/1

$ kubectl describe virtualservice mock-server
...
Spec:
  Hosts:
    mock-server
  Http:
    Name:  primary
    Route:
      Destination:
        Host:    mock-server
        Subset:  stable
      Weight:  100
      Destination:
        Host:    mock-server
        Subset:  canary
      Weight:  0

$ kubectl describe destinationrule mock-server
...
Spec:
  Host:  mock-server
  Subsets:
    Labels:
      App:                               mock-server
      Rollouts - Pod - Template - Hash:  6579c6cc98
    Name:                                stable
    Labels:
      App:                               mock-server
      Rollouts - Pod - Template - Hash:  6579c6cc98
    Name:                                canary

# Set mock-server image to 2.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:2.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ॥ Paused   74s  
├──# revision:2                                                      
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy  11s  canary
│     └──□ mock-server-7c6fcfb847-6mbd7  Pod         ✔ Running  10s  ready:1/1
└──# revision:1                                                      
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  74s  stable
      ├──□ mock-server-6579c6cc98-57kmd  Pod         ✔ Running  74s  ready:1/1
      ├──□ mock-server-6579c6cc98-7w5k4  Pod         ✔ Running  74s  ready:1/1
      ├──□ mock-server-6579c6cc98-gxkjw  Pod         ✔ Running  74s  ready:1/1
      ├──□ mock-server-6579c6cc98-rfzmb  Pod         ✔ Running  74s  ready:1/1
      └──□ mock-server-6579c6cc98-xp4c4  Pod         ✔ Running  74s  ready:1/1

$ kubectl describe virtualservice mock-server
...
Spec:
  Hosts:
    mock-server
  Http:
    Name:  primary
    Route:
      Destination:
        Host:    mock-server
        Subset:  stable
      Weight:  80
      Destination:
        Host:    mock-server
        Subset:  canary
      Weight:  20

$ kubectl describe destinationrule mock-server
...
Spec:
  Host:  mock-server
  Subsets:
    Labels:
      App:                               mock-server
      Rollouts - Pod - Template - Hash:  6579c6cc98
    Name:                                stable
    Labels:
      App:                               mock-server
      Rollouts - Pod - Template - Hash:  7c6fcfb847
    Name:                                canary

# Promote mock-server rollout
$ kubectl argo rollouts promote mock-server
$ kubectl argo rollouts get rollout mock-server
kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          3/5
  SetWeight:     40
  ActualWeight:  40
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       7
  Updated:       2
  Ready:         7
  Available:     7

NAME                                     KIND        STATUS     AGE    INFO
⟳ mock-server                            Rollout     ॥ Paused   2m16s  
├──# revision:2                                                        
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy  73s    canary
│     ├──□ mock-server-7c6fcfb847-6mbd7  Pod         ✔ Running  72s    ready:1/1
│     └──□ mock-server-7c6fcfb847-sp75c  Pod         ✔ Running  6s     ready:1/1
└──# revision:1                                                        
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  2m16s  stable
      ├──□ mock-server-6579c6cc98-57kmd  Pod         ✔ Running  2m16s  ready:1/1
      ├──□ mock-server-6579c6cc98-7w5k4  Pod         ✔ Running  2m16s  ready:1/1
      ├──□ mock-server-6579c6cc98-gxkjw  Pod         ✔ Running  2m16s  ready:1/1
      ├──□ mock-server-6579c6cc98-rfzmb  Pod         ✔ Running  2m16s  ready:1/1
      └──□ mock-server-6579c6cc98-xp4c4  Pod         ✔ Running  2m16s  ready:1/1

$ kubectl describe virtualservice mock-server
...
Spec:
  Hosts:
    mock-server
  Http:
    Name:  primary
    Route:
      Destination:
        Host:    mock-server
        Subset:  stable
      Weight:  60
      Destination:
        Host:    mock-server
        Subset:  canary
      Weight:  40

$ kubectl describe destinationrule mock-server
...
Spec:
  Host:  mock-server
  Subsets:
    Labels:
      App:                               mock-server
      Rollouts - Pod - Template - Hash:  6579c6cc98
    Name:                                stable
    Labels:
      App:                               mock-server
      Rollouts - Pod - Template - Hash:  7c6fcfb847
    Name:                                canary

# Promote mock-server rollout again
$ kubectl argo rollouts promote mock-server
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:2.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS        AGE    INFO
⟳ mock-server                            Rollout     ✔ Healthy     6m40s  
├──# revision:2                                                           
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy     5m37s  stable
│     ├──□ mock-server-7c6fcfb847-6mbd7  Pod         ✔ Running     5m36s  ready:1/1
│     ├──□ mock-server-7c6fcfb847-sp75c  Pod         ✔ Running     4m30s  ready:1/1
│     ├──□ mock-server-7c6fcfb847-mc2b2  Pod         ✔ Running     40s    ready:1/1
│     ├──□ mock-server-7c6fcfb847-kd8cr  Pod         ✔ Running     39s    ready:1/1
│     └──□ mock-server-7c6fcfb847-n6wrr  Pod         ✔ Running     39s    ready:1/1
└──# revision:1                                                           
   └──⧉ mock-server-6579c6cc98           ReplicaSet  • ScaledDown  6m40s 

$ kubectl describe virtualservice mock-server
...
Spec:
  Hosts:
    mock-server
  Http:
    Name:  primary
    Route:
      Destination:
        Host:    mock-server
        Subset:  stable
      Weight:  100
      Destination:
        Host:    mock-server
        Subset:  canary
      Weight:  0

$ kubectl describe destinationrule mock-server
...
Spec:
  Host:  mock-server
  Subsets:
    Labels:
      App:                               mock-server
      Rollouts - Pod - Template - Hash:  7c6fcfb847
    Name:                                stable
    Labels:
      App:                               mock-server
      Rollouts - Pod - Template - Hash:  7c6fcfb847
    Name:                                canary
```

[Manifest 16] shows the Manifest for the Traffic Routing Test Case using Istio Destination Rule, and [Shell 8] shows the process of performing that Test Case. It can be confirmed that the weight of the `mock-server` Virtual Service is specified by Destination Rule's Subset unit. The weight of the `canary` Subset increases and then changes back to 0 after Promotion is completed.

#### 2.2.8. Canary with Istio Destination Rule and AnalysisTemplate

{{< figure caption="[Figure 9] Canary with Istio Destination Rule and AnalysisTemplate Test Case" src="images/argo-rollouts-case-canary-istio-destinationrule-analysistemplate.png" width="1100px" >}}

[Figure 9] diagrams a Traffic Routing Test Case using Istio Destination Rule and AnalysisTemplate. Except for the part of using Destination Rule, it performs the same process as [Figure 6].

```yaml {caption="[Manifest 17] Canary with Istio Destination Rule and AnalysisTemplate Test Case"}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 5
  selector:
    matchLabels:
      app: mock-server
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 30s}
      - analysis:
          templates:
          - templateName: success-rate
      - setWeight: 100
      trafficRouting:
        istio:
          virtualService:
            name: mock-server
            routes:
            - primary
          destinationRule:
            name: mock-server
            stableSubsetName: stable
            canarySubsetName: canary
  template:
    metadata:
      labels:
        app: mock-server
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "15020"
        prometheus.io/path: "/stats/prometheus"
    spec:
      containers:
      - name: mock-server
        image: ghcr.io/ssup2/mock-go-server:1.0.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mock-server
spec:
  hosts:
  - mock-server
  http:
  - name: primary
    route:
    - destination:
        host: mock-server
        subset: stable
      weight: 100
    - destination:
        host: mock-server
        subset: canary
      weight: 0
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: mock-server
spec:
  host: mock-server
  subsets:
  - name: stable
    labels:
      app: mock-server
  - name: canary
    labels:
      app: mock-server
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
  - name: success-rate
    interval: 30s
    count: 3
    successCondition: result >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.istio-system.svc.cluster.local:9090
        query: |
          scalar(
            sum(rate(istio_requests_total{destination_service_name="mock-server",response_code=~"2.."}[1m])) 
            / 
            sum(rate(istio_requests_total{destination_service_name="mock-server"}[1m]))
          )
```

```shell {caption="[Shell 9] Canary with Istio Destination Rule and AnalysisTemplate Test Case"}
# Deploy mock-server canary rollout and check status
$ kubectl apply -f mock-server-canary-istio-destinationrule-analysistemplate.yaml
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          4/4
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ✔ Healthy  6s   
└──# revision:1                                                      
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  6s   stable
      ├──□ mock-server-6579c6cc98-n2w2t  Pod         ✔ Running  6s   ready:1/1
      ├──□ mock-server-6579c6cc98-2jpvc  Pod         ✔ Running  5s   ready:1/1
      ├──□ mock-server-6579c6cc98-jfhl5  Pod         ✔ Running  5s   ready:1/1
      ├──□ mock-server-6579c6cc98-knl9h  Pod         ✔ Running  5s   ready:1/1
      └──□ mock-server-6579c6cc98-lk7m9  Pod         ✔ Running  5s   ready:1/1

# set mock-server image to 2.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:2.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/4
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                     KIND        STATUS     AGE  INFO
⟳ mock-server                            Rollout     ॥ Paused   74s  
├──# revision:2                                                      
│  └──⧉ mock-server-7c6fcfb847           ReplicaSet  ✔ Healthy  6s   canary
│     └──□ mock-server-7c6fcfb847-q78s6  Pod         ✔ Running  6s   ready:1/1
└──# revision:1                                                      
   └──⧉ mock-server-6579c6cc98           ReplicaSet  ✔ Healthy  74s  stable
      ├──□ mock-server-6579c6cc98-n2w2t  Pod         ✔ Running  74s  ready:1/1
      ├──□ mock-server-6579c6cc98-2jpvc  Pod         ✔ Running  73s  ready:1/1
      ├──□ mock-server-6579c6cc98-jfhl5  Pod         ✔ Running  73s  ready:1/1
      ├──□ mock-server-6579c6cc98-knl9h  Pod         ✔ Running  73s  ready:1/1
      └──□ mock-server-6579c6cc98-lk7m9  Pod         ✔ Running  73s  ready:1/1

# Failed promotion
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          2/4
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                     KIND         STATUS         AGE   INFO
⟳ mock-server                            Rollout      ◌ Progressing  113s  
├──# revision:2                                                            
│  ├──⧉ mock-server-7c6fcfb847           ReplicaSet   ✔ Healthy      45s   canary
│  │  └──□ mock-server-7c6fcfb847-q78s6  Pod          ✔ Running      45s   ready:1/1
│  └──α mock-server-7c6fcfb847-2-2       AnalysisRun  ◌ Running      11s   ✖ 1
└──# revision:1                                                            
   └──⧉ mock-server-6579c6cc98           ReplicaSet   ✔ Healthy      113s  stable
      ├──□ mock-server-6579c6cc98-n2w2t  Pod          ✔ Running      113s  ready:1/1
      ├──□ mock-server-6579c6cc98-2jpvc  Pod          ✔ Running      112s  ready:1/1
      ├──□ mock-server-6579c6cc98-jfhl5  Pod          ✔ Running      112s  ready:1/1
      ├──□ mock-server-6579c6cc98-knl9h  Pod          ✔ Running      112s  ready:1/1
      └──□ mock-server-6579c6cc98-lk7m9  Pod          ✔ Running      112s  ready:1/1

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 2: Metric "success-rate" assessed Failed due to failed (3) > failureLimit (2)
Strategy:        Canary
  Step:          0/4
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                     KIND         STATUS      AGE    INFO
⟳ mock-server                            Rollout      ✖ Degraded  2m43s  
├──# revision:2                                                          
│  ├──⧉ mock-server-7c6fcfb847           ReplicaSet   ✔ Healthy   95s    canary,delay:28s
│  │  └──□ mock-server-7c6fcfb847-q78s6  Pod          ✔ Running   95s    ready:1/1
│  └──α mock-server-7c6fcfb847-2-2       AnalysisRun  ✖ Failed    61s    ✖ 3
└──# revision:1                                                          
   └──⧉ mock-server-6579c6cc98           ReplicaSet   ✔ Healthy   2m43s  stable
      ├──□ mock-server-6579c6cc98-n2w2t  Pod          ✔ Running   2m43s  ready:1/1
      ├──□ mock-server-6579c6cc98-2jpvc  Pod          ✔ Running   2m42s  ready:1/1
      ├──□ mock-server-6579c6cc98-jfhl5  Pod          ✔ Running   2m42s  ready:1/1
      ├──□ mock-server-6579c6cc98-knl9h  Pod          ✔ Running   2m42s  ready:1/1
      └──□ mock-server-6579c6cc98-lk7m9  Pod          ✔ Running   2m42s  ready:1/1

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 2: Metric "success-rate" assessed Failed due to failed (3) > failureLimit (2)
Strategy:        Canary
  Step:          0/4
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                     KIND         STATUS        AGE    INFO
⟳ mock-server                            Rollout      ✖ Degraded    3m25s  
├──# revision:2                                                            
│  ├──⧉ mock-server-7c6fcfb847           ReplicaSet   • ScaledDown  2m17s  canary,delay:passed
│  └──α mock-server-7c6fcfb847-2-2       AnalysisRun  ✖ Failed      103s   ✖ 3
└──# revision:1                                                            
   └──⧉ mock-server-6579c6cc98           ReplicaSet   ✔ Healthy     3m25s  stable
      ├──□ mock-server-6579c6cc98-n2w2t  Pod          ✔ Running     3m25s  ready:1/1
      ├──□ mock-server-6579c6cc98-2jpvc  Pod          ✔ Running     3m24s  ready:1/1
      ├──□ mock-server-6579c6cc98-jfhl5  Pod          ✔ Running     3m24s  ready:1/1
      ├──□ mock-server-6579c6cc98-knl9h  Pod          ✔ Running     3m24s  ready:1/1
      └──□ mock-server-6579c6cc98-lk7m9  Pod          ✔ Running     3m24s  ready:1/1

# Successful promotion
$ kubectl argo rollouts retry rollout mock-server
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          0/4
  SetWeight:     20
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         5
  Available:     5

NAME                                     KIND         STATUS         AGE    INFO
⟳ mock-server                            Rollout      ◌ Progressing  4m26s  
├──# revision:2                                                             
│  ├──⧉ mock-server-7c6fcfb847           ReplicaSet   ◌ Progressing  3m18s  canary
│  │  └──□ mock-server-7c6fcfb847-78sjh  Pod          ◌ Init:1/2     2s     ready:0/1
│  └──α mock-server-7c6fcfb847-2-2       AnalysisRun  ✖ Failed       2m44s  ✖ 3
└──# revision:1                                                             
   └──⧉ mock-server-6579c6cc98           ReplicaSet   ✔ Healthy      4m26s  stable
      ├──□ mock-server-6579c6cc98-n2w2t  Pod          ✔ Running      4m26s  ready:1/1
      ├──□ mock-server-6579c6cc98-2jpvc  Pod          ✔ Running      4m25s  ready:1/1
      ├──□ mock-server-6579c6cc98-jfhl5  Pod          ✔ Running      4m25s  ready:1/1
      ├──□ mock-server-6579c6cc98-knl9h  Pod          ✔ Running      4m25s  ready:1/1
      └──□ mock-server-6579c6cc98-lk7m9  Pod          ✔ Running      4m25s  ready:1/1

$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
...

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          4/4
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:2.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                     KIND         STATUS        AGE    INFO
⟳ mock-server                            Rollout      ✔ Healthy     6m56s  
├──# revision:2                                                            
│  ├──⧉ mock-server-7c6fcfb847           ReplicaSet   ✔ Healthy     5m48s  stable
│  │  ├──□ mock-server-7c6fcfb847-78sjh  Pod          ✔ Running     2m32s  ready:1/1
│  │  ├──□ mock-server-7c6fcfb847-dkxsv  Pod          ✔ Running     57s    ready:1/1
│  │  ├──□ mock-server-7c6fcfb847-j89fq  Pod          ✔ Running     57s    ready:1/1
│  │  ├──□ mock-server-7c6fcfb847-ljz98  Pod          ✔ Running     57s    ready:1/1
│  │  └──□ mock-server-7c6fcfb847-v5cdf  Pod          ✔ Running     57s    ready:1/1
│  ├──α mock-server-7c6fcfb847-2-2       AnalysisRun  ✖ Failed      5m14s  ✖ 3
│  └──α mock-server-7c6fcfb847-2-2.1     AnalysisRun  ✔ Successful  117s   ✔ 2,✖ 1
└──# revision:1                                                            
   └──⧉ mock-server-6579c6cc98           ReplicaSet   • ScaledDown  6m56s  
```

[Manifest 17] shows the Manifest for the Traffic Routing Test Case using Istio Destination Rule and AnalysisTemplate, and [Shell 9] shows the process of performing that Test Case.

#### 2.2.9. Canary with Istio Destination Rule, Analysis and Experiment

{{< figure caption="[Figure 10] Canary with Istio Destination Rule, AnalysisTemplate and Experiment Test Case" src="images/argo-rollouts-case-canary-istio-destinationrule-analysistemplate-experiment.png" width="1000px" >}}

[Figure 10] diagrams a Traffic Routing Test Case using Istio Destination Rule, AnalysisTemplate, and Experiment. Except for the part of using Destination Rule, it performs the same process as [Figure 7].

```yaml {caption="[Manifest 18] Canary with Istio Destination Rule, AnalysisTemplate and Experiment Test Case"}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server
spec:
  replicas: 5
  selector:
    matchLabels:
      app: mock-server
  strategy:
    canary:
      steps:
      - experiment:
          duration: 2m
          templates:
          - name: stable
            specRef: stable
            weight: 20
            service:
              name: mock-server-experiment-stable
          - name: canary
            specRef: canary
            weight: 20
            service:
              name: mock-server-experiment-canary
          analyses:
          - name: stable-canary-comparison
            templateName: stable-canary-comparison
            args:
            - name: stable-replicaset
              value: "{{templates.stable.replicaset.name}}"
            - name: canary-replicaset
              value: "{{templates.canary.replicaset.name}}"
      - setWeight: 20
      - pause: {duration: 30s}
      - analysis:
          templates:
          - templateName: success-rate
      - setWeight: 100
      trafficRouting:
        istio:
          virtualService:
            name: mock-server
            routes:
            - primary
          destinationRule:
            name: mock-server
            stableSubsetName: stable
            canarySubsetName: canary
  template:
    metadata:
      labels:
        app: mock-server
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "15020"
        prometheus.io/path: "/stats/prometheus"
    spec:
      containers:
      - name: mock-server
        image: ghcr.io/ssup2/mock-go-server:1.0.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server
spec:
  selector:
    app: mock-server
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mock-server
spec:
  hosts:
  - mock-server
  http:
  - name: primary
    route:
    - destination:
        host: mock-server
        subset: stable
      weight: 100
    - destination:
        host: mock-server
        subset: canary
      weight: 0
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: mock-server
spec:
  host: mock-server
  subsets:
  - name: stable
    labels:
      app: mock-server
  - name: canary
    labels:
      app: mock-server
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
  - name: success-rate
    interval: 30s
    count: 3
    successCondition: result >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.istio-system.svc.cluster.local:9090
        query: |
          scalar(
            sum(rate(istio_requests_total{destination_service_name="mock-server",response_code=~"2.."}[1m])) 
            / 
            sum(rate(istio_requests_total{destination_service_name="mock-server"}[1m]))
          )
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: stable-canary-comparison
spec:
  args:
  - name: stable-replicaset
  - name: canary-replicaset
  metrics:
  - name: stable-success-rate
    interval: 30s
    count: 3
    successCondition: result >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.istio-system.svc.cluster.local:9090
        query: |
          scalar(
            sum(rate(istio_requests_total{
              destination_service_name="mock-server-experiment-stable",
              destination_workload="{{args.stable-replicaset}}",
              response_code=~"2.."
            }[1m])) 
            / 
            sum(rate(istio_requests_total{
              destination_service_name="mock-server-experiment-stable,
              destination_workload="{{args.stable-replicaset}}"
            }[1m]))
          )
  - name: canary-success-rate
    interval: 30s
    count: 3
    successCondition: result >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.istio-system.svc.cluster.local:9090
        query: |
          scalar(
            sum(rate(istio_requests_total{
              destination_service_name="mock-server-experiment-canary",
              destination_workload="{{args.canary-replicaset}}",
              response_code=~"2.."
            }[1m])) 
            / 
            sum(rate(istio_requests_total{
              destination_service_name="mock-server-experiment-canary",
              destination_workload="{{args.canary-replicaset}}"
            }[1m]))
          )
```

```shell {caption="[Shell 10] Canary with Istio Destination Rule, AnalysisTemplate and Experiment Test Case"}
$ kubectl apply -f mock-server-canary-istio-destinationrule-analysistemplate-experiment.yaml
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                   KIND        STATUS     AGE  INFO
⟳ mock-server                          Rollout     ✔ Healthy  8s   
└──# revision:1                                                    
   └──⧉ mock-server-5f59cc96           ReplicaSet  ✔ Healthy  7s   stable
      ├──□ mock-server-5f59cc96-hqgw9  Pod         ✔ Running  7s   ready:1/1
      ├──□ mock-server-5f59cc96-jwgdb  Pod         ✔ Running  7s   ready:1/1
      ├──□ mock-server-5f59cc96-jwxt7  Pod         ✔ Running  7s   ready:1/1
      ├──□ mock-server-5f59cc96-mnfpn  Pod         ✔ Running  7s   ready:1/1
      └──□ mock-server-5f59cc96-tgcn9  Pod         ✔ Running  7s   ready:1/1

# Set mock-server image to 2.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:2.0.0
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          0/5
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, Σ:stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (Σ:canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                                            KIND         STATUS         AGE  INFO
⟳ mock-server                                                   Rollout      ◌ Progressing  30s  
├──# revision:2                                                                                  
│  ├──⧉ mock-server-789cf554d9                                  ReplicaSet   • ScaledDown   5s   canary
│  └──Σ mock-server-789cf554d9-2-0                              Experiment   ◌ Running      5s   
│     ├──⧉ mock-server-789cf554d9-2-0-canary                    ReplicaSet   ✔ Healthy      5s   
│     │  └──□ mock-server-789cf554d9-2-0-canary-w6tzc           Pod          ✔ Running      5s   ready:1/1
│     ├──⧉ mock-server-789cf554d9-2-0-stable                    ReplicaSet   ✔ Healthy      5s   
│     │  └──□ mock-server-789cf554d9-2-0-stable-bp8cv           Pod          ✔ Running      5s   ready:1/1
│     └──α mock-server-789cf554d9-2-0-stable-canary-comparison  AnalysisRun  ◌ Running      0s   ✖ 2
└──# revision:1                                                                                  
   └──⧉ mock-server-5f59cc96                                    ReplicaSet   ✔ Healthy      29s  stable
      ├──□ mock-server-5f59cc96-hqgw9                           Pod          ✔ Running      29s  ready:1/1
      ├──□ mock-server-5f59cc96-jwgdb                           Pod          ✔ Running      29s  ready:1/1
      ├──□ mock-server-5f59cc96-jwxt7                           Pod          ✔ Running      29s  ready:1/1
      ├──□ mock-server-5f59cc96-mnfpn                           Pod          ✔ Running      29s  ready:1/1
      └──□ mock-server-5f59cc96-tgcn9                           Pod          ✔ Running      29s  ready:1/1

$ kubectl describe virtualservice mock-server
...
Spec:
  Hosts:
    mock-server
  Http:
    Name:  primary
    Route:
      Destination:
        Host:    mock-server
        Subset:  stable
      Weight:    60
      Destination:
        Host:    mock-server
        Subset:  canary
      Weight:    0
      Destination:
        Host:  mock-server-experiment-stable
      Weight:  20
      Destination:
        Host:  mock-server-experiment-canary
      Weight:  20

$ kubectl describe destinationrule mock-server
...
Spec:
  Host:  mock-server
  Subsets:
    Labels:
      App:                               mock-server
      Rollouts - Pod - Template - Hash:  5f59cc96
    Name:                                stable
    Labels:
      App:                               mock-server
      Rollouts - Pod - Template - Hash:  789cf554d9
    Name:                                canary
    Labels:
      Rollouts - Pod - Template - Hash:  68879bfdd8
    Name:                                mock-server-experiment-stable
    Labels:
      Rollouts - Pod - Template - Hash:  65c7c65dd7
    Name:                                mock-server-experiment-canary

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 2: Metric "stable-success-rate" assessed Failed due to failed (3) > failureLimit (2)
Strategy:        Canary
  Step:          0/5
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                                            KIND         STATUS        AGE    INFO
⟳ mock-server                                                   Rollout      ✖ Degraded    2m27s  
├──# revision:2                                                                                   
│  ├──⧉ mock-server-789cf554d9                                  ReplicaSet   • ScaledDown  2m2s   canary,delay:passed
│  └──Σ mock-server-789cf554d9-2-0                              Experiment   ✖ Failed      2m2s   
│     ├──⧉ mock-server-789cf554d9-2-0-canary                    ReplicaSet   • ScaledDown  2m2s   delay:passed
│     ├──⧉ mock-server-789cf554d9-2-0-stable                    ReplicaSet   • ScaledDown  2m2s   delay:passed
│     └──α mock-server-789cf554d9-2-0-stable-canary-comparison  AnalysisRun  ✖ Failed      117s   ✖ 6
└──# revision:1                                                                                   
   └──⧉ mock-server-5f59cc96                                    ReplicaSet   ✔ Healthy     2m26s  stable
      ├──□ mock-server-5f59cc96-hqgw9                           Pod          ✔ Running     2m26s  ready:1/1
      ├──□ mock-server-5f59cc96-jwgdb                           Pod          ✔ Running     2m26s  ready:1/1
      ├──□ mock-server-5f59cc96-jwxt7                           Pod          ✔ Running     2m26s  ready:1/1
      ├──□ mock-server-5f59cc96-mnfpn                           Pod          ✔ Running     2m26s  ready:1/1
      └──□ mock-server-5f59cc96-tgcn9                           Pod          ✔ Running     2m26s  ready:1/1

# Retry mock-server rollout
$ kubectl argo rollouts retry rollout mock-server
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          0/5
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, Σ:stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (Σ:canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                                              KIND         STATUS         AGE    INFO
⟳ mock-server                                                     Rollout      ◌ Progressing  3m3s   
├──# revision:2                                                                                      
│  ├──⧉ mock-server-789cf554d9                                    ReplicaSet   • ScaledDown   2m38s  canary
│  ├──Σ mock-server-789cf554d9-2-0                                Experiment   ✖ Failed       2m38s  
│  │  ├──⧉ mock-server-789cf554d9-2-0-canary                      ReplicaSet   • ScaledDown   2m38s  delay:passed
│  │  ├──⧉ mock-server-789cf554d9-2-0-stable                      ReplicaSet   • ScaledDown   2m38s  delay:passed
│  │  └──α mock-server-789cf554d9-2-0-stable-canary-comparison    AnalysisRun  ✖ Failed       2m33s  ✖ 6
│  └──Σ mock-server-789cf554d9-2-0-1                              Experiment   ◌ Running      7s     
│     ├──⧉ mock-server-789cf554d9-2-0-1-canary                    ReplicaSet   ✔ Healthy      7s     
│     │  └──□ mock-server-789cf554d9-2-0-1-canary-2m4l8           Pod          ✔ Running      7s     ready:1/1
│     ├──⧉ mock-server-789cf554d9-2-0-1-stable                    ReplicaSet   ✔ Healthy      7s     
│     │  └──□ mock-server-789cf554d9-2-0-1-stable-bw87g           Pod          ✔ Running      7s     ready:1/1
│     └──α mock-server-789cf554d9-2-0-1-stable-canary-comparison  AnalysisRun  ◌ Running      3s     ✖ 2
└──# revision:1                                                                                      
   └──⧉ mock-server-5f59cc96                                      ReplicaSet   ✔ Healthy      3m2s   stable
      ├──□ mock-server-5f59cc96-hqgw9                             Pod          ✔ Running      3m2s   ready:1/1
      ├──□ mock-server-5f59cc96-jwgdb                             Pod          ✔ Running      3m2s   ready:1/1
      ├──□ mock-server-5f59cc96-jwxt7                             Pod          ✔ Running      3m2s   ready:1/1
      ├──□ mock-server-5f59cc96-mnfpn                             Pod          ✔ Running      3m2s   ready:1/1
      └──□ mock-server-5f59cc96-tgcn9                             Pod          ✔ Running      3m2s   ready:1/1

$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
...

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          0/5
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, Σ:stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (Σ:canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                                              KIND         STATUS         AGE    INFO
⟳ mock-server                                                     Rollout      ◌ Progressing  4m4s   
├──# revision:2                                                                                      
│  ├──⧉ mock-server-789cf554d9                                    ReplicaSet   • ScaledDown   3m39s  canary
│  ├──Σ mock-server-789cf554d9-2-0                                Experiment   ✖ Failed       3m39s  
│  │  ├──⧉ mock-server-789cf554d9-2-0-canary                      ReplicaSet   • ScaledDown   3m39s  delay:passed
│  │  ├──⧉ mock-server-789cf554d9-2-0-stable                      ReplicaSet   • ScaledDown   3m39s  delay:passed
│  │  └──α mock-server-789cf554d9-2-0-stable-canary-comparison    AnalysisRun  ✖ Failed       3m34s  ✖ 6
│  └──Σ mock-server-789cf554d9-2-0-1                              Experiment   ◌ Running      68s    
│     ├──⧉ mock-server-789cf554d9-2-0-1-canary                    ReplicaSet   ✔ Healthy      68s    
│     │  └──□ mock-server-789cf554d9-2-0-1-canary-2m4l8           Pod          ✔ Running      68s    ready:1/1
│     ├──⧉ mock-server-789cf554d9-2-0-1-stable                    ReplicaSet   ✔ Healthy      68s    
│     │  └──□ mock-server-789cf554d9-2-0-1-stable-bw87g           Pod          ✔ Running      68s    ready:1/1
│     └──α mock-server-789cf554d9-2-0-1-stable-canary-comparison  AnalysisRun  ✔ Successful   64s    ✔ 2,✖ 4
└──# revision:1                                                                                      
   └──⧉ mock-server-5f59cc96                                      ReplicaSet   ✔ Healthy      4m3s   stable
      ├──□ mock-server-5f59cc96-hqgw9                             Pod          ✔ Running      4m3s   ready:1/1
      ├──□ mock-server-5f59cc96-jwgdb                             Pod          ✔ Running      4m3s   ready:1/1
      ├──□ mock-server-5f59cc96-jwxt7                             Pod          ✔ Running      4m3s   ready:1/1
      ├──□ mock-server-5f59cc96-mnfpn                             Pod          ✔ Running      4m3s   ready:1/1
      └──□ mock-server-5f59cc96-tgcn9                             Pod          ✔ Running      4m3s   ready:1/1 

# Continue mock-server rollout
$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          2/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, Σ:stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary, Σ:canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                                              KIND         STATUS        AGE    INFO
⟳ mock-server                                                     Rollout      ॥ Paused      5m11s  
├──# revision:2                                                                                     
│  ├──⧉ mock-server-789cf554d9                                    ReplicaSet   ✔ Healthy     4m46s  canary
│  │  └──□ mock-server-789cf554d9-dwwxh                           Pod          ✔ Running     11s    ready:1/1
│  ├──Σ mock-server-789cf554d9-2-0                                Experiment   ✖ Failed      4m46s  
│  │  ├──⧉ mock-server-789cf554d9-2-0-canary                      ReplicaSet   • ScaledDown  4m46s  delay:passed
│  │  ├──⧉ mock-server-789cf554d9-2-0-stable                      ReplicaSet   • ScaledDown  4m46s  delay:passed
│  │  └──α mock-server-789cf554d9-2-0-stable-canary-comparison    AnalysisRun  ✖ Failed      4m41s  ✖ 6
│  └──Σ mock-server-789cf554d9-2-0-1                              Experiment   ✔ Successful  2m15s  
│     ├──⧉ mock-server-789cf554d9-2-0-1-canary                    ReplicaSet   ✔ Healthy     2m15s  delay:18s
│     │  └──□ mock-server-789cf554d9-2-0-1-canary-2m4l8           Pod          ✔ Running     2m15s  ready:1/1
│     ├──⧉ mock-server-789cf554d9-2-0-1-stable                    ReplicaSet   ✔ Healthy     2m15s  delay:18s
│     │  └──□ mock-server-789cf554d9-2-0-1-stable-bw87g           Pod          ✔ Running     2m15s  ready:1/1
│     └──α mock-server-789cf554d9-2-0-1-stable-canary-comparison  AnalysisRun  ✔ Successful  2m11s  ✔ 2,✖ 4
└──# revision:1                                                                                     
   └──⧉ mock-server-5f59cc96                                      ReplicaSet   ✔ Healthy     5m10s  stable
      ├──□ mock-server-5f59cc96-hqgw9                             Pod          ✔ Running     5m10s  ready:1/1
      ├──□ mock-server-5f59cc96-jwgdb                             Pod          ✔ Running     5m10s  ready:1/1
      ├──□ mock-server-5f59cc96-jwxt7                             Pod          ✔ Running     5m10s  ready:1/1
      ├──□ mock-server-5f59cc96-mnfpn                             Pod          ✔ Running     5m10s  ready:1/1
      └──□ mock-server-5f59cc96-tgcn9                             Pod          ✔ Running     5m10s  ready:1/1

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          3/5
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         6
  Available:     6

NAME                                                              KIND         STATUS         AGE    INFO
⟳ mock-server                                                     Rollout      ◌ Progressing  5m41s  
├──# revision:2                                                                                      
│  ├──⧉ mock-server-789cf554d9                                    ReplicaSet   ✔ Healthy      5m16s  canary
│  │  └──□ mock-server-789cf554d9-dwwxh                           Pod          ✔ Running      41s    ready:1/1
│  ├──Σ mock-server-789cf554d9-2-0                                Experiment   ✖ Failed       5m16s  
│  │  ├──⧉ mock-server-789cf554d9-2-0-canary                      ReplicaSet   • ScaledDown   5m16s  delay:passed
│  │  ├──⧉ mock-server-789cf554d9-2-0-stable                      ReplicaSet   • ScaledDown   5m16s  delay:passed
│  │  └──α mock-server-789cf554d9-2-0-stable-canary-comparison    AnalysisRun  ✖ Failed       5m11s  ✖ 6
│  ├──Σ mock-server-789cf554d9-2-0-1                              Experiment   ✔ Successful   2m45s  
│  │  ├──⧉ mock-server-789cf554d9-2-0-1-canary                    ReplicaSet   • ScaledDown   2m45s  delay:passed
│  │  ├──⧉ mock-server-789cf554d9-2-0-1-stable                    ReplicaSet   • ScaledDown   2m45s  delay:passed
│  │  └──α mock-server-789cf554d9-2-0-1-stable-canary-comparison  AnalysisRun  ✔ Successful   2m41s  ✔ 2,✖ 4
│  └──α mock-server-789cf554d9-2-3                                AnalysisRun  ◌ Running      7s     ✖ 1
└──# revision:1                                                                                      
   └──⧉ mock-server-5f59cc96                                      ReplicaSet   ✔ Healthy      5m40s  stable
      ├──□ mock-server-5f59cc96-hqgw9                             Pod          ✔ Running      5m40s  ready:1/1
      ├──□ mock-server-5f59cc96-jwgdb                             Pod          ✔ Running      5m40s  ready:1/1
      ├──□ mock-server-5f59cc96-jwxt7                             Pod          ✔ Running      5m40s  ready:1/1
      ├──□ mock-server-5f59cc96-mnfpn                             Pod          ✔ Running      5m40s  ready:1/1
      └──□ mock-server-5f59cc96-tgcn9                             Pod          ✔ Running      5m40s  ready:1/1
```

[Manifest 18] shows the Manifest for the Traffic Routing Test Case using Istio Destination Rule, AnalysisTemplate, and Experiment, and [Shell 10] shows the process of performing that Test Case.

## 3. References

* Argo Rollouts : [https://ojt90902.tistory.com/1596](https://ojt90902.tistory.com/1596)
* Argo Rollouts : [https://kkamji.net/posts/argo-rollout-5w/](https://kkamji.net/posts/argo-rollout-5w/)
* Netflix Kayenta : [https://netflixtechblog.com/automated-canary-analysis-at-netflix-with-kayenta-3260bc7acc69](https://netflixtechblog.com/automated-canary-analysis-at-netflix-with-kayenta-3260bc7acc69)