---
title: Kubernetes Connection Delay with VXLAN CNI Plugin
---

This content is organized based on the article at https://github.com/kubernetes/kubernetes/pull/92035.

## 1. Issue

There is an issue where TCP connections are delayed inside Kubernetes clusters when using VXLAN-based CNI plugins from Kubernetes v1.16 version. This issue mainly occurs when establishing TCP connections from hosts or pods using host network namespace to other pods.

## 2. Cause

```shell {caption="[Shell 1] Kubernetes iptables NAT Table"}
# iptables -t nat -nvL
...
Chain KUBE-MARK-MASQ (5 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x4000
...
Chain KUBE-POSTROUTING (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service traffic requiring SNAT */ mark match 0x4000/0x4000 random-fully
...
```

[Shell 1] shows part of the iptables NAT table of a Kubernetes cluster node. Kubernetes marks packets that need SNAT through Masquerade via the KUBE-MARK-MASQ chain, and performs SNAT on marked packets through the KUBE-POSTROUTING chain via Masquerade rules. You can see that the "--random-fully" option is included in the Masquerade rule, which is an option added to prevent source ports assigned to packets during SNAT from being duplicated due to race conditions.

When sending packets to pods through VXLAN tunnel interfaces inside Kubernetes clusters using VXLAN-based CNI (Container Network Interface) plugins, the packets pass through the kernel's network stack a total of 2 times and also pass through iptables tables 2 times. When packets pass through the network stack for the first time, they pass in the original packet state sent by the pod, and when packets pass through the network stack for the second time, they pass encapsulated as UDP by the VXLAN technique.

The problem occurs when packets are SNATed to the VXLAN tunnel interface's IP by the KUBE-MARK-MASQ and KUBE-POSTROUTING chain's Masquerade rules while passing through the VXLAN tunnel interface. Packets are SNATed once to the VXLAN tunnel interface's IP through the KUBE-MARK-MASQ chain and KUBE-POSTROUTING chain when passing through the iptables table for the first time. At this time, the mark left on the packet by the KUBE-MARK-MASQ chain remains when the packet passes through the iptables table for the second time. Therefore, packets are SNATed once more by the KUBE-POSTROUTING chain's Masquerade rule when passing through the iptables table for the second time.

If SNAT is performed once more, TCP/UDP checksum must be calculated once more, but there is a problem where TCP/UDP checksum is not calculated once more due to a kernel bug. If the "--random-fully" option is not applied to the Masquerade rule, even if packets SNATed to the VXLAN tunnel interface's IP are SNATed once more to the VXLAN tunnel interface's IP, the packet's Src IP and Src Port do not change, so the kernel's TCP/UDP checksum bug is not fatal. However, if the "--random-fully" option is applied to the Masquerade rule, the Src IP does not change during the second SNAT, but the Src Port changes, so the kernel's TCP/UDP checksum bug becomes a fatal bug. Packets with incorrect TCP/UDP checksums are dropped by the NIC that receives them.

In most VXLAN-based CNI plugins, when sending packets from pods to pods through VXLAN tunnel interfaces, packets are not SNATed to the VXLAN tunnel interface's IP but are sent with the pod's IP as the Src IP. Packets are SNATed to the VXLAN tunnel interface's IP when sending packets from hosts to pods through VXLAN tunnel interfaces, or when sending packets from pods using host network namespace to pods through VXLAN tunnel interfaces. **Therefore, this issue mainly occurs when using hosts or host network namespace.** The "--random-fully" option for Masquerade rules has been applied since Kubernetes v1.16 version. Therefore, this issue does not occur in versions before v1.16.

## 3. Solution

### 3.1 Kubernetes Patch

```shell {caption="[Shell 2] Kubernetes iptables nat Table with Patch Applied"}
# iptables -t nat -nvL
...
Chain KUBE-MARK-MASQ (11 references)
 pkts bytes target     prot opt in     out     source               destination
   12   720 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x4000
...
Chain KUBE-POSTROUTING (1 references)
 pkts bytes target     prot opt in     out     source               destination
   38  2512 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            mark match ! 0x4000/0x4000
    6   360 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK xor 0x4000
    6   360 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service traffic requiring SNAT */ random-fully
...
```

Kubernetes' KUBE-POSTROUTING chain rules have been patched to prevent a single packet from being SNATed twice. [Shell 2] shows part of the iptables nat table of a Kubernetes cluster node with the patch applied. You can see that the packet's mark is removed through the "xor 0x4000" option before applying the Masquerade rule to the packet in the KUBE-POSTROUTING chain. Therefore, when packets pass through the iptables table for the second time, they are not affected by the KUBE-POSTROUTING chain's Masquerade rule, and packets are SNATed only once by the KUBE-POSTROUTING chain's Masquerade rule when passing through the iptables table for the first time.

Since SNAT is performed only once, even if you use a kernel with the kernel's TCP/UDP checksum bug, the TCP/UDP checksum bug does not actually occur. Therefore, no kernel patch is needed when using patched Kubernetes. The Kubernetes versions with patches applied are as follows.

* v1.16.13+
* v1.17.9+
* v1.18.6+

### 3.2. Kernel Patch

You can apply a kernel that fixes the following bug.

* netfilter: nat: never update the UDP checksum when it's 0
  * [https://www.spinics.net/lists/netdev/msg648256.html](https://www.spinics.net/lists/netdev/msg648256.html)

The kernel versions with UDP checksum bug fixes are as follows.

* Linux Longterm
  * 4.14.181+
  * 4.19.123+
  * 5.4.41+
* Distro Linux Kernel
  * Ubuntu : 4.15.0-107.108, 5.4.0-32.36+

### 3.3. Checksum Offload Disable

Turn off the TCP/UDP checksum offload function so that TCP/UDP checksum is not performed on the NIC. You need to turn off the TCP/UDP checksum offload function on all nodes in the cluster. The method to turn off the TCP/UDP checksum offload function in Linux is as follows. You can turn off the TCP/UDP checksum offload function through the `ethtool --offload eth0 rx off tx off` command.

## 4. References

* [https://github.com/kubernetes/kubernetes/pull/92035](https://github.com/kubernetes/kubernetes/pull/92035)
* [https://github.com/kubernetes/kubernetes/issues/88986#issuecomment-640929804](https://github.com/kubernetes/kubernetes/issues/88986#issuecomment-640929804)
* [https://github.com/kubernetes/kubernetes/issues/90854](https://github.com/kubernetes/kubernetes/issues/90854)
* [https://github.com/kubernetes/kubernetes/pull/78547](https://github.com/kubernetes/kubernetes/pull/78547)
* [https://tech.xing.com/a-reason-for-unexplained-connection-timeouts-on-kubernetes-docker-abd041cf7e02](https://tech.xing.com/a-reason-for-unexplained-connection-timeouts-on-kubernetes-docker-abd041cf7e02)
* [https://www.spinics.net/lists/netdev/msg648256.html](https://www.spinics.net/lists/netdev/msg648256.html)
* [https://github.com/kubernetes/kubernetes/tree/master/CHANGELOG](https://github.com/kubernetes/kubernetes/tree/master/CHANGELOG)
