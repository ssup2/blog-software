---
title: Kubernetes Service Proxy
---

Kubernetes supports Service Proxy in three modes: iptables, IPVS, and Userspace. Analyzes the path of Service request packets according to Service Proxy mode.

## 1. Service, Pod Info

```shell {caption="[Shell 1] Service and Pod Information for Kubernetes Service Proxy Analysis", linenos=table}
$ kubectl get pod -o wide
NAME                              READY   STATUS    RESTARTS   AGE   IP              NODE     NOMINATED NODE
my-nginx-756f645cd7-gh7sq         1/1     Running   14         15d   192.167.2.231   kube03   <none>
my-nginx-756f645cd7-hm7rg         1/1     Running   17         20d   192.167.2.206   kube03   <none>
my-nginx-756f645cd7-qfqbp         1/1     Running   16         20d   192.167.1.123   kube02   <none>

$ kubectl get pod -o wide
NAME                    TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)                           AGE     SELECTOR
my-nginx-cluster        ClusterIP      10.103.1.234     <none>         80/TCP                            15d     run=my-nginx
my-nginx-loadbalancer   LoadBalancer   10.96.98.173     172.35.0.200   80:30781/TCP                      15d    run=my-nginx
my-nginx-nodeport       NodePort       10.97.229.148    <none>         80:30915/TCP                      15d     run=my-nginx
```

[Shell 1] shows Service and Pod information for Kubernetes Service Proxy analysis. Three `nginx` Pods were created using Deployment, and **ClusterIP** type `my-nginx-cluster` Service, **NodePort** type `my-nginx-nodeport` Service, and **LoadBalancer** type `my-nginx-loadbalancer` Service were attached.

## 2. iptables Mode

{{< figure caption="[Figure 1] Service Request Packet Path in iptables Mode" src="images/iptables-mode-service-packet-path.png" width="700px" >}}

```text {caption="[NAT Table 1] KUBE-SERVICES in iptables Mode", linenos=table}
Chain KUBE-SERVICES (2 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  tcp  --  *      *      !192.167.0.0/16       10.96.98.173         /* default/my-nginx-loadbalancer: cluster IP */ tcp dpt:80
    0     0 KUBE-SVC-TNQCJ2KHUMKABQTD  tcp  --  *      *       0.0.0.0/0            10.96.98.173         /* default/my-nginx-loadbalancer: cluster IP */ tcp dpt:80
    0     0 KUBE-FW-TNQCJ2KHUMKABQTD  tcp  --  *      *       0.0.0.0/0            172.35.0.200         /* default/my-nginx-loadbalancer: loadbalancer IP */ tcp dpt:80
    0     0 KUBE-MARK-MASQ  tcp  --  *      *      !192.167.0.0/16       10.103.1.234         /* default/my-nginx-cluster: cluster IP */ tcp dpt:80
    0     0 KUBE-SVC-52FY5WPFTOHXARFK  tcp  --  *      *       0.0.0.0/0            10.103.1.234         /* default/my-nginx-cluster: cluster IP */ tcp dpt:80 
    0     0 KUBE-MARK-MASQ  tcp  --  *      *      !192.167.0.0/16       10.97.229.148        /* default/my-nginx-nodeport: cluster IP */ tcp dpt:80
    0     0 KUBE-SVC-6JXEEPSEELXY3JZG  tcp  --  *      *       0.0.0.0/0            10.97.229.148        /* default/my-nginx-nodeport: cluster IP */ tcp dpt:80
    0     0 KUBE-NODEPORTS  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service nodeports; NOTE: this must be the last rule in this chain */ ADDRTYPE match dst-type LOCAL
```

```text {caption="[NAT Table 2] KUBE-NODEPORTS in iptables Mode", linenos=table}
Chain KUBE-NODEPORTS (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/my-nginx-loadbalancer: */ tcp dpt:30781
    0     0 KUBE-SVC-TNQCJ2KHUMKABQTD  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/my-nginx-loadbalancer: */ tcp dpt:30781
    0     0 KUBE-MARK-MASQ  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/my-nginx-nodeport: */ tcp dpt:30915
    0     0 KUBE-SVC-6JXEEPSEELXY3JZG  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/my-nginx-nodeport: */ tcp dpt:30915 
```

```text {caption="[NAT Table 3] KUBE-FW-XXX in iptables Mode", linenos=table}
Chain KUBE-FW-TNQCJ2KHUMKABQTD (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/my-nginx-loadbalancer: loadbalancer IP */
    0     0 KUBE-SVC-TNQCJ2KHUMKABQTD  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/my-nginx-loadbalancer: loadbalancer IP */
    0     0 KUBE-MARK-DROP  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/my-nginx-loadbalancer: loadbalancer IP */
```

```text {caption="[NAT Table 4] KUBE-SVC-XXX in iptables Mode", linenos=table}
Chain KUBE-SVC-TNQCJ2KHUMKABQTD (2 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SEP-6HM47TA5RTJFOZFJ  all  --  *      *       0.0.0.0/0            0.0.0.0/0            statistic mode random probability 0.33332999982
    0     0 KUBE-SEP-AHRDCNDYGFSFVA64  all  --  *      *       0.0.0.0/0            0.0.0.0/0            statistic mode random probability 0.50000000000
    0     0 KUBE-SEP-BK523K4AX5Y34OZL  all  --  *      *       0.0.0.0/0            0.0.0.0/0      
```

```text {caption="[NAT Table 5] KUBE-SEP-XXX in iptables Mode", linenos=table}
Chain KUBE-SEP-6HM47TA5RTJFOZFJ (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       192.167.2.231        0.0.0.0/0
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp to:192.167.2.231:80 
```

```text {caption="[NAT Table 6] KUBE-POSTROUTING in iptables Mode", linenos=table}
Chain KUBE-POSTROUTING (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service traffic requiring SNAT */ mark match
0x4000/0x4000 
```

```text {caption="[NAT Table 7] KUBE-MARK-MASQ in iptables Mode", linenos=table}
Chain KUBE-MARK-MASQ (23 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x4000 
```

```text {caption="[NAT Table 8] KUBE-MARK-DROP in iptables Mode", linenos=table}
Chain KUBE-MARK-DROP (10 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x8000 
```

The iptables Mode of Service Proxy is a mode that performs Service Proxy using iptables. It is the default proxy mode currently used by Kubernetes. [Figure 1] shows the path of Service request packets in iptables Mode. [NAT Table 1] ~ [NAT Table 8] show the actual contents of the main NAT Tables in [Figure 1]. The NAT Tables in [Figure 1] are configured identically on all nodes that make up the Kubernetes cluster. Therefore, Service request packets can be sent from any node that makes up the Kubernetes cluster.

Since request packets sent from most Pods are delivered to the Host's Network Namespace through the Pod's veth, request packets are delivered to the `KUBE-SERVICES` Table by the `PREROUTING` Table. Request packets sent from Pods or Host Processes using the Host's Network Namespace are delivered to the `KUBE-SERVICES` Table by the `OUTPUT` Table. In the `KUBE-SERVICES` Table, if the Dest IP and Dest Port of the request packet match the IP and Port of a ClusterIP Service, the request packet is delivered to the `KUBE-SVC-XXX` Table, which is the NAT Table of the matching ClusterIP Service.

If the Dest IP of the request packet in the `KUBE-SERVICES` Table is the Node's own IP, the request packet is delivered to the `KUBE-NODEPORTS` Table. In the `KUBE-NODEPORTS` Table, if the Dest Port of the request packet matches the Port of a NodePort Service, the request packet is delivered to the `KUBE-SVC-XXX` Table, which is the NAT Table of the NodePort Service. If the Dest IP and Dest Port of the request packet in the `KUBE-SERVICES` Table match the External IP and Port of a **LoadBalancer** Service, the request packet is delivered to the `KUBE-FW-XXX` Table, which is the NAT Table of the matching **LoadBalancer** Service, and then to the `KUBE-SVC-XXX` Table, which is the NAT Table of the **LoadBalancer** Service.

The `KUBE-SVC-XXX` Table uses iptables' statistic feature to randomly and evenly load balance request packets to Pods that make up the Service. In [NAT Table 4], since the Service consists of 3 Pods, it can be confirmed that request packets are configured to be randomly and evenly load balanced to 3 `KUBE-SEP-XXX` Tables. In the `KUBE-SEP-XXX` Table, request packets perform DNAT to the Pod's IP and the Port set in the Service. Request packets **DNAT**ed to the Pod's IP are delivered to that Pod through the Container Network built via CNI Plugin.

Since request packets delivered to Services are delivered to Pods through iptables' DNAT, response packets sent from Pods must be **SNAT**ed to the Service's IP, not the Pod's IP. There is no explicit SNAT Rule for Services in iptables. However, iptables SNATs response packets received from Service Pods based on TCP Connection information from Linux Kernel's **Conntrack** (Connection Tracking).

### 2.1. Source IP

**The Src IP of Service request packets is maintained or SNATed to the Host's IP through Masquerade.** The `KUBE-MARK-MASQ` Table is a table that marks packets for Masquerade of request packets. Marked packets are Masqueraded in the `KUBE-POSTROUTING` Table, and the Src IP is SNATed to the Host's IP. When examining iptables Tables, it can be confirmed that packets to be Masqueraded are marked through the `KUBE-MARK-MASQ` Table in various places.

{{< figure caption="[Figure 2] Packet Path According to `externalTrafficPolicy` of **NodePort**, **LoadBalancer** Service" src="images/nodeport-policy.png" width="550px" >}}

The `externalTrafficPolicy` of **NodePort** and **LoadBalancer** Services uses Cluster as the default value. If the `externalTrafficPolicy` value is set to Cluster, the Src IP of request packets is SNATed to the Host's IP through Masquerade. The left side of [Figure 2] shows a diagram where the `externalTrafficPolicy` value is set to Cluster and request packets are Masqueraded. It can be confirmed that all packets with the Port of **NodePort** and **LoadBalancer** Services as Dest Port in the `KUBE-NODEPORTS` Table are marked through the `KUBE-MARK-MASQ` Table.

If the `externalTrafficPolicy` value is set to Local, the rules related to the `KUBE-MARK-MASQ` Table disappear from the `KUBE-NODEPORTS` Table, and Masquerade is not performed. Therefore, the Src IP of request packets is maintained as-is. Additionally, request packets are not load balanced on the Host and are only delivered to Target Pods running on the Host where the request packet was delivered. If a request packet is delivered to a Host without Target Pods, the request packet is dropped. The right side of [Figure 2] shows a diagram where `externalTrafficPolicy` is set to Local and Masquerade is not performed.

`externalTrafficPolicy: Local` is mainly used in LoadBalancer Services. This is because the Src IP of request packets can be maintained, and since the Cloud Provider's Load Balancer performs load balancing, the Host's load balancing process is unnecessary. If `externalTrafficPolicy: Local`, packets are dropped on Hosts without Target Pods, so during the Host Health Check process performed by the Cloud Provider's Load Balancer, Hosts without Target Pods are excluded from load balancing targets. Therefore, the Cloud Provider's Load Balancer load balances request packets only to Hosts with Target Pods.

{{< figure caption="[Figure 3] Packet Path Before/After Applying Hairpinning in iptables Mode" src="images/iptables-mode-hairpinning.png" width="650px" >}}

`Masquerade` is also necessary when a Pod sends request packets to the IP of the Service it belongs to and the request packet returns to itself. The left side of [Figure 3] shows this case. Request packets are DNATed, so both the Src IP and Dest IP of the packet become the Pod's IP. Therefore, when sending response packets for request packets returned from the Pod, SNAT is not performed because packets are processed inside the Pod without passing through the Host's NAT Table.

Using Masquerade, request packets returned to the Pod can be forcibly passed to the Host so that SNAT is performed. This technique of intentionally bypassing packets to receive them is called Hairpinning. The right side of [Figure 3] shows a case where Hairpinning is applied using Masquerade. In the `KUBE-SEP-XXX` Table, if the Src IP of the request packet is the same as the IP to DNAT, that is, when a Pod receives a packet it sent to the Service, the request packet is marked through the `KUBE-MARK-MASQ` Table and Masqueraded in the `KUBE-POSTROUTING` Table. Since the Src IP of the packet received by the Pod is set to the Host's IP, the Pod's response is delivered to the Host's NAT Table and then SNATed and DNATed again to be delivered to the Pod.

## 3. Userspace Mode

{{< figure caption="[Figure 4] Service Request Packet Path in Userspace Mode" src="images/userspace-mode-service-packet-path.png" width="700px" >}}

```text {caption="[NAT Table 9] KUBE-PORTALS-CONTAINER in Userspace Mode", linenos=table}
Chain KUBE-PORTALS-CONTAINER (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            10.96.98.173         /* default/my-nginx-loadbalancer: */ tcp dpt:80 redir ports 38023
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            172.35.0.200         /* default/my-nginx-loadbalancer: */ tcp dpt:80 redir ports 38023
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            10.103.1.234         /* default/my-nginx-cluster: */ tcp dpt:80 redir ports 36451
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            10.97.229.148        /* default/my-nginx-nodeport: */ tcp dpt:80 redir ports 44257
```

```text {caption="[NAT Table 10] KUBE-NODEPORT-CONTAINER in Userspace Mode", linenos=table}
Chain KUBE-NODEPORT-CONTAINER (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/my-nginx-loadbalancer: */ tcp dpt:30781 redir ports 38023
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/my-nginx-nodeport: */ tcp dpt:30915 redir ports 44257
```

```text {caption="[NAT Table 11] KUBE-PORTALS-HOST in Userspace Mode", linenos=table}
Chain KUBE-PORTALS-HOST (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            10.96.98.173         /* default/my-nginx-loadbalancer: */ tcp dpt:80 to:172.35.0.100:38023
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            172.35.0.200         /* default/my-nginx-loadbalancer: */ tcp dpt:80 to:172.35.0.100:38023
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            10.103.1.234         /* default/my-nginx-cluster: */ tcp dpt:80 to:172.35.0.100:46635
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            10.97.229.148        /* default/my-nginx-nodeport: */ tcp dpt:80 to:172.35.0.100:32847
```

```text {caption="[NAT Table 12] KUBE-NODEPORT-HOST in Userspace Mode", linenos=table}
Chain KUBE-NODEPORT-HOST (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/my-nginx-loadbalancer: */ tcp dpt:30781 to:172.35.0.100:38023
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/my-nginx-nodeport: */ tcp dpt:30915 to:172.35.0.100:44257
```

The Userspace Mode of Service Proxy is a mode where kube-proxy running in Userspace performs the Service Proxy role. It was the first Proxy Mode provided by Kubernetes. Currently, it is rarely used due to inferior performance compared to iptables Mode. [Figure 4] shows the path of Service request packets in Userspace Mode. [NAT Table 9] ~ [NAT Table 12] show the actual contents of the main NAT Tables in [Figure 4]. The NAT Tables and kube-proxy in [Figure 4] are configured identically on all nodes that make up the Kubernetes cluster. Therefore, Service request packets can be sent from any node that makes up the Kubernetes cluster.

Since request packets sent from most Pods are delivered to the Host's Network Namespace through the Pod's veth, request packets are delivered to the `KUBE-PORTALS-CONTAINER` Table by the PREROUTING Table. In the `KUBE-PORTALS-CONTAINER` Table, if the Dest IP and Dest Port of the request packet match the IP and Port of a ClusterIP Service, the request packet is **Redirect**ed to kube-proxy. If the Dest IP of the request packet is the Node's own IP, the packet is delivered to the `KUBE-NODEPORT-CONTAINER` Table. In the `KUBE-NODEPORT-CONTAINER` Table, if the Dest Port of the request packet matches the Port of a NodePort Service, the request packet is Redirected to kube-proxy. If the Dest IP and Dest Port of the request packet match the External IP and Port of a **LoadBalancer** Service, that request packet is also Redirected to kube-proxy.

Request packets sent from Pods or Host Processes using the Host's Network Namespace are delivered to the `KUBE-PORTALS-HOST` Table by the OUTPUT Table. The subsequent request packet processing in the `KUBE-PORTALS-HOST` and `KUBE-NODEPORT-HOST` Tables is similar to request packet processing in the `KUBE-PORTALS-CONTAINER` and `KUBE-NODEPORT-CONTAINER` Tables. The difference is that **DNAT** is performed instead of Redirecting request packets.

**All request packets sent to Services through Redirect or DNAT are delivered to kube-proxy.** One Service is mapped per Dest Port of request packets received by kube-proxy. Therefore, kube-proxy can identify which Service the request packet should be delivered to through the Dest Port of the Redirected or NATed request packet. kube-proxy evenly load balances received request packets to multiple Pods belonging to the Service that the request packet should be sent to and retransmits them.

Since kube-proxy operates in the Host's Network Namespace, request packets sent by kube-proxy also pass through Service NAT Tables. However, since the Dest IP of request packets sent by kube-proxy is the Pod's IP, the request packet is not changed by Service NAT Tables and is delivered to that Pod through the Container Network built via CNI Plugin.

## 4. IPVS Mode

{{< figure caption="[Figure 5] Service Request Packet Path in IPVS Mode" src="images/ipvs-mode-service-packet-path.png" width="700px" >}}

```text {caption="[NAT Table 13] KUBE-SERVICES in IPVS Mode", linenos=table}
Chain KUBE-SERVICES (2 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-LOAD-BALANCER  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* Kubernetes service lb portal */ match-set KUBE-LOAD-BALANCER dst,dst
    0     0 KUBE-MARK-MASQ  all  --  *      *      !192.167.0.0/16       0.0.0.0/0            /* Kubernetes service cluster ip + port for masquerade purpose */ match-set KUBE-CLUSTER-IP dst,dst
    8   483 KUBE-NODE-PORT  all  --  *      *       0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL
    0     0 ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            match-set KUBE-CLUSTER-IP dst,dst
    0     0 ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            match-set KUBE-LOAD-BALANCER dst,dst
```

```text {caption="[NAT Table 12] KUBE-NODE-PORT in IPVS Mode", linenos=table}
Chain KUBE-NODE-PORT (1 references)
 pkts bytes target     prot opt in     out     source               destination
    6   360 KUBE-MARK-MASQ  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* Kubernetes nodeport TCP port for masquerade purpose */ match-set KUBE-NODE-PORT-TCP dst
```

```text {caption="[NAT Table 13] KUBE-LOAD-BALANCER in IPVS Mode", linenos=table}
Chain KUBE-LOAD-BALANCER (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       0.0.0.0/0            0.0.0.0/0 
```

```text {caption="[NAT Table 14] KUBE-POSTROUTING in IPVS Mode", linenos=table}
Chain KUBE-POSTROUTING (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service traffic requiring SNAT */ mark match 0x4000/0x4000
    1    60 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* Kubernetes endpoints dst ip:port, source ip for solving hairpinpurpose */ match-set KUBE-LOOP-BACK dst,dst,src
```

```text {caption="[NAT Table 15] KUBE-MARK-MASQ in IPVS Mode", linenos=table}
Chain KUBE-MARK-MASQ (3 references)
 pkts bytes target     prot opt in     out     source               destination         
    2   120 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x4000
```

```text {caption="[IPset List 1] IPset List in IPVS Mode", linenos=table}
Name: KUBE-CLUSTER-IP
Type: hash:ip,port
Revision: 5
Header: family inet hashsize 1024 maxelem 65536
Size in memory: 600
References: 2
Number of entries: 1
Members:
10.96.98.173,tcp:80 
10.97.229.148,tcp:80
10.103.1.234,tcp:80 

Name: KUBE-LOOP-BACK
Type: hash:ip,port,ip
Revision: 5
Header: family inet hashsize 1024 maxelem 65536
Size in memory: 896
References: 1
Number of entries: 3
Members:
192.167.2.231,tcp:80,192.167.2.231
192.167.1.123,tcp:80,192.167.1.123
192.167.2.206,tcp:80,192.167.2.206

Name: KUBE-NODE-PORT-TCP
Type: bitmap:port
Revision: 3
Header: range 0-65535
Size in memory: 8268
References: 1
Number of entries: 2
Members:
30781
30915

Name: KUBE-LOAD-BALANCER
Type: hash:ip,port
Revision: 5
Header: family inet hashsize 1024 maxelem 65536
Size in memory: 152
References: 2
Number of entries: 1
Members:
172.35.0.200,tcp:80 
```

```text {caption="[IPVS List 1] IPVS List in IPVS Mode", linenos=table}
TCP  172.35.0.100:30781 rr
  -> 192.167.1.123:80             Masq    1      0          0
  -> 192.167.2.206:80             Masq    1      0          0
  -> 192.167.2.231:80             Masq    1      0          0
TCP  172.35.0.100:30915 rr
  -> 192.167.1.123:80             Masq    1      0          0
  -> 192.167.2.206:80             Masq    1      0          0
  -> 192.167.2.231:80             Masq    1      0          0
TCP  172.35.0.200:80 rr
  -> 192.167.1.123:80             Masq    1      0          0
  -> 192.167.2.206:80             Masq    1      0          0
  -> 192.167.2.231:80             Masq    1      0          0    
TCP  10.96.98.173:80 rr
  -> 192.167.1.123:80             Masq    1      0          0
  -> 192.167.2.206:80             Masq    1      0          0
  -> 192.167.2.231:80             Masq    1      0          0
TCP  10.97.229.148:80 rr
  -> 192.167.1.123:80             Masq    1      0          0
  -> 192.167.2.206:80             Masq    1      0          0
  -> 192.167.2.231:80             Masq    1      0          0   
TCP  10.103.1.234:80 rr
  -> 192.167.1.123:80             Masq    1      0          0
  -> 192.167.2.206:80             Masq    1      0          0
  -> 192.167.2.231:80             Masq    1      0          0         
```

The IPVS Mode of Service Proxy is a mode where IPVS, an L4 Load Balancer provided by the Linux Kernel, performs the Service Proxy role. Since IPVS shows higher performance than iptables when performing Packet Load Balancing, IPVS Mode shows higher performance than iptables Mode. [Figure 5] shows the path of request packets sent to Services in IPVS Mode. [NAT Table 13] ~ [NAT Table 15] show the actual contents of the main NAT Tables in [Figure 5]. [IPset List 1] shows the main IPset list in IPVS Mode. [IPVS List 1] shows the actual contents of IPVS in [Figure 5]. The NAT Tables, IPset, and IPVS in [Figure 5] are configured identically on all nodes that make up the Kubernetes cluster. Therefore, Service request packets can be sent from any node that makes up the Kubernetes cluster.

Since request packets sent from most Pods are delivered to the Host's Network Namespace through the Pod's veth, request packets are delivered to the `KUBE-SERVICES` Table by the `PREROUTING` Table. Request packets sent from Pods or Host Processes using the Host's Network Namespace are delivered to the `KUBE-SERVICES` Table by the OUTPUT Table. In the `KUBE-SERVICES` Table, if the Dest IP and Dest Port of the request packet match the IP and Port of a ClusterIP Service, the request packet is delivered to IPVS.

If the Dest IP of the request packet is the Node's own IP, the request packet is delivered to IPVS via the `KUBE-NODE-PORT` Table. If the Dest IP and Dest Port of the request packet match the External IP and Port of a **LoadBalancer** Service, that request packet is delivered to IPVS via the `KUBE-LOAD-BALANCER` Table. If the Default Rule of the `PREROUTING` and `OUTPUT` Tables is Accept, packets delivered to Services are delivered to IPVS even without the `KUBE-SERVICES` Table, so it does not affect Services.

IPVS performs Load Balancing and **DNAT** to the Pod's IP and the Port set in the Service when the Dest IP and Dest Port of the request packet match the Service's Cluster-IP and Port, when the Dest IP of the request packet is the Node's own IP and the Dest Port matches the NodePort Service's NodePort, or when the Dest IP and Dest Port of the request packet match the **LoadBalancer** Service's External IP and Port. Request packets DNATed to the Pod's IP are delivered to that Pod through the Container Network built via CNI Plugin. In [IPVS List 1], it can be confirmed that Load Balancing and DNAT are performed for all IPs associated with Services.

IPVS also uses TCP Connection information from Linux Kernel's Conntrack, same as iptables. Therefore, response packets for Service Packets that were DNATed and sent by IPVS are SNATed again by IPVS and delivered to the Pod or Host Process that requested the Service. **Hairpinning** is also applied in IPVS Mode, like in iptables Mode, to solve the SNAT problem of Service response packets. It can be seen that Masquerade is performed in the `KUBE-POSTROUTING` Table when matching the `KUBE-LOOP-BACK` IPset rule. It can be confirmed that the `KUBE-LOOP-BACK` IPset contains all possible cases where the Packet's Src IP and Dest IP can be the same Pod's IP.

## 5. References

* [https://www.slideshare.net/Docker/deep-dive-in-container-service-discovery](https://www.slideshare.net/Docker/deep-dive-in-container-service-discovery)
* [http://www.system-rescue-cd.org/networking/Load-balancing-using-iptables-with-connmark/](http://www.system-rescue-cd.org/networking/Load-balancing-using-iptables-with-connmark/)
* [https://kubernetes.io/docs/concepts/services-networking/service/](https://kubernetes.io/docs/concepts/services-networking/service/)
* [https://kubernetes.io/docs/tutorials/services/source-ip/](https://kubernetes.io/docs/tutorials/services/source-ip/)

