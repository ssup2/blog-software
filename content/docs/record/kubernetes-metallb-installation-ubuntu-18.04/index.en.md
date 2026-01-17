---
title: Kubernetes MetalLB Installation / Ubuntu 18.04 Environment
---

## 1. Installation Environment

The installation environment is as follows.
* Kubernetes 1.12
  * Network Addon : using cilium
* Helm
  * Client : v2.13.1
  * Server : v2.13.1
* MetalLB 0.7.3

## 2. Network Configuration

{{< figure caption="[Figure 1] Kubernetes Network" src="images/kubernetes-network.png" width="900px" >}}

The Network is as follows.
* Node Network : 10.0.0.0/24
* LoadBalancer Service IP : 10.0.0.200 ~ 10.0.0.220

## 3. MetalLB Installation

```shell
$ git clone https://github.com/helm/charts.git
$ cd charts/stable/metallb
```

Get the Official Stable Chart from Helm. MetalLB is currently included in Helm's Official Stable Chart.

```text {caption="[File 1] MetalLB Chart's values.yaml", linenos=table}
...
configInline:
  address-pools:
  - name: default
    protocol: layer2
    addresses:
    - 10.0.0.200-10.0.0.220    
...
```

Configure MetalLB. Modify the value.yaml file of the MetalLB Chart as shown in [File 1]. Set MetalLB to ARP Mode and configure the range of LoadBalancer Service IPs.

```shell
$ helm install --name metallb --namespace metallb .
```

Install MetalLB.

## 4. MetalLB Verification

```shell
$ root@kube01:~/charts/stable/metallb# kubectl get service --all-namespaces
NAMESPACE     NAME                    TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)                           AGE
default       my-nginx-loadbalancer   LoadBalancer   10.96.98.173     10.0.0.200   80:30781/TCP                      34m
...                                                                             
```

Create a LoadBalancer Service to verify that the External IP is properly assigned.
