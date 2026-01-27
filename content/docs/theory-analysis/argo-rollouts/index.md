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
  - port: 80
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
  - port: 80
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
  - port: 80
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
  - port: 80
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
  - port: 80
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

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98

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

$ kubectl describe service mock-server-canary
Name:                     mock-server
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=7c6fcfb847

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

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b

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

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b

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

$ kubectl describe service mock-server-canary
Name:                     mock-server-canary
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b
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
  - port: 80
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
  - port: 80
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
  - port: 80
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
  - port: 80
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
  - port: 80
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
        port:
          number: 80
      weight: 100
    - destination:
        host: mock-server-canary
        port:
          number: 80
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
        Port:
          Number:  80
      Weight:      100
      Destination:
        Host:  mock-server-canary
        Port:
          Number:  80
      Weight:      0

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
        Port:
          Number:  80
      Weight:      80
      Destination:
        Host:  mock-server-canary
        Port:
          Number:  80
      Weight:      20

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
        Port:
          Number:  80
      Weight:      60
      Destination:
        Host:  mock-server-canary
        Port:
          Number:  80
      Weight:      40

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
        Port:
          Number:  80
      Weight:      100
      Destination:
        Host:  mock-server-canary
        Port:
          Number:  80
      Weight:      0
```

#### 2.2.5. Canary with istio Destination Rule

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
  - port: 80
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
      Weight:    100
      Destination:
        Host:    mock-server
        Subset:  canary
      Weight:    0

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
      Weight:    80
      Destination:
        Host:    mock-server
        Subset:  canary
      Weight:    20

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
      Weight:    60
      Destination:
        Host:    mock-server
        Subset:  canary
      Weight:    40

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
      Weight:    100
      Destination:
        Host:    mock-server
        Subset:  canary
      Weight:    0

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

#### 2.2.6. Canary with istio Destination Rule and Tem

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
  - port: 80
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
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus.istio-system.svc.cluster.local:9090
        query: |
          sum(rate(istio_requests_total{destination_service_name="mock-server",response_code=~"2.."}[1m])) 
          / 
          sum(rate(istio_requests_total{destination_service_name="mock-server"}[1m]))
```

```shell
# Deploy mock-server canary rollout and check status
$ kubectl apply -f mock-server-canary-istio-destinationrule-analysistemplate.yaml
$ kubectl argo rollouts get rollout mock-server

```

## 3. 참조

* Argo Rollouts : [https://kkamji.net/posts/argo-rollout-5w/](https://kkamji.net/posts/argo-rollout-5w/)