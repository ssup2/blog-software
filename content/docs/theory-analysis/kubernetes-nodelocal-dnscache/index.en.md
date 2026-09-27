---
title: Kubernetes NodeLocal DNSCache
---

This post analyzes the NodeLocal DNSCache technique of Kubernetes.

## 1. Kubernetes NodeLocal DNSCache

The **NodeLocal DNSCache** technique of Kubernetes is a technique that configures a DNS Cache Server on every Node of a Kubernetes Cluster. Through the NodeLocal DNSCache technique, Domain Resolve requests sent by Apps inside Pods can be processed faster, and the phenomenon where Domain Resolve request Packets are dropped due to the Linux conntrack Race Condition can also be avoided. The implementation method of the NodeLocal DNSCache technique differs depending on the kube-proxy Mode used by the Kubernetes Cluster.

### 1.1. with iptables kube-proxy Mode

{{< figure caption="[Figure 1] Kubernetes NodeLocal DNSCache Architecture with iptables kube-proxy Mode" src="images/kubernetes-nodelocal-dnscache-iptables.png" width="700px" >}}

[Figure 1] shows the Architecture of the NodeLocal DNSCache technique when the Kubernetes Cluster uses the iptables kube-proxy Mode. Like a normal Kubernetes Cluster, there are CoreDNS Pods that exist for each Cluster and a CoreDNS Service that groups these CoreDNS Pods. The ClusterIP of the CoreDNS Service is `10.96.0.10`. NodeLocal DNSCache Pods are placed on all Master Nodes and Worker Nodes through a DaemonSet.

```console {caption="[Shell 1] nodelocaldns Dummy Interface with iptables kube-proxy Mode", linenos=table}
# ip a
...
16: nodelocaldns: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default
    link/ether be:29:ca:e7:39:4b brd ff:ff:ff:ff:ff:ff
    inet 169.254.25.10/32 brd 169.254.25.10 scope global nodelocaldns
       valid-lft forever preferred-lft forever
    inet 10.96.0.10/32 brd 10.96.0.10 scope global nodelocaldns
       valid-lft forever preferred-lft forever
...

# ip -details link show
...
16: nodelocaldns: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN mode DEFAULT group default
    link/ether be:29:ca:e7:39:4b brd ff:ff:ff:ff:ff:ff promiscuity 0
    dummy addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso-max-size 65536 gso-max-segs 6553
...
```

Inside the NodeLocal DNSCache Pod, there is a CoreDNS operating in Cache Mode. The CoreDNS operating in Cache Mode runs in the Host Network Namespace and creates a `nodelocaldns` Dummy Interface that has `10.96.0.10`, the ClusterIP of the CoreDNS Service, and `169.254.25.10`, one of the Local Address IPs, as its IP addresses. Then it listens on the `10.96.0.10` and `169.254.25.10` IP addresses through the created `nodelocaldns` Dummy Interface and waits for Domain Resolve requests. [Shell 1] shows the process of checking the information of the `nodelocaldns` Dummy Interface in a Kubernetes Cluster using the iptables kube-proxy Mode.

An App inside a Pod sends Domain Resolve requests only to the NodeLocal DNSCache Pod of the Node where it is running, through the `10.96.0.10` or `169.254.25.10` IP address. Therefore, the Domain Resolve requests that should be sent to the Cluster CoreDNS are naturally distributed to each NodeLocal DNSCache Pod that exists on every Node. In addition, once a Domain Resolve request sent by an App inside a Pod reaches the NodeLocal DNSCache Pod, in most cases it is processed inside the NodeLocal DNSCache Pod, so the Network Hops of the Domain Resolve request are also reduced. For these reasons, NodeLocal DNSCache can improve Domain Resolve processing performance.

The CoreDNS of the NodeLocal DNSCache Pod does not fetch and cache the information of all DNS Records from the Cluster CoreDNS. It fetches and caches only the information of DNS Records belonging to the Kubernetes Cluster Domain from the Cluster CoreDNS, and fetches and caches the information of the remaining DNS Records from external DNS servers. When fetching DNS Record information from the Cluster CoreDNS, TCP is specially used for stability, and when fetching DNS Record information from external DNS servers, UDP is used like normal Domain Resolve requests.

In [Figure 1], `cluster.local` in the Config file of the CoreDNS of the NodeLocal DNSCache Pod means the Domain of the Kubernetes Cluster. In [Figure 1], for DNS Records belonging to the `cluster.local` Domain, the ClusterIP address of the CoreDNS Service is set so that the information is fetched from the Cluster CoreDNS, and the remaining DNS Records are configured to be cached from external DNS Servers.

```yaml {caption="[Text 1] NodeLocal DNSCache ConfigMap", linenos=table}
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-local-dns
  namespace: kube-system
data:
  Corefile: |
    __PILLAR__DNS__DOMAIN__:53 {
        errors
        cache {
                success 9984 30
                denial 9984 5
        }
        reload
        loop
        bind __PILLAR__LOCAL__DNS__ __PILLAR__DNS__SERVER__
        forward . __PILLAR__CLUSTER__DNS__ {
                force_tcp
        }
        prometheus :9253
        health __PILLAR__LOCAL__DNS__:8080
        }
    in-addr.arpa:53 {
        errors
        cache 30
        reload
        loop
        bind __PILLAR__LOCAL__DNS__ __PILLAR__DNS__SERVER__
        forward . __PILLAR__CLUSTER__DNS__ {
                force_tcp
        }
        prometheus :9253
        }
    ip6.arpa:53 {
        errors
        cache 30
        reload
        loop
        bind __PILLAR__LOCAL__DNS__ __PILLAR__DNS__SERVER__
        forward . __PILLAR__CLUSTER__DNS__ {
                force_tcp
        }
        prometheus :9253
        }
    .:53 {
        errors
        cache 30
        reload
        loop
        bind __PILLAR__LOCAL__DNS__ __PILLAR__DNS__SERVER__
        forward . __PILLAR__UPSTREAM__SERVERS__
        prometheus :9253
        }
```

[Text 1] shows the actual Config file of the CoreDNS of the NodeLocal DNSCache Pod. `__PILLAR__DNS__DOMAIN__` means the Domain of the Kubernetes Cluster (`cluster.local`), `__PILLAR__CLUSTER__DNS__` represents the CoreDNS of the Cluster, and `__PILLAR__UPSTREAM__SERVERS__` means the external DNS. Therefore, lines `8~22` represent the part that sends requests for the Cluster's Domain to the Cluster's CoreDNS, and lines `45~53` represent the part that sends the other domain requests to the external DNS.

The NodeLocal DNSCache technique has the disadvantage that if the NodeLocal DNSCache Pod stops, all Pods running on the Node where the NodeLocal DNSCache Pod stopped cannot perform Domain Resolve, which can lead to temporary failures of Apps. Due to the structure of the NodeLocal DNSCache technique, multiple instances cannot run simultaneously on one Node, so care must be taken to ensure that the NodeLocal DNSCache Pod running on each Node does not stop. The NodeLocal DNSCache Pod runs with the `system-node-critical` `priorityClassName` to prevent it from being forcibly removed by kubelet.

If the Image of the NodeLocal DNSCache DaemonSet is simply replaced to update the NodeLocal DNSCache Pod, the temporary stop of the NodeLocal DNSCache Pod cannot be prevented, which can lead to temporary failures of Apps. As a workaround to prevent such failures, when first starting the NodeLocal DNSCache DaemonSet, set the `updateStrategy` to `OnDelete` so that the Kubernetes Cluster user performs the update by deleting NodeLocal DNSCache Pods one by one. Then, cordon the Node to be updated, move all Pods to other Nodes, and delete the NodeLocal DNSCache Pod to proceed with the update. After the update is completed, uncordon the Node to restore it so that Pods can be scheduled. Repeat Cordon, Update, and Uncordon for all Nodes.

```console {caption="[Shell 2] iptables raw table with iptables kube-proxy Mode", linenos=table}
# iptables -t raw -nvL
Chain PREROUTING (policy ACCEPT 5262 packets, 1194K bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 CT         udp  --  *      *       0.0.0.0/0            10.96.0.10           udp dpt:53 NOTRACK
    0     0 CT         tcp  --  *      *       0.0.0.0/0            10.96.0.10           tcp dpt:53 NOTRACK
    0     0 CT         udp  --  *      *       0.0.0.0/0            169.254.25.10        udp dpt:53 NOTRACK
    0     0 CT         tcp  --  *      *       0.0.0.0/0            169.254.25.10        tcp dpt:53 NOTRACK
...
Chain OUTPUT (policy ACCEPT 5918 packets, 537K bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 CT         tcp  --  *      *       10.96.0.10           0.0.0.0/0            tcp spt:8080 NOTRACK
    0     0 CT         tcp  --  *      *       0.0.0.0/0            10.96.0.10           tcp dpt:8080 NOTRACK
    0     0 CT         udp  --  *      *       0.0.0.0/0            10.96.0.10           udp dpt:53 NOTRACK
    0     0 CT         tcp  --  *      *       0.0.0.0/0            10.96.0.10           tcp dpt:53 NOTRACK
    0     0 CT         udp  --  *      *       10.96.0.10           0.0.0.0/0            udp spt:53 NOTRACK
    0     0 CT         tcp  --  *      *       10.96.0.10           0.0.0.0/0            tcp spt:53 NOTRACK
    0     0 CT         tcp  --  *      *       169.254.25.10        0.0.0.0/0            tcp spt:8080 NOTRACK
    0     0 CT         tcp  --  *      *       0.0.0.0/0            169.254.25.10        tcp dpt:8080 NOTRACK
    0     0 CT         udp  --  *      *       0.0.0.0/0            169.254.25.10        udp dpt:53 NOTRACK
    0     0 CT         tcp  --  *      *       0.0.0.0/0            169.254.25.10        tcp dpt:53 NOTRACK
    0     0 CT         udp  --  *      *       169.254.25.10        0.0.0.0/0            udp spt:53 NOTRACK
    0     0 CT         tcp  --  *      *       169.254.25.10        0.0.0.0/0            tcp spt:53 NOTRACK
...
```

The reason why a Domain Resolve request sent from a Pod to the `10.96.0.10` IP address, the ClusterIP of the CoreDNS Service, is sent to the NodeLocal DNSCache Pod instead of the Cluster CoreDNS Pod can be understood by checking the iptables raw Table. [Shell 2] shows the process of checking the raw Table of iptables in a Kubernetes Cluster using the iptables kube-proxy Mode. It can be seen that the `NOTRACK` Rule is applied to Packets whose Src IP or Dst IP contains the `10.96.0.10` IP address.

The `NOTRACK` Rule is a Rule that prevents the Connection of the corresponding Packet from being managed by Linux conntrack. Packets whose Connections are not managed are not NATed by the nat Table of iptables. Therefore, even if a Pod sends a Domain Resolve request to the `10.96.0.10` IP address, it is sent to the NodeLocal DNSCache Pod instead of the Cluster CoreDNS Pod. Another benefit obtained through the `NOTRACK` Rule is that since Domain Resolve request Packets are excluded from the Connection management targets of Linux conntrack, the phenomenon where Domain Resolve request Packets are dropped due to the Linux conntrack Race Condition can also be avoided. For this reason, the `NOTRACK` Rule is also applied to the `169.254.25.10` IP address.

In the iptables kube-proxy Mode, the App inside a Pod simply sends Domain Resolve requests to the `10.96.0.10` IP address in the same way regardless of whether the NodeLocal DNSCache technique is applied. In addition, the CoreDNS of the NodeLocal DNSCache Pod creates the `nodelocaldns` dummy Interface and sets the `NOTRACK` Rule when starting, and deletes the `nodelocaldns` dummy Interface and removes the `NOTRACK` Rule when terminating. Therefore, whether or not to apply the NodeLocal DNSCache technique can be freely changed without restarting Pods. However, if NodeLocal DNSCache terminates abnormally, the `NOTRACK` Rule remains as it is, so the fact that Domain Resolve requests sent by Pods are not sent to the Cluster CoreDNS, which can lead to temporary failures of Apps, does not change.

### 1.2. with IPVS kube-proxy Mode

{{< figure caption="[Figure 2] Kubernetes NodeLocal DNSCache Architecture with iptables IPVS Mode" src="images/kubernetes-nodelocal-dnscache-ipvs.png" width="700px" >}}

[Figure 1] shows the Architecture of the NodeLocal DNSCache technique when the Kubernetes Cluster uses the IPVS kube-proxy Mode. The overall Architecture is the same as when the Kubernetes Cluster uses the iptables kube-proxy Mode, but the difference is that Pods send Domain Resolve requests not to the `10.96.0.10` IP address, the ClusterIP of the CoreDNS Service, but to the `169.254.25.10` IP address, the Local Address IP set by the CoreDNS of NodeLocal DNSCache. Therefore, if the Kubernetes Cluster uses the IPVS kube-proxy Mode, whether or not to apply the NodeLocal DNSCache technique cannot be freely changed. Whenever the application of the NodeLocal DNSCache technique is changed, the Pod DNS Server address setting configured in kubelet must be changed and kubelet must be restarted. In addition, Pods must also be restarted so that the DNS Server address used by the Pods is changed.

The reason why the ClusterIP of the CoreDNS Service is not used inside Pods when the Kubernetes Cluster uses the IPVS kube-proxy Mode is that it cannot be used. This is because there is no way to forcibly send Domain Resolve requests sent from Pods to the ClusterIP of the CoreDNS Service to the NodeLocal DNSCache Pod. Even if the `NOTRACK` Rule is applied to the iptables raw Table, IPVS ignores the `NOTRACK` Rule and performs Load Balancing as it is.

```console {caption="[Shell 3] nodelocaldns Dummy Interface with IPVS kube-proxy Mode", linenos=table}
# ip a
...
16: nodelocaldns: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default
    link/ether be:29:ca:e7:39:4b brd ff:ff:ff:ff:ff:ff
    inet 169.254.25.10/32 brd 169.254.25.10 scope global nodelocaldns
       valid-lft forever preferred-lft forever
...

# ip -details link show
...
16: nodelocaldns: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN mode DEFAULT group default
    link/ether be:29:ca:e7:39:4b brd ff:ff:ff:ff:ff:ff promiscuity 0
    dummy addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso-max-size 65536 gso-max-segs 6553
...
```

[Shell 3] shows the process of checking the information of the `nodelocaldns` Dummy Interface in a Kubernetes Cluster using the IPVS kube-proxy Mode. The `10.96.0.10` IP address, the ClusterIP of the CoreDNS Service, is not set on the `nodelocaldns` Dummy Interface either; only the `169.254.25.10` IP address, the Local Address IP, is set. Since the `10.96.0.10` IP address is not used, it is not set on the `nodelocaldns` Dummy Interface, and the CoreDNS of the NodeLocal DNSCache Pod also listens only on the `169.254.25.10` IP address and waits for Domain Resolve requests.

```console {caption="[Shell 4] iptables raw table with IPVS kube-proxy Mode", linenos=table}
# iptables -t raw -nvL
Chain PREROUTING (policy ACCEPT 18166 packets, 75M bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 CT         udp  --  *      *       0.0.0.0/0            169.254.25.10        udp dpt:53 NOTRACK
    0     0 CT         tcp  --  *      *       0.0.0.0/0            169.254.25.10        tcp dpt:53 NOTRACK
...
Chain OUTPUT (policy ACCEPT 9161 packets, 1478K bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 CT         tcp  --  *      *       169.254.25.10        0.0.0.0/0            tcp spt:8080 NOTRACK
    0     0 CT         tcp  --  *      *       0.0.0.0/0            169.254.25.10        tcp dpt:8080 NOTRACK
    0     0 CT         udp  --  *      *       0.0.0.0/0            169.254.25.10        udp dpt:53 NOTRACK
    0     0 CT         tcp  --  *      *       0.0.0.0/0            169.254.25.10        tcp dpt:53 NOTRACK
    0     0 CT         udp  --  *      *       169.254.25.10        0.0.0.0/0            udp spt:53 NOTRACK
    0     0 CT         tcp  --  *      *       169.254.25.10        0.0.0.0/0            tcp spt:53 NOTRACK
...
```

[Shell 4] shows the process of checking the raw Table of iptables in a Kubernetes Cluster using the IPVS kube-proxy Mode. It can be seen that the `10.96.0.10` IP address, the ClusterIP of the CoreDNS Service, is not set in the raw Table either; only the `169.254.25.10` IP address, the Local Address IP, is set. The `NOTRACK` Rule is set to prevent Domain Resolve request Packets sent to the `169.254.25.10` IP address from being dropped due to the Linux conntrack Race Condition.

## 2. References

* Kubernetes Node Local DNS Cache : [https://povilasv.me/kubernetes-node-local-dns-cache/](https://povilasv.me/kubernetes-node-local-dns-cache/)
* Using NodeLocal DNSCache in Kubernetes Clusters : [https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/](https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/)
* kube-dns per node · kubernetes Issue #45363 : [https://github.com/kubernetes/kubernetes/issues/45363#issuecomment-443019910](https://github.com/kubernetes/kubernetes/issues/45363#issuecomment-443019910)
* Set up NodeLocal DNSCache (GKE) : [https://cloud.google.com/kubernetes-engine/docs/how-to/nodelocal-dns-cache](https://cloud.google.com/kubernetes-engine/docs/how-to/nodelocal-dns-cache)
* colopl/k8s-local-dns : [https://github.com/colopl/k8s-local-dns](https://github.com/colopl/k8s-local-dns)
