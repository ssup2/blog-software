---
title: Linux Container TCP Connection Reset with Out of Order Delivery
---

This content is organized based on the article at https://github.com/moby/libnetwork/issues/1090.

## 1. Issue

There is an issue where TCP connections are reset due to out-of-order delivery when packets sent from containers to outside the host are **SNATed**. When a client runs inside a container and a server runs outside the host, packets sent by the client are SNATed and delivered outside the host. There is no problem when the container's client and the server outside the host send a small amount of packets for a short time like HTTP protocol, but **when establishing TCP connections for a long time and sending a large amount of packets**, the probability of this issue occurring is high.

In the case of Docker containers, this issue can occur because packets are SNATed when sending packets outside the host. Also, when most Kubernetes pod containers establish TCP connections with servers outside the Kubernetes cluster, this issue can occur because TCP SYN packets sent by Kubernetes pod containers are SNATed and sent externally.

## 2. Cause

During the process of establishing TCP connections between clients and servers and communicating, out-of-order delivery phenomena where the order of sent packets changes due to various external factors can occur. Due to out-of-order delivery phenomena, the ACK for the Sequence Number 90 packet that the client sent earlier can arrive at the client before the ACK for the Sequence Number 100 packet that the client sent.

The fact that the client received the ACK for the Sequence Number 100 packet from the server means that the server also received the Sequence Number 90 packet well according to the TCP protocol. Therefore, the ACK for the Sequence Number 90 packet received late by the client is considered a retransmitted packet due to TCP's Spurious Retransmission technique and is ignored by the kernel.

When packets sent by a client inside a container are SNATed to establish TCP connections with a server outside the host, packets sent by the server to the client must be DNATed and sent to the client. The problem is that when out-of-order delivery phenomena occur in ACKs sent by the server, the ACK is classified as an invalid packet due to a bug in Linux's conntrack module. ACKs that have become invalid by the conntrack module are not DNATed, so they are delivered to the host instead of the container. The host that receives the ACK forcibly terminates the connection with the server through the TCP Reset flag because it receives packets from connections it doesn't know.

```shell {caption="[Shell 1] Host Network Interface Packet Dump with tshark"}
...
117893 291.390819085 192.168.0.100 → 10.205.13.199 TCP 66 80 → 56284 [ACK] Seq=26 Ack=10069055 Win=173056 Len=0 TSval=3479336939 TSecr=499458820
117894 291.390838911 10.205.13.199 → 192.168.0.100 TCP 19790 56284 → 80 [ACK] Seq=10194987 Ack=26 Win=43008 Len=19724 TSval=499458821 TSecr=3479336939 [TCP segment of a reassembled PDU]
117895 291.390917661 192.168.0.100 → 10.205.13.199 TCP 66 80 → 56284 [ACK] Seq=26 Ack=10149475 Win=173056 Len=0 TSval=3479336939 TSecr=499458820
117896 291.390972667 10.205.13.199 → 192.168.0.100 TCP 64326 56284 → 80 [ACK] Seq=10214711 Ack=26 Win=43008 Len=64260 TSval=499458821 TSecr=3479336939 [TCP segment of a reassembled PDU]
117897 291.391007869 10.205.13.199 → 192.168.0.100 TCP 43626 [TCP Window Full] 56284 → 80 [ACK] Seq=10278971 Ack=26 Win=43008 Len=43560 TSval=499458821 TSecr=3479336939 [TCP segment of a reassembled PDU]
117898 291.391020119 192.168.0.100 → 10.205.13.199 TCP 66 80 → 56284 [ACK] Seq=26 Ack=10110467 Win=173056 Len=0 TSval=3479336939 TSecr=499458820
117899 291.391054153 10.205.13.199 → 192.168.0.100 TCP 54 56284 → 80 [RST] Seq=10110467 Win=0 Len=0
117900 291.391596495 192.168.0.100 → 10.205.13.199 TCP 66 80 → 56284 [ACK] Seq=26 Ack=10160447 Win=173056 Len=0 TSval=3479336939 TSecr=499458821
117901 291.391646840 192.168.0.100 → 10.205.13.199 TCP 66 80 → 56284 [ACK] Seq=26 Ack=10194987 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
117902 291.391676345 10.205.13.199 → 192.168.0.100 TCP 20766 56284 → 80 [ACK] Seq=10322531 Ack=26 Win=43008 Len=20700 TSval=499458822 TSecr=3479336940 [TCP segment of a reassembled PDU]
117903 291.391692731 192.168.0.100 → 10.205.13.199 TCP 66 80 → 56284 [ACK] Seq=26 Ack=10204983 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
117904 291.391798515 192.168.0.100 → 10.205.13.199 TCP 66 80 → 56284 [ACK] Seq=26 Ack=10214711 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
117905 291.391852326 192.168.0.100 → 10.205.13.199 TCP 66 80 → 56284 [ACK] Seq=26 Ack=10227563 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
117906 291.392008540 192.168.0.100 → 10.205.13.199 TCP 66 80 → 56284 [ACK] Seq=26 Ack=10256123 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
117907 291.392020293 192.168.0.100 → 10.205.13.199 TCP 66 80 → 56284 [ACK] Seq=26 Ack=10320383 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
117908 291.392092929 10.205.13.199 → 192.168.0.100 TCP 64326 56284 → 80 [ACK] Seq=10343231 Ack=26 Win=43008 Len=64260 TSval=499458822 TSecr=3479336940 [TCP segment of a reassembled PDU]
117909 291.392120048 10.205.13.199 → 192.168.0.100 TCP 64326 56284 → 80 [ACK] Seq=10407491 Ack=26 Win=43008 Len=64260 TSval=499458822 TSecr=3479336940 [TCP segment of a reassembled PDU]
117910 291.392134522 192.168.0.100 → 10.205.13.199 TCP 66 80 → 56284 [ACK] Seq=26 Ack=10322531 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
117911 291.392168474 10.205.13.199 → 192.168.0.100 HTTP 14302 PUT /v1/test/yanoo.kim/METAKAGEAPI-56/b019 HTTP/1.1
117912 291.392855855 192.168.0.100 → 10.205.13.199 TCP 54 80 → 56284 [RST] Seq=26 Win=8397824 Len=0
117913 291.392875260 192.168.0.100 → 10.205.13.199 TCP 54 80 → 56284 [RST] Seq=26 Win=8397824 Len=0
117914 291.392879867 192.168.0.100 → 10.205.13.199 TCP 54 80 → 56284 [RST] Seq=26 Win=8397824 Len=0
...
```

[Shell 1] is the result of dumping packets on the host interface using tshark when a connection reset occurred in a Docker container. 10.205.13.199 is the Docker container's client IP, and 192.168.0.100 is the server outside the host. It shows the Docker container's client establishing a TCP connection with the server outside the host and sending data, then experiencing a connection reset.

You can see in the 4th line of [Shell 1] that the server received the ACK for the Sequence Number 10149475 packet sent to the client. In the 7th line of [Shell 1], you can see that the ACK for the Sequence Number 10110467 packet was received. Since 10110467 is smaller than 10149475, the ACK for the Sequence Number 10110467 packet should originally be considered as TCP Spurious and ignored, but due to a bug in the conntrack module, it is considered an invalid packet and not DNATed.

Therefore, the ACK for the Sequence Number 10110467 packet is delivered to the host. The host determines that the ACK for the Sequence Number 10110467 packet is neither an ACK for packets it sent nor a packet from a TCP connection connected to itself through conntrack's connection information. Therefore, the host forcibly terminates the connection with the server through the TCP Reset flag. You can see the TCP Reset packet sent by the host to the server in the 8th line of [Shell 1]. After receiving the host's TCP Reset packet, the server sends a TCP Reset packet to the pod according to the TCP protocol.

```shell {caption="[Shell 2] Docker Container Network Interface Packet Dump with tshark"}
...
348997 1199.001039577 192.168.0.100 → 10.251.0.1   TCP 66 80 → 56284 [ACK] Seq=26 Ack=10069055 Win=173056 Len=0 TSval=3479336939 TSecr=499458820
348998 1199.001044501   10.251.0.1 → 192.168.0.100 TCP 19790 56284 → 80 [ACK] Seq=10194987 Ack=26 Win=43008 Len=19724 TSval=499458821 TSecr=3479336939 [TCP segment of a reassembled PDU]
348999 1199.001137509 192.168.0.100 → 10.251.0.1   TCP 66 80 → 56284 [ACK] Seq=26 Ack=10149475 Win=173056 Len=0 TSval=3479336939 TSecr=499458820
349000 1199.001142437   10.251.0.1 → 192.168.0.100 TCP 64326 56284 → 80 [ACK] Seq=10214711 Ack=26 Win=43008 Len=64260 TSval=499458821 TSecr=3479336939 [TCP segment of a reassembled PDU]
349001 1199.001173634   10.251.0.1 → 192.168.0.100 TCP 43626 [TCP Window Full] 56284 → 80 [ACK] Seq=10278971 Ack=26 Win=43008 Len=43560 TSval=499458821 TSecr=3479336939 [TCP segment of a reassembled PDU]
349002 1199.001829309 192.168.0.100 → 10.251.0.1   TCP 66 80 → 56284 [ACK] Seq=26 Ack=10160447 Win=173056 Len=0 TSval=3479336939 TSecr=499458821
349003 1199.001867310 192.168.0.100 → 10.251.0.1   TCP 66 80 → 56284 [ACK] Seq=26 Ack=10194987 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
349004 1199.001873632   10.251.0.1 → 192.168.0.100 TCP 20766 56284 → 80 [ACK] Seq=10322531 Ack=26 Win=43008 Len=20700 TSval=499458822 TSecr=3479336940 [TCP segment of a reassembled PDU]
349005 1199.001913499 192.168.0.100 → 10.251.0.1   TCP 66 80 → 56284 [ACK] Seq=26 Ack=10204983 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
349006 1199.002019049 192.168.0.100 → 10.251.0.1   TCP 66 80 → 56284 [ACK] Seq=26 Ack=10214711 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
349007 1199.002072808 192.168.0.100 → 10.251.0.1   TCP 66 80 → 56284 [ACK] Seq=26 Ack=10227563 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
349008 1199.002234891 192.168.0.100 → 10.251.0.1   TCP 66 80 → 56284 [ACK] Seq=26 Ack=10256123 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
349009 1199.002246041   10.251.0.1 → 192.168.0.100 TCP 64326 56284 → 80 [ACK] Seq=10343231 Ack=26 Win=43008 Len=64260 TSval=499458822 TSecr=3479336940 [TCP segment of a reassembled PDU]
349010 1199.002239068 192.168.0.100 → 10.251.0.1   TCP 66 80 → 56284 [ACK] Seq=26 Ack=10320383 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
349011 1199.002275354   10.251.0.1 → 192.168.0.100 TCP 64326 56284 → 80 [ACK] Seq=10407491 Ack=26 Win=43008 Len=64260 TSval=499458822 TSecr=3479336940 [TCP segment of a reassembled PDU]
349012 1199.002354715 192.168.0.100 → 10.251.0.1   TCP 66 80 → 56284 [ACK] Seq=26 Ack=10322531 Win=173056 Len=0 TSval=3479336940 TSecr=499458821
349013 1199.002360711   10.251.0.1 → 192.168.0.100 HTTP 14302 PUT /v1/test/yanoo.kim/METAKAGEAPI-56/b019 HTTP/1.1
349014 1199.003089773 192.168.0.100 → 10.251.0.1   TCP 54 80 → 56284 [RST] Seq=26 Win=8397824 Len=0
349015 1199.003094968 192.168.0.100 → 10.251.0.1   TCP 54 80 → 56284 [RST] Seq=26 Win=8397824 Len=0
349016 1199.003098534 192.168.0.100 → 10.251.0.1   TCP 54 80 → 56284 [RST] Seq=26 Win=8397824 Len=0
```

[Shell 2] is the result of dumping packets on the Docker container interface inside the Docker container using tshark when the connection reset phenomenon in [Shell 1] occurred. It is mostly the same as [Shell 1], but you can see that the ACK for the Sequence Number 10110467 packet does not exist. The ACK for the Sequence Number 10110467 packet was not delivered to the Docker container because it was considered an invalid packet due to a bug in the conntrack module on the host and was not DNATed.

You also cannot see the TCP Reset packet sent by the host. Inside the Docker container, it receives a TCP Reset packet from the server without knowing the existence of the TCP Reset packet sent by the host. Therefore, inside the Docker container, it determines that the server terminated the connection first and delivers a "connection reset by peer" error to the Docker container app.

## 3. Solution

There are 2 workarounds to solve this issue. Both workarounds are not perfect methods, and since they affect the entire system, sufficient review must be conducted before application.

* Execute the `echo 1 > /proc/sys/net/ipv4/netfilter/ip_conntrack_tcp_be_liberal` command

The first method makes conntrack not actually change to an invalid state even if it determines that a packet is invalid. Therefore, it can prevent connection reset occurrences by preventing packets sent by the server to the client from being delivered to the host without being DNATed. It affects not only containers but the entire system. When applied to Kubernetes, there is [feedback](https://github.com/kubernetes/kubernetes/pull/74840#issuecomment-491674987) that it fills conntrack's connection table and affects all connections in the system.

* Add iptables rules that drop invalid packets

The second method is to drop packets in an invalid state. In the case of Docker containers, you can drop packets in an invalid state by setting iptables rules through the `iptables -I INPUT -m conntrack --ctstate INVALID -j DROP` command. When the previous iptables rule is applied, in the case of [Shell 1], the ACK for the Sequence Number 10110467 packet in the 7th line is dropped, so the host does not reset the connection.

## 4. References

* [https://github.com/moby/libnetwork/issues/1090](https://github.com/moby/libnetwork/issues/1090)
* [https://github.com/moby/libnetwork/issues/1090#issuecomment-425421288](https://github.com/moby/libnetwork/issues/1090#issuecomment-425421288)
* [https://imbstack.com/2020/05/03/debugging-docker-connection-resets.html](https://imbstack.com/2020/05/03/debugging-docker-connection-resets.html)
* [https://github.com/kubernetes/kubernetes/pull/74840#issuecomment-491674987](https://github.com/kubernetes/kubernetes/pull/74840#issuecomment-491674987)
* [https://kubernetes.io/blog/2019/03/29/kube-proxy-subtleties-debugging-an-intermittent-connection-reset/](https://kubernetes.io/blog/2019/03/29/kube-proxy-subtleties-debugging-an-intermittent-connection-reset/)
