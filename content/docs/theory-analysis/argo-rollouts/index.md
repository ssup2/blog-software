---
title: Argo Rollouts
draft: true
---

## 1. Argo Rollouts

## 2. Argo Rollout Cases

### 2.1. Test 환경 구성

```shell {caption="[Shell 1] Test 환경 구성"}
# Create kubernetes cluster with kind
$ kind create cluster --config=- <<EOF                           
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Install istio
$ istioctl install --set profile=demo -y

# Enable sidecar injection to default namespace
$ kubectl label namespace default istio-injection=enabled

# Install argo rollouts
$ kubectl create namespace argo-rollouts
$ kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install prometheus
$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/prometheus.yaml
```

[Shell 1]은 Test 환경을 구성하는 Script를 나타내고 있다. `kind`를 활용하여 Kubernetes Cluster를 구성하고 Istio를 설치한다. 그리고 default Namespace에 Sidecar Injection을 활성화한다. Argo Rollouts를 설치한다. 그리고 Prometheus를 설치한다.

```yaml {caption="[File 1] shell Pod Manifest", linenos=table}
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

[File 1]은 `shell` Pod의 Manifest를 나타내고 있다. netshoot Image를 이용하여 `shell` Pod을 생성하며, Argo Rollout으로 구성한 Service에 접근하여 istio Metric을 발생시키기 위해서 사용한다.

### 2.2. Test Cases

#### 2.2.1. Blue/Green

```yaml {caption="[File 1] Argo Rollouts Blue/Green Example", linenos=table}
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

```shell
# Deploy mock-server blue/green rollout and check status
$ kubectl apply -f mock-server.yaml
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

#### 2.2.2. Canary Success

```yaml {caption="[File 2] Argo Rollouts Canary Example", linenos=table}
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

```shell
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

#### 2.2.3. Canary with Undo and Abort

```yaml {caption="[File 2] Argo Rollouts Canary Example", linenos=table}
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

```shell
# Deploy mock-server canary rollout and check status
$ kubectl apply -f mock-server-canary-rollback.yaml
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

#### 2.2.4. Canary with istio Virtual Service

```yaml {caption="[File 3] Argo Rollouts Canary with istio Virtual Service Example", linenos=table}
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

```shell
# Deploy mock-server canary rollout and check status
$ kubectl apply -f mock-server-istio-virtualservice.yaml
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
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=7c6fcfb847
...
```

#### 2.2.5. Canary with istio Virtual Service and Analysis

```yaml {caption="[File 4] Argo Rollouts Canary with istio Virtual Service and Analysis Example", linenos=table}
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

```shell
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

#### 2.2.6. Canary with istio Virtual Service, Analysis and Experiment

```yaml {caption="[File 4] Argo Rollouts Canary with istio Virtual Service, Analysis and Experiment Example", linenos=table}
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

```shell
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

#### 2.2.7. Canary with istio Destination Rule

```yaml {caption="[File 4] Argo Rollouts Canary with istio Destination Rule Example", linenos=table}
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

```shell
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

#### 2.2.8. Canary with istio Destination Rule and Analysis

```yaml {caption="[File 4] Argo Rollouts Canary with istio Destination Rule Example", linenos=table}
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

```shell
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

#### 2.2.9. Canary with istio Destination Rule, Analysis and Experiment

```yaml {caption="[File 5] Argo Rollouts Canary with istio Destination Rule, Analysis and Experiment Example", linenos=table}
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

```shell
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

## 3. 참조

* Argo Rollouts : [https://ojt90902.tistory.com/1596](https://ojt90902.tistory.com/1596)
* Argo Rollouts : [https://kkamji.net/posts/argo-rollout-5w/](https://kkamji.net/posts/argo-rollout-5w/)