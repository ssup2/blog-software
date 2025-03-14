---
title: Kubernetes Cilium Plugin
---

Kubernetes Network Plugin인 Cilium을 분석한다.

## 1. Cilium

{{< figure caption="[Figure 1] Cilium 구성요소" src="images/cilium-components.png" width="800px" >}}

Cilium은 **BPF (Berkeley Packet Filter)**를 기반으로 Pod Network를 구축하는 CNI Plugin이다. Kubernetes의 Network Plugin으로 많이 이용되고 있다. [Figure 1]은 Kubernetes의 Plugin으로 동작하는 Cilium의 구성요소를 나타내고 있다.

* Kubernetes API Server : Cilium은 Network 설정에 필요한 Pod, Service, Network Policy와 같은 정보를 Kubernetes API Server에게 얻어온다.

* Key-value Store : Cilium은 Cilium Component들이 공유하여 이용해야할 정보를 별도의 Key-value Store에 저장하고 이용한다. Cilium 내부에서 관리하는 Policy Identitiy나 VXLAN 이용시 필요한 VTEP (VXLAN Tunnel End Point) 정보들을 Key-value Store에 저장한다. 일반적으로는 etcd를 Key-value Store로 이용한다.

* cilium-agent : cilium-agent는 DaemonSet를 통해서 모든 Host(Node)에서 동작하며 각 Host의 Network 설정 및 Network Monitoring을 수행한다. Host Network Namespace에서 동작한다. Kubernetes API Server 또는 Key-value Store로부터 필요한 정보를 얻어 Host의 Network를 설정한다. 필요에 따라서 동적으로 BPF Program을 Compile 하고 결과물을 BPF에 삽입하여 동작시킨다.

* cilium : cilium은 cilium-agent의 CLI 역활을 수행한다. cilium-agent와 통신하며 cilium-agent를 제어하거나 cilium-agent이 가지고 있는 정보들을 출력하는 역활을 수행한다.

* BPF : BPF는 cilium-agent가 Compile한 Program을 실행하여 Linux Kernel Level에서 Packet Routing 및 Filtering을 수행한다. Cilium은 BPF 이용을 통해서 Netfilter Framework 및 Routing Table의 사용을 최소화하여 Network 성능을 끌어올린다.

* cilium-operator : cilium-operator는 Deployment를 통해서 동작하며 Cluster에서 한번만 Action이 필요한 동작의 경우 모두 cilium-operator가 수행한다. 예를들어 Cluster에서 Host(Node)가 제거 되었을때 제거된 Host와 관련된 정보를 Key-value Store에서 제거하는 GC 역활을 cilium-operator가 수행한다. 다수의 cilium-operator가 동작하는 경우 Active-standby 형태로 동작하며 HA를 수행한다.

### 1.1. Pod Network

Cilium은 Pod Network를 구축하는 방법으로 VXLAN 기반의 기법과 Host Network를 그대로 이용하는 기법 2가지를 제공한다.

#### 1.1.1. with VXLAN

{{< figure caption="[Figure 2] Cilium VXLAN Pod Network" src="images/cilium-network-vxlan.png" width="900px" >}}

[Figure 2]는 Cilium과 VXLAN을 이용하여 구축한 Default Pod Network를 나타낸다. Host의 Network는 10.0.0.0/24이고, Pod Network는 10.244.0.0/16이다. Cilium은 etcd에 저장된 정보를 바탕으로 각 Host에 Pod Network를 할당한다. 그림에서 Host 1은 192.167.2.0/24 Network가 할당되었다. 따라서 Host 1에 생긴 Pod A의 IP는 192.167.2.0/24 Network에 속한 IP인 192.167.2.10을 이용한다. Host 2에는 192.167.3.0/24 Network가 할당되었기 때문에 Host 2에 생긴 Pod C의 IP는 192.167.3.0/24 Network에 속한 IP인 192.167.3.10를 이용한다.

Pod Network 구축시 이용하는 주요 BPF는 VXLAN Interface에 붙는 SCHED-CLS Ingress BPF, Pod의 veth Interface에 붙는 SCHED-CLS Ingress BPF, Cilium을 위해 Host에 생성한 veth Inteface인 cilium-host에 붙는 SCHED-CLS Egress BPF, 3가지 BPF가 이용된다. cilium-host Interface와 짝을 이루는 veth Interface는 cilium-net Interface이다. 따라서 따라서 cilium-host Interface로 전달된 Packet은 cilium-host에 붙는 SCHED-CLS Egress BPF에 의해서 Packet이 Routing 되지 않는다면, cilium-net Interface로 나와서 Host Network Namespace를 이용하는 Pod로 전달된다.

Pod Network Namespace를 이용하는 Pod들 사이에 Packet을 주고 받을때는 Host의 Routing Table 및 cilium-host/cilium-net Interface를 이용하지 않고 Packet을 Routing한다. [Figure 2]에서 Pod A에서 Pod B로 Packet을 전송하는 경우 Pod A의 veth Interface에 붙는 SCHED-CLS Ingress BPF로 인해서 Pod B로 Packet이 바로 전송된다. Pod A에서 Pod F로 Packet을 전송하는 경우 Pod A의 veth Interface에 붙는 SCHED-CLS Ingress BPF는 cilium-vxlan Interface로 Packet을 바로 전송하여 Packet을 Host 2의 cilium-vxlan Interface로 전송한다. 이후에 cilium-vxlan Interface에 붙는 SCHED-CLS Ingress BPF에 의해서 Packet은 Pod F로 바로 전송된다.

Pod Network Namespace를 이용하는 Pod와 Host Network Namespace를 이용하는 Pod 사이에 Packet을 주고 받을때는 Host의 Host의 Routing Table 및 cilium-host/cilium-net Interface를 이용한다. [Figure 2]에서 Pod A에서 Pod C로 Packet을 전송하는 경우 Packet은 Host 1의 Routing Table로 전달되고, Host 1의 Routing Table에 따라서 cilium-host Interface로 전달된다. 이후 Packet은 cilium-net Interface로 나와서 Pod C로 전달된다. Pod A에서 Pod F로 전송하는 Packet을 전송하는 경우 Packet은 Host 1의 cilium-vxlan Interface를 통해서 Host 2의 cilium-vxlan Interface로 나오고, Host 2의 Routing Table에 의해서 cilium-host/cilium-net Interface 통해서 Pod F로 전달된다. 

Pod C에서 Pod A로 Packet을 전송하는 경우 Packet은 Host 1의 Routing Table에 따라서 cilium-host Interface에 전달되는데 이때 cilium-host에 붙는 SCHED-CLS Egress BPF에 의해서 Packet은 Pod A로 바로 전달된다. Pod C에서 Pod D로 Pacekt으 전송하는 경우 Packet은 Host 1의 Routing Table에 따라서 cilium-host Interface에 전달되는데 이때 cilium-host에 붙는 SCHED-CLS Egress BPF에 의해서 Packet은 Host 1의 cilium-vxlan Interface를 통해서 Host 2의 cilium-vxlan Interface로 전송된다. 이후에 cilium-vxlan Interface에 붙는 SCHED-CLS Ingress BPF에 의해서 Packet은 Pod D로 바로 전송된다.

Pod가 이용한는 Network Namespace에 관계없이 Pod에서 전송한 Packet이 Pod가 아닌 Cluster 외부로 전송될 경우, Packet은 Host의 Routing Table에 의해서 Routing 되어 Host 밖으로 전송된다. [Figure 2]에서는 Default Gateway가 eth0이기 때문에 Packet은 eth0를 통해서 Cluster 외부로 전송된다. Cilium의 설정에 따라서 [Figure 2]와 다른 Pod Network가 생성될 수 있다. 예를들어 Cilium이 IPsec을 이용하도록 설정되어 있다면 Pod의 veth Interface에 붙는 SCHED-CLS Ingress BPF에서 Packet의 목적지에 관계없이 Packet을 무조건 Host의 Routing Table을 통해서 전송하도록 설정한다.

```text {caption="[Shell 1] Cilium Endpoint", linenos=table}
# cilium map get cilium-lxc
Key               Value                                                                               State   Error
30.0.0.160:0      (localhost)                                                                         sync
192.167.1.138:0   (localhost)                                                                         sync
192.167.1.235:0   id=829   flags=0x0000 ifindex=8   mac=F2:EC:03:FC:7A:BF nodemac=FA:7D:9E:AF:1E:01   sync
192.167.1.139:0   id=53    flags=0x0000 ifindex=10  mac=DE:B8:9A:BA:37:5E nodemac=D6:EB:D8:44:E9:AD   sync    
# cilium endpoint list
ENDPOINT   POLICY (ingress)   POLICY (egress)   IDENTITY   LABELS (source:key[=value])                       IPv6   IPv4            STATUS
           ENFORCEMENT        ENFORCEMENT
691        Disabled           Disabled          32535      k8s:io.cilium.k8s.policy.cluster=default                 192.167.2.176   ready
                                                           k8s:io.cilium.k8s.policy.serviceaccount=default
                                                           k8s:io.kubernetes.pod.namespace=default
                                                           k8s:run=my-nginx
2296       Disabled           Disabled          104        k8s:io.cilium.k8s.policy.cluster=default                 192.167.2.194   ready
                                                           k8s:io.cilium.k8s.policy.serviceaccount=coredns
                                                           k8s:io.kubernetes.pod.namespace=kube-system
                                                           k8s:k8s-app=kube-dns
3424       Disabled           Disabled          104        k8s:io.cilium.k8s.policy.cluster=default                 192.167.2.32    ready
                                                           k8s:io.cilium.k8s.policy.serviceaccount=coredns
                                                           k8s:io.kubernetes.pod.namespace=kube-system
                                                           k8s:k8s-app=kube-dns
3787       Disabled           Disabled          4          reserved:health                                          192.167.2.88    ready 
```

Cilium은 Cilium이 이용하는 etcd에는 **Endpoint**라는 이름으로 Cilium이 관리하는 모든 Pod의 IP, MAC을 저장하고 관리하고 있다. cilium-agent는 BPF Map을 통해 Endpoint 정보를 BPF에 전달하여 BPF가 Routing을 수행할 수 있도록 한다. [Shell 1]은 'cilium map get cilium-lxc' 또는 'cilium endpoint list' 명령어를 이용하여 특정 Host에 있는 모든 Pod의 IP를 조회하는 Shell의 모습을 나타내고 있다.

#### 1.1.2. with Host L3

{{< figure caption="[Figure 3] Cilium Host L3 Pod Network" src="images/cilium-network-host.png" width="900px" >}}

[Figure 3]은 Cilium과 Host L3 Network를 이용하여 구축한 Pod Network를 나타낸다. 각 Host에 할당된 Pod Network, Host IP, Pod IP는 [Figure 2]의 예제와 동일하다. VXLAN을 이용할 때와 차이점은 VXLAN Interface 및 VXLAN Interface에 붙는 SCHED-CLS Ingress BPF가 존재하지 않는다. 또한 Routing Table도 VXLAN을 이용할 때와 다르다. Host의 Routing Table에는 각 Host에게 할당된 Pod Network 관련 Rule만 있는걸 확인할 수 있다.

[Figure 3]에서 Host 1의 Routing Table에는 Host 1에 할당된 Pod Network인 192.167.2.0/24 관련 Rule만 있지 Host 2에 할당된 Pod Network인 192.167.3.0/24 관련 Rule은 없는것을 확인할 수 있다. 따라서 서로 다른 Host에 위치한 Pod 사이에 전송되는 Packet은 Host Network의 설정에 따라서 전송된다. [Figure 3]에서는 eth0 Inteface를 통해서 Host Network가 구성되어 있고 eth0 Interface가 Default GW로 설정되어 있기 때문에, Host 1,2 모두 eth0 Interface를 통해서 Pod의 Packet을 주고받는다.

VXLAN을 이용할 때와 다른 또하나의 차이점은 Pod가 이용하는 Network Namespace에 관계없이 Pod에서 전송한 Packet이 Host의 Routing Table을 통해서 전송된다는 점이다. 이외에는 VXLAN을 이용할 때와 크게 다르지 않다. Cilium의 설정에 따라서 [Figure 3]과 다른 Pod Network가 생성될 수 있다.

### 1.2. Connection Tracking

```text {caption="[Shell 2] Cilium Connection Info", linenos=table}
# cilium bpf ct list global
TCP IN 192.167.0.113:58044 -> 192.167.0.175:8080 expires=247809 RxPackets=6 RxBytes=525 RxFlagsSeen=0x1b LastRxReport=247799 TxPackets=4 TxBytes=409 TxFlagsSeen=0x1b LastTxReport=247799 Flags=0x0013 [ RxClosing TxClosing SeenNonSyn ] RevNAT=0 SourceSecurityID=1
TCP OUT 30.0.0.34:59050 -> 192.168.0.40:8774 expires=246703 RxPackets=4 RxBytes=2436 RxFlagsSeen=0x13 LastRxReport=246693 TxPackets=5 TxBytes=761 TxFlagsSeen=0x1b LastTxReport=246693 Flags=0x0013 [ RxClosing TxClosing SeenNonSyn ] RevNAT=0 SourceSecurityID=0
ICMP OUT 30.0.0.34:49527 -> 30.0.0.79:0 expires=258603 RxPackets=1 RxBytes=50 RxFlagsSeen=0x00 LastRxReport=258543 TxPackets=1 TxBytes=50 TxFlagsSeen=0x00 LastTxReport=258543 Flags=0x0000 [ ] RevNAT=0 SourceSecurityID=0
ICMP IN 192.167.1.109:25170 -> 192.167.0.76:0 expires=256931 RxPackets=1 RxBytes=50 RxFlagsSeen=0x00 LastRxReport=256871 TxPackets=1 TxBytes=50 TxFlagsSeen=0x00 LastTxReport=256871 Flags=0x0000 [ ] RevNAT=0 SourceSecurityID=1
ICMP IN 30.0.0.160:0 -> 30.0.0.34:58168 expires=250323 RxPackets=1 RxBytes=50 RxFlagsSeen=0x00 LastRxReport=250263 TxPackets=0 TxBytes=0 TxFlagsSeen=0x00 LastTxReport=0 Flags=0x0000 [ ] RevNAT=0 SourceSecurityID=0
```

Cilium은 Pod의 Connection 정보를 Linux conntrack을 이용하지 않고 BPF와 BPF MAP을 이용하여 직접 관리한다. [Shell 2]는 'cilium bpf ct list global' 명령어를 이용하여 BPF Map에 저장되어 있는 Connection 정보를 출력하는 Shell을 나타내고 있다.

### 1.3. Service Load Balancing

```text {caption="[Shell 3] Cilium Service", linenos=table}
# cilium service list
ID   Frontend           Backend
1    10.96.0.10:53      1 => 192.167.2.194:53
                        2 => 192.167.2.32:53
2    10.96.0.10:9153    1 => 192.167.2.194:9153
                        2 => 192.167.2.32:9153
3    10.96.0.1:443      1 => 30.0.0.34:6443
4    10.97.188.211:80   1 => 192.167.1.139:80
                        2 => 192.167.2.176:80
5    10.109.68.251:80   1 => 30.0.0.160:80
                        2 => 30.0.0.79:80  
6    30.0.0.160:30381   1 => 192.167.2.32:80
                        2 => 192.167.2.194:80
7    192.168.0.101:80   1 => 192.167.2.32:80
                        2 => 192.167.2.194:80
```

Cilium에서 제공하는 추가적인 기능중 하나는 Service Load Balancing을 지원한다는 점이다. Cilium은 Kubernetes API Server로부터 Service 정보를 얻어 Cilium이 이용하는 etcd에 저장한다. [Shell 3]은 'cilium service list' 명령어를 이용하여 Cilium의 etcd에 저장되어 있는 Service 정보를 출력하는 Shell을 나타내고 있다. Frontent는 Kubernetes Service의 Cluster IP를 의미하고, Backend는 해당 Service에 소속되어 있는 Pod의 IP를 의미한다. Cilium의 BPF는 BPF Map의 Service 정보를 바탕으로 전달 받은 Packet의 Dest IP가 Service의 Cluster IP인 경우, 해당 Packet의 Dest IP를 Service와 연결된 Pod의 IP로 **DNAT**하여 Load Balancing을 수행한다.

Load Balancing Algorithm은 **Random 방식**과 Cilium이 저장하는 Connection 정보를 기반으로 하는 **Affinity 방식을** 혼용한다. Cilium은 Pod에서 Service로 전송시 BPF Map에 출발지 Pod과 목적지 Service에 소속된 임의의 Pod 사이의 Connection 정보가 있는지 확인한다. 관련 Connection 정보가 없다면 Cilium은 목적지 Service에 소속된 임의의 Pod을 선택하여 Packet을 전송하고 관련 Connection 정보를 BPF MAP에 추가한다. 관련 Connection 정보가 있다면 Connection 정보에 따라서 이전에 Packet을 전송했던 Pod으로 Packet을 다시 전송한다.

Cilium 17.XX 이전 Version의 경우에 Cilium은 ClusterIP Type의 Service만 Load Balancing을 지원하였지만, Cilium 17.XX 이후 Version에서는 NodePort, Loadbalancer Type의 Service의 Load Balancing도 지원한다.

#### 1.3.1. with VXLAN

{{< figure caption="[Figure 3] Cilium Service Load Balancing with VXLAN" src="images/cilium-service-vxlan.png" width="900px" >}}

[Figure 3]은 VXLAN을 이용할 경우의 Service Load Balancing 과정을 나타내고 있다. Pod Network Namespace를 이용하는 Pod에서 Service의 Cluster IP로 Packet을 전송할 경우, 전송한 Packet은 Pod의 veth Interface에 붙는 SCHED-CLS Ingress BPF에서 DNAT된다. SNAT는 응답 Packet을 전송한 Pod의 위치에 따라서 veth Interface의 SCHED-CLS Ingress BPF 또는 cilium-vxlan의 SCHED-CLS Ingress BPF에서 SNAT 된다.

Host Network Namespace를 이용하는 Pod에서 Service의 Cluster IP로 Packet을 전송하는 경우에는 기본적으로 kube-proxy가 설정하는 iptables 또는 IPVS를 이용하여 DNAT를 수행한다. 하지만 cilium 16.xx 이후 Version의 경우에는 CGROUP-SOCK-ADDR BPF를 이용하여 DNAT를 수행할 수 있는 기능이 추가 되었다. 물론 CGROUP-SOCK-ADDR BPF를 지원하는 Kernel Version에서만 이용할 수 있다. SNAT는 응답 Packet을 전송한 Pod의 위치에 따라서 veth Interface의 SCHED-CLS Ingress BPF 또는 cilium-host의 SCHED-CLS Egress BPF에서 SNAT 된다.

#### 1.3.2. with Host L3

{{< figure caption="[Figure 4] Cilium Service Load Balancing with Host L3" src="images/cilium-service-host.png" width="900px" >}}

[Figure 4]는 Host L3 Network을 이용할 경우의 Service Load Balancing 과정을 나타내고 있다. Pod Network Namespace를 이용하는 Pod에서 Service의 Cluster IP로 Packet을 전송할 경우 Service와 연결된 Pod이 외부에 있다면, SNAT가 cilium-host의 SCHED-CLS Egress BPF에서 수행된다는 점을 제외하고는 VXLAN을 이용할 때와 크게 다르지 않다.

### 1.4. Filtering

Cilium에서 제공하는 추가적인 기능중 하나는 Packet Filtering이다. Cilium의 Filtering 기법은 Cilium에서 제공하는 CiliumNetworkPolicy CRD를 통해서 정의하는 Network Policy 기법과 XDP를 이용하는 Prefileter 기법 두가지가 존재한다.

#### 1.4.1. Network Policy

```text {caption="[Shell 4] Cilium Network Policy", linenos=table}
# cilium policy get
[
  {
    "endpointSelector": {
      "matchLabels": {
        "any:org": "ssup2",
        "k8s:io.kubernetes.pod.namespace": "default"
      }
    },
    "ingress": [
      {
        "fromEndpoints": [
          {
            "matchLabels": {
              "any:org": "ssup2",
              "k8s:io.kubernetes.pod.namespace": "default"
            }
          }
        ],
        "toPorts": [
          {
            "ports": [
              {
                "port": "80",
                "protocol": "TCP"
...  
]
```

Cilium이 설치되면 **CiliumNetworkPolicy** CRD를 이용하여 Network Policy를 정의할 수 있다. Network Policy을 통해서 L3, L4, L7 Level Packet Filtering Rule을 정의할 수 있다. [Shell 4]는 정의된 Network Policy를 'cilium policy get' 명령어를 통해서 확인하는 Shell의 모습을 나타내고 있다. 정의된 Network Policy는 [Figure 1] 또는 [Figure 2]에 나타난 모든 BPF에서 Packet을 전송할때 적용된다.

#### 1.4.2. Prefilter

{{< figure caption="[Figure 5] Cilium Prefilter" src="images/cilium-prefilter.png" width="900px" >}}

Cilium은 XDP (eXpress Data Path)를 이용한 Packet Filteirng 기능도 제공한다. Cilium에서는 Prefilter라고 호칭한다. Kubernets Cluster Network를 구성하는 NIC의 Interface에 XDP BPF를 삽입시켜 동작한다. Generic XDP, Native XDP 2가지 방식 모두 제공한다. prefilter를 통해서 CIDR로 설정한 특정 Network의 Packet만 받도록 설정할 수 있다. prefilter 설정은 cilium-agent의 Config를 통해서 진행이 가능하다.

## 2. 참조

* [https://docs.cilium.io/en/v1.4/concepts/](https://docs.cilium.io/en/v1.4/concepts/) 
* [https://docs.cilium.io/en/v1.4/architecture/](https://docs.cilium.io/en/v1.4/architecture/)
* [https://github.com/cilium/cilium/commit/5e3e420f7927647b780c01d986ecaeff1bf32846#diff-9c45a228401ffc83c5c6ad50c7cc825b](https://github.com/cilium/cilium/commit/5e3e420f7927647b780c01d986ecaeff1bf32846#diff-9c45a228401ffc83c5c6ad50c7cc825b)
* [https://github.com/cilium/cilium/tree/master/monitor](https://github.com/cilium/cilium/tree/master/monitor)
* [https://ddiiwoong.github.io/2018/cilium-1/](https://ddiiwoong.github.io/2018/cilium-1/)
* [https://github.com/cilium/cilium/commit/b52130c55ee68a3de08125d29a91953de092338f#diff-01a7217c02bf211c22c4c232517f2dfb](https://github.com/cilium/cilium/commit/b52130c55ee68a3de08125d29a91953de092338f#diff-01a7217c02bf211c22c4c232517f2dfb)
* [https://kccncna19.sched.com/event/Uae7](https://kccncna19.sched.com/event/Uae7)
* [https://docs.cilium.io/en/v1.6/gettingstarted/host-services/](https://docs.cilium.io/en/v1.6/gettingstarted/host-services/)