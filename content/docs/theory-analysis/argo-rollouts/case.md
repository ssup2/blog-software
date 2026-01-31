#### 2.2.7. Canary with istio Destination Rule, Analysis and Experiment

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
          - name: baseline
            specRef: stable
            weight: 20
          - name: canary
            specRef: canary
            weight: 20
          analyses:
          - name: baseline-canary-comparison
            templateName: baseline-canary-comparison
            args:
            - name: baseline-hash
              value: "{{templates.baseline.podTemplateHash}}"
            - name: canary-hash
              value: "{{templates.canary.podTemplateHash}}"
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
  name: baseline-canary-comparison
spec:
  args:
  - name: baseline-hash
  - name: canary-hash
  metrics:
  - name: baseline-success-rate
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
              destination_service_name="mock-server-canary",
              destination_workload=~"mock-server-{{args.baseline-hash}}.*",
              response_code=~"2.."
            }[1m])) 
            / 
            sum(rate(istio_requests_total{
              destination_service_name="mock-server-canary",
              destination_workload=~"mock-server-{{args.baseline-hash}}.*"
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
              destination_service_name="mock-server-canary",
              destination_workload=~"mock-server-{{args.canary-hash}}.*",
              response_code=~"2.."
            }[1m])) 
            / 
            sum(rate(istio_requests_total{
              destination_service_name="mock-server-canary",
              destination_workload=~"mock-server-{{args.canary-hash}}.*"
            }[1m]))
          )
```

```shell
# Deploy mock-server canary rollout and check status
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
⟳ mock-server                          Rollout     ✔ Healthy  5s   
└──# revision:1                                                    
   └──⧉ mock-server-5f59cc96           ReplicaSet  ✔ Healthy  5s   stable
      ├──□ mock-server-5f59cc96-57d6k  Pod         ✔ Running  5s   ready:1/1
      ├──□ mock-server-5f59cc96-j2lgm  Pod         ✔ Running  5s   ready:1/1
      ├──□ mock-server-5f59cc96-rgq9x  Pod         ✔ Running  5s   ready:1/1
      ├──□ mock-server-5f59cc96-rl58z  Pod         ✔ Running  5s   ready:1/1
      └──□ mock-server-5f59cc96-v6q9w  Pod         ✔ Running  5s   ready:1/1

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
      Rollouts - Pod - Template - Hash:  5f59cc96
    Name:                                stable
    Labels:
      App:                               mock-server
      Rollouts - Pod - Template - Hash:  5f59cc96
    Name:                                canary

# Set mock-server image to 2.0.0 and check status
$ kubectl argo rollouts set image mock-server mock-server=ghcr.io/ssup2/mock-go-server:2.0.0
$ kubectl argo rollouts get rollout mock-server
kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          0/5
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, Σ:baseline)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (Σ:canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                                              KIND         STATUS         AGE  INFO
⟳ mock-server                                                     Rollout      ◌ Progressing  90s  
├──# revision:2                                                                                    
│  ├──⧉ mock-server-789cf554d9                                    ReplicaSet   • ScaledDown   53s  canary
│  └──Σ mock-server-789cf554d9-2-0                                Experiment   ◌ Running      53s  
│     ├──⧉ mock-server-789cf554d9-2-0-baseline                    ReplicaSet   ✔ Healthy      53s  
│     │  └──□ mock-server-789cf554d9-2-0-baseline-6sb8f           Pod          ✔ Running      53s  ready:1/1
│     ├──⧉ mock-server-789cf554d9-2-0-canary                      ReplicaSet   ✔ Healthy      53s  
│     │  └──□ mock-server-789cf554d9-2-0-canary-b7vzq             Pod          ✔ Running      53s  ready:1/1
│     └──α mock-server-789cf554d9-2-0-baseline-canary-comparison  AnalysisRun  ◌ Running      48s  ✖ 4
└──# revision:1                                                                                    
   └──⧉ mock-server-5f59cc96                                      ReplicaSet   ✔ Healthy      90s  stable
      ├──□ mock-server-5f59cc96-57d6k                             Pod          ✔ Running      90s  ready:1/1
      ├──□ mock-server-5f59cc96-j2lgm                             Pod          ✔ Running      90s  ready:1/1
      ├──□ mock-server-5f59cc96-rgq9x                             Pod          ✔ Running      90s  ready:1/1
      ├──□ mock-server-5f59cc96-rl58z                             Pod          ✔ Running      90s  ready:1/1
      └──□ mock-server-5f59cc96-v6q9w                             Pod          ✔ Running      90s  ready:1/1

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
        Host:  mock-server-789cf554d9-2-0-baseline
      Weight:  20
      Destination:
        Host:  mock-server-789cf554d9-2-0-canary
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
    Name:                                mock-server-789cf554d9-2-0-baseline
    Labels:
      Rollouts - Pod - Template - Hash:  65c7c65dd7
    Name:                                mock-server-789cf554d9-2-0-canary

$ kubectl argo rollouts get rollout mock-server
Name:            mock-server
Namespace:       default
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 2: Metric "baseline-success-rate" assessed Failed due to failed (3) > failureLimit (2)
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

NAME                                                              KIND         STATUS        AGE    INFO
⟳ mock-server                                                     Rollout      ✖ Degraded    2m15s  
├──# revision:2                                                                                     
│  ├──⧉ mock-server-789cf554d9                                    ReplicaSet   • ScaledDown  98s    canary,delay:passed
│  └──Σ mock-server-789cf554d9-2-0                                Experiment   ✖ Failed      98s    
│     ├──⧉ mock-server-789cf554d9-2-0-baseline                    ReplicaSet   • ScaledDown  98s    delay:passed
│     ├──⧉ mock-server-789cf554d9-2-0-canary                      ReplicaSet   • ScaledDown  98s    delay:passed
│     └──α mock-server-789cf554d9-2-0-baseline-canary-comparison  AnalysisRun  ✖ Failed      93s    ✖ 6
└──# revision:1                                                                                     
   └──⧉ mock-server-5f59cc96                                      ReplicaSet   ✔ Healthy     2m15s  stable
      ├──□ mock-server-5f59cc96-57d6k                             Pod          ✔ Running     2m15s  ready:1/1
      ├──□ mock-server-5f59cc96-j2lgm                             Pod          ✔ Running     2m15s  ready:1/1
      ├──□ mock-server-5f59cc96-rgq9x                             Pod          ✔ Running     2m15s  ready:1/1
      ├──□ mock-server-5f59cc96-rl58z                             Pod          ✔ Running     2m15s  ready:1/1
      └──□ mock-server-5f59cc96-v6q9w                             Pod          ✔ Running     2m15s  ready:1/1

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
Images:          ghcr.io/ssup2/mock-go-server:1.0.0 (stable, Σ:baseline)
                 ghcr.io/ssup2/mock-go-server:2.0.0 (Σ:canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5

NAME                                                                KIND         STATUS         AGE    INFO
⟳ mock-server                                                       Rollout      ◌ Progressing  2m46s  
├──# revision:2                                                                                        
│  ├──⧉ mock-server-789cf554d9                                      ReplicaSet   • ScaledDown   2m9s   canary
│  ├──Σ mock-server-789cf554d9-2-0                                  Experiment   ✖ Failed       2m9s   
│  │  ├──⧉ mock-server-789cf554d9-2-0-baseline                      ReplicaSet   • ScaledDown   2m9s   delay:passed
│  │  ├──⧉ mock-server-789cf554d9-2-0-canary                        ReplicaSet   • ScaledDown   2m9s   delay:passed
│  │  └──α mock-server-789cf554d9-2-0-baseline-canary-comparison    AnalysisRun  ✖ Failed       2m4s   ✖ 6
│  └──Σ mock-server-789cf554d9-2-0-1                                Experiment   ◌ Running      4s     
│     ├──⧉ mock-server-789cf554d9-2-0-1-baseline                    ReplicaSet   ✔ Healthy      4s     
│     │  └──□ mock-server-789cf554d9-2-0-1-baseline-gf8hq           Pod          ✔ Running      4s     ready:1/1
│     ├──⧉ mock-server-789cf554d9-2-0-1-canary                      ReplicaSet   ✔ Healthy      4s     
│     │  └──□ mock-server-789cf554d9-2-0-1-canary-xq9c6             Pod          ✔ Running      4s     ready:1/1
│     └──α mock-server-789cf554d9-2-0-1-baseline-canary-comparison  AnalysisRun  ◌ Running      0s     ✖ 2
└──# revision:1                                                                                        
   └──⧉ mock-server-5f59cc96                                        ReplicaSet   ✔ Healthy      2m46s  stable
      ├──□ mock-server-5f59cc96-57d6k                               Pod          ✔ Running      2m46s  ready:1/1
      ├──□ mock-server-5f59cc96-j2lgm                               Pod          ✔ Running      2m46s  ready:1/1
      ├──□ mock-server-5f59cc96-rgq9x                               Pod          ✔ Running      2m46s  ready:1/1
      ├──□ mock-server-5f59cc96-rl58z                               Pod          ✔ Running      2m46s  ready:1/1
      └──□ mock-server-5f59cc96-v6q9w                               Pod          ✔ Running      2m46s  ready:1/1

$ kubectl exec -it shell -- curl -s mock-server:80/status/200
```