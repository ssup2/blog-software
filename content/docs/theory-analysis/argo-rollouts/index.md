---
title: Argo Rollouts
draft: true
---

## 1. Argo Rollouts

### 1.1. Test 환경 구성

```yaml
```

### 1.2. Test Case

#### 1.2.1. Blue/Green

```yaml {caption="[File 1] Argo Rollouts Blue/Green Example", linenos=table}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mock-server-bluegreen
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
$ kubectl apply -f mock-server-bluegreen.yaml
$ kubectl argo rollouts get rollout mock-server-bluegreen
Name:            mock-server-bluegreen
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

NAME                                               KIND        STATUS     AGE  INFO
⟳ mock-server-bluegreen                            Rollout     ✔ Healthy  15s  
└──# revision:1                                                                
   └──⧉ mock-server-bluegreen-6579c6cc98           ReplicaSet  ✔ Healthy  15s  stable,active
      ├──□ mock-server-bluegreen-6579c6cc98-76zf2  Pod         ✔ Running  15s  ready:1/1
      ├──□ mock-server-bluegreen-6579c6cc98-7bwhd  Pod         ✔ Running  15s  ready:1/1
      ├──□ mock-server-bluegreen-6579c6cc98-khls8  Pod         ✔ Running  15s  ready:1/1
      ├──□ mock-server-bluegreen-6579c6cc98-pwdf9  Pod         ✔ Running  15s  ready:1/1
      └──□ mock-server-bluegreen-6579c6cc98-qj7qx  Pod         ✔ Running  15s  ready:1/1

$ kubectl describe service mock-server-active
Name:                     mock-server-active
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server-bluegreen
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-preview
Name:                     mock-server-preview
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server-bluegreen
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

# Set mock-server image to 2.0.0 and check status
$ kubectl argo rollouts set image mock-server-bluegreen mock-server=ghcr.io/ssup2/mock-go-server:2.0.0
$ kubectl argo rollouts get rollout mock-server-bluegreen
Name:            mock-server-bluegreen
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

NAME                                               KIND        STATUS     AGE  INFO
⟳ mock-server-bluegreen                            Rollout     ॥ Paused   72s  
├──# revision:2                                                                
│  └──⧉ mock-server-bluegreen-7c6fcfb847           ReplicaSet  ✔ Healthy  6s   preview
│     ├──□ mock-server-bluegreen-7c6fcfb847-cdws6  Pod         ✔ Running  6s   ready:1/1
│     ├──□ mock-server-bluegreen-7c6fcfb847-gmq45  Pod         ✔ Running  6s   ready:1/1
│     ├──□ mock-server-bluegreen-7c6fcfb847-gzvk5  Pod         ✔ Running  6s   ready:1/1
│     ├──□ mock-server-bluegreen-7c6fcfb847-vcfw4  Pod         ✔ Running  6s   ready:1/1
│     └──□ mock-server-bluegreen-7c6fcfb847-zr7zd  Pod         ✔ Running  6s   ready:1/1
└──# revision:1                                                                
   └──⧉ mock-server-bluegreen-6579c6cc98           ReplicaSet  ✔ Healthy  72s  stable,active
      ├──□ mock-server-bluegreen-6579c6cc98-76zf2  Pod         ✔ Running  72s  ready:1/1
      ├──□ mock-server-bluegreen-6579c6cc98-7bwhd  Pod         ✔ Running  72s  ready:1/1
      ├──□ mock-server-bluegreen-6579c6cc98-khls8  Pod         ✔ Running  72s  ready:1/1
      ├──□ mock-server-bluegreen-6579c6cc98-pwdf9  Pod         ✔ Running  72s  ready:1/1
      └──□ mock-server-bluegreen-6579c6cc98-qj7qx  Pod         ✔ Running  72s  ready:1/1

$ kubectl describe service mock-server-active
Name:                     mock-server-active
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server-bluegreen
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-preview
Name:                     mock-server-preview
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server-bluegreen
Selector:                 app=mock-server,rollouts-pod-template-hash=7c6fcfb847
...


$ kubectl argo rollouts set image mock-server-bluegreen mock-server=ghcr.io/ssup2/mock-go-server:3.0.0
$ kubectl argo rollouts get rollout mock-server-bluegreen
Name:            mock-server-bluegreen
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

NAME                                               KIND        STATUS        AGE    INFO
⟳ mock-server-bluegreen                            Rollout     ॥ Paused      2m52s  
├──# revision:3                                                                     
│  └──⧉ mock-server-bluegreen-6fcb56df9b           ReplicaSet  ✔ Healthy     40s    preview
│     ├──□ mock-server-bluegreen-6fcb56df9b-9ws9k  Pod         ✔ Running     39s    ready:1/1
│     ├──□ mock-server-bluegreen-6fcb56df9b-sznrj  Pod         ✔ Running     39s    ready:1/1
│     ├──□ mock-server-bluegreen-6fcb56df9b-t7mxx  Pod         ✔ Running     39s    ready:1/1
│     ├──□ mock-server-bluegreen-6fcb56df9b-x7v48  Pod         ✔ Running     39s    ready:1/1
│     └──□ mock-server-bluegreen-6fcb56df9b-xclfh  Pod         ✔ Running     39s    ready:1/1
├──# revision:2                                                                     
│  └──⧉ mock-server-bluegreen-7c6fcfb847           ReplicaSet  • ScaledDown  106s   
└──# revision:1                                                                     
   └──⧉ mock-server-bluegreen-6579c6cc98           ReplicaSet  ✔ Healthy     2m52s  stable,active
      ├──□ mock-server-bluegreen-6579c6cc98-76zf2  Pod         ✔ Running     2m52s  ready:1/1
      ├──□ mock-server-bluegreen-6579c6cc98-7bwhd  Pod         ✔ Running     2m52s  ready:1/1
      ├──□ mock-server-bluegreen-6579c6cc98-khls8  Pod         ✔ Running     2m52s  ready:1/1
      ├──□ mock-server-bluegreen-6579c6cc98-pwdf9  Pod         ✔ Running     2m52s  ready:1/1
      └──□ mock-server-bluegreen-6579c6cc98-qj7qx  Pod         ✔ Running     2m52s  ready:1/1

$ kubectl describe service mock-server-active
Name:                     mock-server-active
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server-bluegreen
Selector:                 app=mock-server,rollouts-pod-template-hash=6579c6cc98
...

$ kubectl describe service mock-server-preview
Name:                     mock-server-preview
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server-bluegreen
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b

# Promote mock-server-bluegreen rollout
$ kubectl argo rollouts promote mock-server-bluegreen
$ kubectl argo rollouts get rollout mock-server-bluegreen
Name:            mock-server-bluegreen
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

NAME                                               KIND        STATUS        AGE   INFO
⟳ mock-server-bluegreen                            Rollout     ✔ Healthy     4m7s  
├──# revision:3                                                                    
│  └──⧉ mock-server-bluegreen-6fcb56df9b           ReplicaSet  ✔ Healthy     115s  stable,active
│     ├──□ mock-server-bluegreen-6fcb56df9b-9ws9k  Pod         ✔ Running     114s  ready:1/1
│     ├──□ mock-server-bluegreen-6fcb56df9b-sznrj  Pod         ✔ Running     114s  ready:1/1
│     ├──□ mock-server-bluegreen-6fcb56df9b-t7mxx  Pod         ✔ Running     114s  ready:1/1
│     ├──□ mock-server-bluegreen-6fcb56df9b-x7v48  Pod         ✔ Running     114s  ready:1/1
│     └──□ mock-server-bluegreen-6fcb56df9b-xclfh  Pod         ✔ Running     114s  ready:1/1
├──# revision:2                                                                    
│  └──⧉ mock-server-bluegreen-7c6fcfb847           ReplicaSet  • ScaledDown  3m1s  
└──# revision:1                                                                    
   └──⧉ mock-server-bluegreen-6579c6cc98           ReplicaSet  • ScaledDown  4m7s  

$ kubectl describe service mock-server-active
Name:                     mock-server-active
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server-bluegreen
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b

$ kubectl describe service mock-server-preview 
Name:                     mock-server-preview
Namespace:                default
Labels:                   <none>
Annotations:              argo-rollouts.argoproj.io/managed-by-rollouts: mock-server-bluegreen
Selector:                 app=mock-server,rollouts-pod-template-hash=6fcb56df9b
```

#### 1.2.2. Canary

#### 1.2.3. Canary with istio Traffic Routing

#### 1.2.4. Canary with istio Traffic Routing

## 2. 참조

* Argo Rollouts : [https://kkamji.net/posts/argo-rollout-5w/](https://kkamji.net/posts/argo-rollout-5w/)