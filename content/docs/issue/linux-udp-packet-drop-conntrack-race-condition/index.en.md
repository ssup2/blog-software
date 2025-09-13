---
title: Linux UDP Packet Drop with conntrack Race Condition
---

This content is organized based on the article at https://www.weave.works/blog/racy-conntrack-and-dns-lookup-timeouts.

## 1. Issue

There is an issue where UDP packets are dropped due to a race condition in Linux conntrack. In Kubernetes clusters, this issue can cause temporary service discovery failures.

## 2. Background

* Src 10.0.0.10:10, Dst 20.0.0.20:20
  * Original Table : Src 10.0.0.10:10, Dst 20.0.0.20:20
  * Reply Table : Src 20.0.0.20:20, Dst 10.0.0.10:10

Linux conntrack uses two tables, Original Table and Reply Table, when storing one connection information. The above example shows the contents of conntrack's Original Table and Reply Table according to the packet's Src and Dst IP/Port. The Original Table is filled with the same content as the packet's Src and Dst IP/Port. You can see that the Reply Table content is just the Src and Dst positions swapped from the Original Table.

* Src 10.0.0.10:10, Dst 20.0.0.20:20, DNAT 20.0.0.20->30.0.0.30:30
  * Original Table : Src 10.0.0.10:10, Dst 20.0.0.20:20
  * Reply Table : Src 30.0.0.30:30, Dst 10.0.0.10:10

The above example is the same as the first example but shows the state when a DNAT rule is set for the Dst IP/Port. The Original Table is filled with the same content as the packet's Src and Dst IP/Port. You can see that the Reply Table's Src IP/Port is not the same as the Original Table's Dst IP/Port due to the influence of the DNAT rule. Like this, conntrack stores connection information reflecting NAT rules to perform fast reverse NAT.

TCP connection information is stored in conntrack when the connection is created. In the case of UDP, since it is a connection-less protocol, there is no connection, but conntrack creates and manages connection information based on the Src and Dst IP/Port information of UDP packets to perform operations such as reverse NAT of UDP packets. The time when UDP connection information is stored in conntrack is when the actual UDP packet is sent.

conntrack checks the Original Table and Reply Table every time it adds connection information to verify whether the connection to be added is valid. If the connection information to be added duplicates with the Original Table or Reply Table, conntrack considers that connection information invalid and does not add it to the table. Also, conntrack drops the packet that had the connection information to be added.

## 3. Cause and Solution

Since UDP connection information is stored in conntrack when the actual UDP packet is sent, a race condition occurs in conntrack when multiple threads in the same process simultaneously send UDP packets to the same counterpart through one socket (using the same port). In this case, all sent UDP packets should be sent to the counterpart, but conntrack discovers the same connection information of UDP packets and drops some UDP packets.

One more thing to consider is that even if an app sends multiple UDP packets simultaneously to the same counterpart, the packets may be sent to **different places** rather than the same place due to the kernel's DNAT rule on the host (node) where the app is running. DNAT rules affect the connection information to be stored in conntrack's Reply Table, but do not affect the connection information to be stored in conntrack's Original Table. Therefore, conntrack monitors conflicts in the Original Table and drops some UDP packets. The UDP packet drop issue that occurs when DNAT is not performed or when DNAT is performed but packets are sent to the same place has been resolved by the following kernel patch.

* [https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=ed07d9a021df6da53456663a76999189badc432a](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=ed07d9a021df6da53456663a76999189badc432a)

The UDP packet drop issue that occurs when DNAT is performed and packets are sent to different places has been partially resolved by the following kernel patch. However, it is not completely resolved.

* [https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=4e35c1cb9460240e983a01745b5f29fe3a4d8e39](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=4e35c1cb9460240e983a01745b5f29fe3a4d8e39)

The versions with the above two kernel patches applied are as follows.

* Linux Stable 
  * 5.0+
* Linux Longterm
  * 4.9.163+, 4.14.106+, 4.19.29+, 5.4+
* Distro Linux Kernel
  * Ubuntu : 4.15.0-56+

The issue that occurs when UDP packets are DNATed and sent to different counterparts has not been completely resolved in the kernel yet. Therefore, you need to prevent conntrack race conditions by restricting apps from sending UDP packets simultaneously through one socket, or bypass this issue by setting the kernel's DNAT rule so that UDP packets are sent to the same counterpart even when DNATed in the state where the above kernel patch is applied. Alternatively, you can prevent conntrack race conditions by using iptables' mangle table to set packets sent to specific IPs and ports not to be managed through conntrack.

## 4. DNS Timeout Issue with Kubernetes
 
Kubernetes performs service discovery using service records, and in Kubernetes environments, UDP packets generated during domain resolution may be dropped due to this issue, causing temporary service discovery failures. In Kubernetes, CoreDNS, which performs the DNS server role, is typically run in multiple instances on the master node and bundled as a service to provide to apps inside the Kubernetes cluster. Therefore, UDP packets sent to CoreDNS for domain resolution from apps are **DNATed** on the host (node) where the app pod is located and distributed to the master's CoreDNS.

Also, when performing domain resolution, glibc and musl, which are the most commonly used C libraries in apps, perform A Record and AAAA Record resolution simultaneously using the same socket (same port) if the kernel is configured to use both IPv4 and IPv6. In other words, A Record resolve packets and AAAA Record resolve packets sent by glibc or musl-based apps running in Kubernetes have the same Src IP/Port simultaneously and are sent to CoreDNS through DNAT, but due to this issue, one of the two resolve packets is dropped by conntrack.

Since DNAT does not occur in the pod's network namespace, this issue can be resolved in the pod's network namespace by using the kernel version with the patches mentioned above. **The problem is that the issue cannot be resolved even with the patches mentioned above in the host (node) where DNAT occurs, so workarounds must be applied to solve the problem.** The most intuitive approach is to prevent simultaneously performed domain resolution to prevent conntrack race conditions. glibc can be restricted from simultaneously resolving A Record and AAAA Record by giving "single-request" or "single-request-reopen" options in the /etc/resolv.conf file. However, musl does not support these options. musl is a C library used in Alpine images, which are used in many places.

Another workaround is to set domain resolve packets sent from one app to be DNATed to the same CoreDNS unconditionally. You can run only one CoreDNS so that domain resolve packets are sent to the same pod even when DNATed. Or you can use an algorithm that performs load balancing based on packet header hashing. If service load balancing is performed through IPVS in the Kubernetes cluster, you can use IPVS's load balancing algorithms dh (Destination Hashing Scheduling) and sh (Source Hashing Scheduling).

The final workaround is to prevent conntrack race conditions by setting domain resolve packets not to be managed by conntrack. The [LocalNode DNSCache](https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/) technique is a technique that bypasses this issue by using iptables' mangle table to prevent domain resolve packets from being managed by conntrack. You can avoid using conntrack by using Cilium CNI.

Cilium CNI uses BPF and BPF Map instead of conntrack for connection management between pod network namespaces and services. For connection management between pods using host network namespace or host processes and services, Cilium CNI versions (1.6.0+) that support cgroup eBPF use BPF and BPF Map instead of conntrack. Therefore, if you use Cilium CNI and kernel versions that support cgroup eBPF, you can bypass this issue.

## 5. References

* [https://www.weave.works/blog/racy-conntrack-and-dns-lookup-timeouts](https://www.weave.works/blog/racy-conntrack-and-dns-lookup-timeouts)
* [https://blog.quentin-machu.fr/2018/06/24/5-15s-dns-lookups-on-kubernetes/](https://blog.quentin-machu.fr/2018/06/24/5-15s-dns-lookups-on-kubernetes/)
* [https://github.com/kubernetes/kubernetes/issues/56903](https://github.com/kubernetes/kubernetes/issues/56903)
* [https://github.com/weaveworks/weave/issues/3287](https://github.com/weaveworks/weave/issues/3287)
* [http://patchwork.ozlabs.org/patch/937963](http://patchwork.ozlabs.org/patch/937963)
* [http://patchwork.ozlabs.org/patch/1032812](http://patchwork.ozlabs.org/patch/1032812)
* [https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns](https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns)
* [https://github.com/kubernetes/kubernetes/issues/56903#issuecomment-466368174](https://github.com/kubernetes/kubernetes/issues/56903#issuecomment-466368174)
* [https://blog.quentin-machu.fr/2018/06/24/5-15s-dns-lookups-on-kubernetes/](https://blog.quentin-machu.fr/2018/06/24/5-15s-dns-lookups-on-kubernetes/)
* [https://wiki.musl-libc.org/functional-differences-from-glibc.html](https://wiki.musl-libc.org/functional-differences-from-glibc.html)
* [https://launchpad.net/ubuntu/+source/linux/4.15.0-58.64](https://launchpad.net/ubuntu/+source/linux/4.15.0-58.64)
* [https://github.com/colopl/k8s-local-dns](https://github.com/colopl/k8s-local-dns)
* [https://kb.isc.org/docs/aa-01183](https://kb.isc.org/docs/aa-01183)
