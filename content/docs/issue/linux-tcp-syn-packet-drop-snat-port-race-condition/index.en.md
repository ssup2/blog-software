---
title: Linux TCP SYN Packet Drop with SNAT Port Race Condition
---

This content is organized based on the article at https://tech.xing.com/a-reason-for-unexplained-connection-timeouts-on-kubernetes-docker-abd041cf7e02.

## 1. Issue

There is an issue where TCP SYN packets are dropped due to a race condition that occurs in the process of selecting the Src Port number set in the TCP SYN packet while performing SNAT when sending TCP SYN packets through SNAT to establish TCP connections. When TCP SYN packets are dropped, TCP connections are established with a delay of at least 1 second, causing clients to experience timeouts.

When most Docker containers establish TCP connections with servers outside the Docker host, the TCP SYN packets sent by Docker containers are SNATed by the Docker host and sent externally, so this issue can occur. Similarly, when most Kubernetes pod containers establish TCP connections with servers outside the Kubernetes cluster, the TCP SYN packets sent by Kubernetes pod containers are SNATed and sent externally, so this issue can occur.

## 2. Cause and Solution

Linux provides the Masquerade technique, which is an SNAT technique that changes the Src IP of packets to the IP of the interface through which packets are sent when sending packets externally through the iptables command. At this time, the Src Port number is also changed to an arbitrary port number that is not being used on the host.

When multiple threads within one process simultaneously try to establish TCP connections to the same external server (same IP, port) through the Masquerade technique, multiple TCP SYN packets are SNATed through the Masquerade technique. At this time, **the Src Port number of each TCP SYN packet must be changed to a different port number**. This is because only then can we identify which TCP connection the response is for when a response comes from the external server.

However, **due to a kernel bug, when TCP SYN packets are sent simultaneously, the Src Port number of each TCP SYN packet can be changed to the same port number**. Among the TCP SYN packets whose Src Port has been changed to the same port number, all TCP SYN packets except the first processed TCP SYN packet are dropped by Linux conntrack's duplicate connection prevention logic.

The kernel bug related to this issue has not been resolved yet. Therefore, currently, there is no other way than to set the Src Port number allocated by the Masquerade technique to minimize duplication. The default algorithm for allocating Src Port numbers through the Masquerade technique starts from the last allocated port number and increases one by one, checking if the port number is in use, and if not in use, allocates it. Therefore, the default method has a high probability of allocating duplicate Src Port numbers when Src Port number allocation requests come in simultaneously.

The kernel has NF_NAT_RANGE_PROTO_RANDOM Algorithm and NF_NAT_RANGE_PROTO_RANDOM_FULLY Algorithm that allocate Src Port numbers randomly to solve this problem. The NF_NAT_RANGE_PROTO_RANDOM_FULLY Algorithm was created to improve the NF_NAT_RANGE_PROTO_RANDOM Algorithm. Therefore, **by allocating Src Port randomly through the NF_NAT_RANGE_PROTO_RANDOM_FULLY Algorithm, Src Port duplication can be prevented** to reduce the probability of TCP SYN packet drops. However, this is not a method that can solve this issue 100%.

To apply the NF_NAT_RANGE_PROTO_RANDOM_FULLY Algorithm to the Masquerade technique, you can add the `--random-fully` option when adding a Masquerade rule with the iptables command. The `--random-fully` option is supported from iptables v1.6.2 version.

## 3. with Kubernetes

```shell {caption="[Shell 1] KUBE-POSTROUTING Chain without --random-fully Option applied"}
# iptables -t nat -nvL
...
Chain KUBE-POSTROUTING (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service traffic requiring SNAT */ mark match 0x4000/0x4000
...
```

```shell {caption="[Shell 2] KUBE-POSTROUTING Chain with --random-fully Option applied"}
# iptables -t nat -nvL
...
Chain KUBE-POSTROUTING (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service traffic requiring SNAT */ mark match 0x4000/0x4000 random-fully
...
```

From Kubernetes v1.16.0 version, to solve this issue, if the iptables command supports the `--random-fully` option, the `--random-fully` option is applied to the Masquerade rule of the KUBE-POSTROUTING chain. [Shell 1] shows the KUBE-POSTROUTING chain without the `--random-fully` option applied, and [Shell 2] shows the chain with the `--random-fully` option applied. Also, some CNI plugins add Masquerade rules with the `--random-fully` option set to solve this issue. Flannel and Cilium CNI support the `--random-fully` option.

## 4. References

* [https://tech.xing.com/a-reason-for-unexplained-connection-timeouts-on-kubernetes-docker-abd041cf7e02](https://tech.xing.com/a-reason-for-unexplained-connection-timeouts-on-kubernetes-docker-abd041cf7e02)
* [https://github.com/kubernetes/kubernetes/pull/78547](https://github.com/kubernetes/kubernetes/pull/78547)
* [https://manpages.debian.org/unstable/iptables/iptables-extensions.8.en.html](https://manpages.debian.org/unstable/iptables/iptables-extensions.8.en.html)
* [https://patchwork.ozlabs.org/project/netfilter-devel/patch/1388963586-5049-7-git-send-email-pablo@netfilter.org/](https://patchwork.ozlabs.org/project/netfilter-devel/patch/1388963586-5049-7-git-send-email-pablo@netfilter.org/)
* [https://lwn.net/Articles/746343/](https://lwn.net/Articles/746343/)
* [https://github.com/coreos/flannel/commit/0d7b99460b81f98df43da183258edf56c4abf854](https://github.com/coreos/flannel/commit/0d7b99460b81f98df43da183258edf56c4abf854)
* [https://github.com/cilium/cilium/commit/4e39def13bca568a21087238877fbc60f8751567](https://github.com/cilium/cilium/commit/4e39def13bca568a21087238877fbc60f8751567)
