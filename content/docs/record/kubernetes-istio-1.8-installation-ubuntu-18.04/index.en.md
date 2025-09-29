---
title: Kubernetes istio 1.8 Installation / Ubuntu 18.04 Environment
---

## 1. Installation Environment

The installation environment is as follows:
* Kubernetes 1.18.3
  * Network Addon : Using cilium
* istio 1.8.1

## 2. istio Installation

```shell
$ curl -L https://istio.io/downloadIstio | sh -
$ cd istio-1.8.1
```

Download istio.

```shell
$ export PATH=$PWD/bin:$PATH
```

Configure istioctl.

```shell
$ istioctl install --set profile=demo -y

$ kubectl -n istio-system get pod
NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-6f9f4ddc9c-2qggk    1/1     Running   0          16m
istio-ingressgateway-78b47bc88b-lvxj2   1/1     Running   0          16m
istiod-67dbfcd4dd-b2dtc                 1/1     Running   0          16m

$ kubectl -n istio-system get service
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)                                                                      AGE
istio-egressgateway    ClusterIP      10.110.33.89    <none>         80/TCP,443/TCP,15443/TCP                                                     16m
istio-ingressgateway   LoadBalancer   10.109.246.4    192.168.0.82   15021:31021/TCP,80:31546/TCP,443:30724/TCP,31400:31073/TCP,15443:30737/TCP   16m
istiod                 ClusterIP      10.105.57.203   <none>         15010/TCP,15012/TCP,443/TCP,15014/TCP                                        16m
```

Install istio and verify operation.

```shell
$ kubectl apply -f samples/addons
$ kubectl apply -f samples/addons

$ kubectl -n istio-system get pod
NAME                                    READY   STATUS    RESTARTS   AGE
grafana-7b4b8c4c8c-2qggk               1/1     Running   0          16m
istio-egressgateway-6f9f4ddc9c-2qggk    1/1     Running   0          16m
istio-ingressgateway-78b47bc88b-lvxj2   1/1     Running   0          16m
istiod-67dbfcd4dd-b2dtc                 1/1     Running   0          16m
jaeger-7b4b8c4c8c-2qggk                1/1     Running   0          16m
kiali-7b4b8c4c8c-2qggk                  1/1     Running   0          16m
prometheus-7b4b8c4c8c-2qggk            1/1     Running   0          16m
```

Install istio addons and verify operation.

## 3. References

* istio Installation : [https://istio.io/latest/docs/setup/getting-started/](https://istio.io/latest/docs/setup/getting-started/)
* istio Addons : [https://istio.io/latest/docs/ops/integrations/](https://istio.io/latest/docs/ops/integrations/)
