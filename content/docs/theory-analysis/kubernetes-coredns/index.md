---
title: Kubernetes CoreDNS
---

Kubernetes에서 동작하는 CoreDNS를 분석한다.

## 1. Kubernetes CoreDNS

{{< figure caption="[Figure 1] Kubernetes CoreDNS Architecture" src="images/kubernetes-coredns-architecture.png" width="800px" >}}

CoreDNS는 Kubernetes Cluster 내부에서 이용되는 DNS Server이다. 대부분의 Pod들은 기본적으로 CoreDNS로 DNS Record를 조회를 수행하며, CoreDNS는 Service 또는 Pod의 DNS Record 뿐만 아니라 외부 Domain의 DNS Record도 Caching하여 Pod에게 제공한다. [Figure 1]은 Kubernetes Cluster에서 동작하는 CoreDNS의 Architecture를 나타내고 있다.

### 1.1. Pod의 DNS Record 조회

CoreDNS는 일반적으로 Worker Node에서 Deployment로 배포되어 **다수의 Pod**로 구동된다. 그리고 다수의 CoreDNS Pod들은 CoreDNS Service를 통해서 VIP (ClusterIP)로 묶이게 된다. Kubernetes Cluster의 Pod들은 CoreDNS Service의 VIP를 통해서 CoreDNS에 접근하게 된다. 다수의 CoreDNS Pod와 CoreDNS Service를 이용하는 이유는 **HA(High Availability)**를 확보하기 위해서다.

```shell {caption="[Shell 1] CoreDNS Deployment, Pod"}
$ kubectl -n kube-system get deployment coredns
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
coredns   2/2     2            2           13d

$ kubectl -n kube-system get service kube-dns
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   13d
```

```shell {caption="[Shell 2] Pod /etc/resolv.conf", linenos=table}
$ kubectl run my-shell --rm -i --tty --image nicolaka/netshoot -- bash
(container)# cat /etc/resolv.conf
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

[Shell 1]은 kube-system Namespace에 설정되어 있는 CoreDNS의 Deployment, Service의 모습을 나타내고 있다. [Shell 2]는 임의의 Shell Pod을 만들고 Shell Pod안에서 `/etc/resolv.conf` 파일에 설정된 DNS Server를 확인하는 과정이다. CoreDNS Service의 VIP (ClusterIP)가 설정되어 있는걸 확인할 수 있다. [Figure 1]에서도 Pod의 `/etc/resolve.conf` 파일에 CoreDNS Service의 VIP가 설정되어 있는것을 나타내고 있다.

### 1.2. CoreDNS의 DNS Record 관리

```text {caption="[File 1] CoreDNS Config", linenos=table}
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
```

CoreDNS는 Kubernetes API 서버로부터 Service와 Pod를 Watch하여 **Service와 Pod의 변화를 수신**한다. Kubernetes API 서버로부터 Service 또는 Pod의 생성/삭제 Event를 받은 CoreDNS는 Service와 Pod의 DNS Record를 생성/삭제한다. 이러한 CoreDNS의 Kubernetes 관련 동작은 CoreDNS의 Config 파일을 통해서 설정할 수 있다. [File 1]은 CoreDNS의 Config 파일을 나타내고 있다. `kubernetes` 설정 부분이 있는걸 확인할 수 있으며, `kubernetes` 설정으로 인해서 Service와 Pod의 DNS Record를 관리한다.

CoreDNS의 설정파일에서 한가지 더 주목해야하는 설정은 `forward` 설정이다. `forward` 설정은 CoreDNS의 Upstream DNS Server를 지정하는 역할을 수행한다. `forward` 설정에 `/etc/resolv.conf` 파일이 지정되어 있는것을 알 수 있다. CoreDNS Pod의 `dnsPolicy`는 `Default`로 설정되어 있다. `Default`는 Pod가 떠있는 Node의 `/etc/resolv.conf` 파일의 내용을 상속받아 Pod의 `/etc/resolv.conf` 파일을 생성하는 설정이다. 따라서 CoreDNS Pod의 `/etc/resolve.conf`는 Node의 DNS Server 정보가 저장되어 있다. 즉 CoreDNS는 **Node의 DNS Server를 Upstream**으로 설정하며, Pod가 외부 Domain의 DNS Record를 조회하면 CoreDNS는 Node의 DNS Server에게 다시 외부 Domain의 DNS Record를 조회하고 그 결과를 Caching하여 Pod에게 제공한다.

### 1.3. CoreDNS Auto-scaling

일반적으로 Kubernetes Cluster의 크기가 증가할 수록 Pod의 개수가 증가하고, Pod의 개수가 증가할수록 CoreDNS의 부하도 같이 증가한다. 따라서 CoreDNS Auto-scaling을 통해서 각 CoreDNS Pod의 부하를 분산시키는 것이 중요하다. CoreDNS의 Auto-scaling은 일반인 Pod에 많이 활용되는 HPA (Horizontal Pod Autoscaler)보다는 **CPA (Cluster Proportional Autoscaler)**를 활용하여 수행한다. HPA는 CPU/Memory 사용량을 기준으로 필요에 따라서 Auto-scaling을 수행하지만, CPA는 Kubernetes Cluster 전체의 Node 또는 Pod의 개수에 비례하여 CoreDNS의 개수를 조정한다.

CoreDNS는 일반적으로 CPU/Memory 사용량이 많지 않기 때문에 일반적으로 HPA를 활용하여 CoreDNS의 개수를 조정하는 것이 어렵다. 또한 CoreDNS 장애는 Kubernetes Cluster 내부의 모든 Pod의 DNS Record 조회 실패로 이어지고 큰 장애로 이어지기 때문에, HPA보다 보수적이며 실제 부하가 발생하기전에 Node/Pod 개수를 기반으로 좀더 앞서서 Auto-scaling을 수행하는 CPA를 일반적으로 좀더 활용한다.

### 1.4. CoreDNS DNS Record 조회 Log

```text {caption="[File 2] CoreDNS Log Config", linenos=table}
.:53 {
    log
...
}
```

```text {caption="[File 3] CoreDNS DNS Record Lookup Log Example", linenos=table}
[INFO] 10.244.5.175:34723 - 2191 "A IN postgresql.postgresql.svc.cluster.local. udp 57 false 512" NOERROR qr,aa,rd 112 0.000806156s
[INFO] 10.244.5.175:53842 - 51161 "AAAA IN postgresql.postgresql.dagster.svc.cluster.local. udp 65 false 512" NXDOMAIN qr,aa,rd 158 0.000603742s
[INFO] 10.244.5.175:53842 - 17124 "A IN postgresql.postgresql.dagster.svc.cluster.local. udp 65 false 512" NXDOMAIN qr,aa,rd 158 0.001028403s
[INFO] 10.244.4.69:51787 - 29856 "A IN dagster-workflows.dagster.svc.cluster.local. udp 61 false 512" NOERROR qr,aa,rd 120 0.000590034s
[INFO] 10.244.4.69:51787 - 57932 "AAAA IN dagster-workflows.dagster.svc.cluster.local. udp 61 false 512" NOERROR qr,aa,rd 154 0.000671699s
[INFO] 10.244.4.69:51787 - 12158 "AAAA IN dagster-workflows.svc.cluster.local. udp 53 false 512" NXDOMAIN qr,aa,rd 146 0.00062795s
[INFO] 10.244.4.69:51787 - 46184 "AAAA IN dagster-workflows.cluster.local. udp 49 false 512" NXDOMAIN qr,aa,rd 142 0.000417661s
[INFO] 10.244.4.69:51787 - 14951 "AAAA IN dagster-workflows. udp 35 false 512" NXDOMAIN qr,aa,rd,ra 110 0.00012804s
[INFO] 10.244.5.175:33153 - 36922 "AAAA IN dagster-workflows.dagster.svc.cluster.local. udp 61 false 512" NOERROR qr,aa,rd 154 0.00112786s
[INFO] 10.244.5.175:33153 - 2421 "A IN dagster-workflows.dagster.svc.cluster.local. udp 61 false 512" NOERROR qr,aa,rd 120 0.001399106s
[INFO] 10.244.5.175:33153 - 64099 "AAAA IN dagster-workflows.svc.cluster.local. udp 53 false 512" NXDOMAIN qr,aa,rd 146 0.000403953s
[INFO] 10.244.5.175:33153 - 43914 "AAAA IN dagster-workflows.cluster.local. udp 49 false 512" NXDOMAIN qr,aa,rd 142 0.000372453s
[INFO] 10.244.5.175:33153 - 50806 "AAAA IN dagster-workflows. udp 35 false 512" NXDOMAIN qr,aa,rd,ra 110 0.000258997s
[INFO] 10.244.5.175:52825 - 57931 "AAAA IN postgresql.postgresql.dagster.svc.cluster.local. udp 65 false 512" NXDOMAIN qr,aa,rd 158 0.000735281s
[INFO] 10.244.5.175:52825 - 14918 "A IN postgresql.postgresql.dagster.svc.cluster.local. udp 65 false 512" NXDOMAIN qr,aa,rd 158 0.001117651s
[INFO] 10.244.5.175:48479 - 6783 "AAAA IN postgresql.postgresql.svc.cluster.local. udp 57 false 512" NOERROR qr,aa,rd 150 0.000550951s
[INFO] 10.244.5.175:48479 - 8047 "A IN postgresql.postgresql.svc.cluster.local. udp 57 false 512" NOERROR qr,aa,rd 112 0.000853697s
[INFO] 10.244.5.175:39729 - 58289 "AAAA IN postgresql.postgresql.dagster.svc.cluster.local. udp 65 false 512" NXDOMAIN qr,aa,rd 158 0.000522368s
[INFO] 10.244.5.175:39729 - 34179 "A IN postgresql.postgresql.dagster.svc.cluster.local. udp 65 false 512" NXDOMAIN qr,aa,rd 158 0.000654199s
[INFO] 10.244.5.175:51351 - 27693 "A IN postgres제l.postgresql.dagster.svc.cluster.local. udp 65 false 512" NXDOMAIN qr,aa,rd 158 0.000357578s
```

CoreDNS는 `log` 설정을 통해서 CoreDNS로 전달되는 모든 DNS Record 조회를 Log로 남길 수 있다. [File 2]는 CoreDNS의 `log` 설정을 나타내고 있으며, [File 3]은 CoreDNS의 DNS Record 조회 Log의 예제 나타내고 있다. `log` 설정 시 기본적으로 `{remote}:{port} - {>id} "{type} {class} {name} {proto} {size} {>do} {>bufsize}" {rcode} {>rflags} {rsize} {duration}` 형태의 Log를 남긴다.

## 2. 참조

* [https://jonnung.dev/kubernetes/2020/05/11/kubernetes-dns-about-coredns/](https://jonnung.dev/kubernetes/2020/05/11/kubernetes-dns-about-coredns/)
* [https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
* [https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/)
* [https://coredns.io/plugins/kubernetes/](https://coredns.io/plugins/kubernetes/)
* [https://coredns.io/plugins/log/](https://coredns.io/plugins/log/)