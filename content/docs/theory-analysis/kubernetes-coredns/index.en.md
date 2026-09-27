---
title: Kubernetes CoreDNS
---

This post analyzes CoreDNS running on Kubernetes.

## 1. Kubernetes CoreDNS

{{< figure caption="[Figure 1] Kubernetes CoreDNS Architecture" src="images/kubernetes-coredns-architecture.png" width="800px" >}}

**CoreDNS** is the DNS Server used inside a Kubernetes Cluster. Most Pods perform DNS Record lookups against CoreDNS by default, and CoreDNS serves not only the DNS Records of Services and Pods but also caches the DNS Records of external Domains and provides them to Pods. [Figure 1] shows the Architecture of CoreDNS running in a Kubernetes Cluster.

### 1.1. DNS Record Lookup from Pods

CoreDNS is generally deployed on Worker Nodes as a Deployment and runs as **multiple Pods**. The multiple CoreDNS Pods are grouped under a VIP (ClusterIP) through the CoreDNS Service. Pods in the Kubernetes Cluster access CoreDNS through the VIP of the CoreDNS Service. The reason for using multiple CoreDNS Pods and the CoreDNS Service is to ensure **HA** (High Availability).

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

[Shell 1] shows the Deployment and Service of CoreDNS configured in the `kube-system` Namespace. [Shell 2] shows the process of creating an arbitrary Shell Pod and checking the DNS Server configured in the `/etc/resolv.conf` file inside the Shell Pod. It can be seen that the VIP (ClusterIP) of the CoreDNS Service is configured. [Figure 1] also shows that the VIP of the CoreDNS Service is configured in the `/etc/resolv.conf` file of the Pod.

### 1.2. DNS Record Management of CoreDNS

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

CoreDNS watches Services and Pods through the Kubernetes API Server and **receives changes of Services and Pods**. When CoreDNS receives a create/delete Event of a Service or Pod from the Kubernetes API Server, it creates/deletes the DNS Records of the Service and Pod. This Kubernetes-related behavior of CoreDNS can be configured through the CoreDNS Config file. [File 1] shows the Config file of CoreDNS. It can be seen that there is a `kubernetes` configuration section, and CoreDNS manages the DNS Records of Services and Pods because of the `kubernetes` configuration.

Another configuration worth noting in the CoreDNS configuration file is the `forward` configuration. The `forward` configuration specifies the Upstream DNS Server of CoreDNS. It can be seen that the `/etc/resolv.conf` file is specified in the `forward` configuration. The `dnsPolicy` of the CoreDNS Pod is set to `Default`. `Default` is a setting that creates the Pod's `/etc/resolv.conf` file by inheriting the contents of the `/etc/resolv.conf` file of the Node where the Pod is running. Therefore, the `/etc/resolv.conf` of the CoreDNS Pod stores the DNS Server information of the Node. In other words, CoreDNS sets the **Node's DNS Server as the Upstream**, and when a Pod looks up the DNS Record of an external Domain, CoreDNS looks up the DNS Record of the external Domain again from the Node's DNS Server, caches the result, and provides it to the Pod.

### 1.3. CoreDNS Auto-scaling

In general, as the size of a Kubernetes Cluster grows, the number of Pods increases, and as the number of Pods increases, the load on CoreDNS also increases. Therefore, it is important to distribute the load of each CoreDNS Pod through CoreDNS Auto-scaling. Auto-scaling of CoreDNS is performed using **CPA** (Cluster Proportional Autoscaler) rather than HPA (Horizontal Pod Autoscaler), which is widely used for ordinary Pods. HPA performs Auto-scaling as needed based on CPU/Memory usage, whereas CPA adjusts the number of CoreDNS instances in proportion to the number of Nodes or Pods in the entire Kubernetes Cluster.

Since CoreDNS generally does not use much CPU/Memory, it is generally difficult to adjust the number of CoreDNS instances using HPA. In addition, since a CoreDNS failure leads to DNS Record lookup failures of all Pods inside the Kubernetes Cluster and results in a major outage, CPA is generally used more, as it is more conservative than HPA and performs Auto-scaling proactively based on the number of Nodes/Pods before the actual load occurs.

### 1.4. CoreDNS DNS Record Lookup Log

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
[INFO] 10.244.5.175:51351 - 27693 "A IN postgresql.postgresql.dagster.svc.cluster.local. udp 65 false 512" NXDOMAIN qr,aa,rd 158 0.000357578s
```

CoreDNS can log all DNS Record lookup requests delivered to CoreDNS through the `log` configuration. [File 2] shows the `log` configuration of CoreDNS, and [File 3] shows an example of the DNS Record lookup Log of CoreDNS. With the `log` configuration, CoreDNS by default leaves Logs in the form of `{remote}:{port} - {>id} "{type} {class} {name} {proto} {size} {>do} {>bufsize}" {rcode} {>rflags} {rsize} {duration}`.

* `remote` : Means the **IP of the Pod** used for the lookup request
* `port` : Means the **Port of the Pod** used for the lookup request
* `id` : Means the **ID of the lookup request**
* `type` : Means the **Type of the lookup request** (Query Type)
  * `A` : IPv4 Address
  * `AAAA` : IPv6 Address
  * `CNAME` : Canonical Name
* `class` : Means the **Class of the lookup request** (Query Class)
  * `IN` : Internet
* `name` :  Means the **Name of the lookup request** (Query Name)
* `proto` : Means the **Protocol used for the lookup request**
  * `udp` : UDP
  * `tcp` : TCP
* `size` : Means the **size of the lookup request**
* `do` : Means whether **DNSSEC is used** for the lookup request (DNSSEC OK)
  * `false` : DNSSEC is not used
  * `true` : DNSSEC is used
* `bufsize` : Means the Buffer size for the **EDNS0** extension protocol of the lookup request
* `rcode` : Means the **response Code** for the lookup request (Response Code)
  * `NOERROR` : There is a response to the lookup request
  * `NXDOMAIN` : There is no response to the lookup request
  * `SERVFAIL` : There is a response to the lookup request but an error occurred
  * `REFUSED` : The response to the lookup request is refused
* `rflags` : Means the **response Flags** for the DNS Record lookup request (Response Flags)
  * `QR` : Response Flag
  * `AA` : Authoritative Answer Flag
  * `RD` : Recursion Desired Flag
  * `TC` : Truncated Flag
* `rsize` : Means the **response size** for the lookup request; it means the uncompressed response size, while the Pod receives the compressed response size
* `duration` : Means the **response time** taken for the lookup request

## 2. References

* Kubernetes의 DNS, CoreDNS를 알아보자 : [https://jonnung.dev/kubernetes/2020/05/11/kubernetes-dns-about-coredns/](https://jonnung.dev/kubernetes/2020/05/11/kubernetes-dns-about-coredns/)
* DNS for Services and Pods : [https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
* Customizing DNS Service : [https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/)
* CoreDNS kubernetes Plugin : [https://coredns.io/plugins/kubernetes/](https://coredns.io/plugins/kubernetes/)
* CoreDNS log Plugin : [https://coredns.io/plugins/log/](https://coredns.io/plugins/log/)
