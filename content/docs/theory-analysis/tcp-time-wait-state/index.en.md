---
title: TCP TIME-WAIT State
---

This post analyzes the behavior related to TCP TIME-WAIT.

## 1. TCP TIME-WAIT

The **TIME-WAIT** state is the state that the **Active Closer**, the side that closes the Connection first, reaches after the Connection is closed. It is a state used to wait until the Packets of the closed Connection that may still remain in the Network are completely removed, so that they do not affect new Connections created afterwards. For this reason, the TCP standard defines that it must be maintained for 2MSL (2 * Maximum Segment Lifetime), and until the TIME-WAIT state ends, a new Connection cannot be established using the Local IP/Port occupied by the TIME-WAIT. Both the Client and the Server can become the Active Closer. Therefore, the TIME-WAIT state can occur on both the Client and the Server.

```console {caption="[Shell 1] TIME-WAIT State through curl(Client)", linenos=table}
(client)$ echo 30000 30000 > /proc/sys/net/ipv4/ip-local-port-range
(client)$ curl 192.168.0.60:80
DATA
...

(client)$ netstat -na | grep 192.168.0.60
tcp        0      0 192.168.0.61:30000      192.168.0.60:80         TIME-WAIT
...

(client)$ curl 192.168.0.60:80
curl: (7) Couldn't connect to server
```

[Shell 1] shows the process of reproducing the TIME-WAIT state on Linux where the Client runs, using the `curl` command. The `curl` command sends a request to the Server and, after receiving the response, plays the role of the Active Closer that closes the Connection first. Therefore, the TIME-WAIT state can be seen after running the `curl` command. Afterwards, the same request was sent to the Server through the second `curl` command, but it can be seen that it does not work and fails with an Error.

In [Shell 1], since the `curl` command established a Connection with the `192.168.0.60:80` Server using `192.168.0.61:30000` as the Local IP/Port, it can be seen that the `192.168.0.61:30000`/`192.168.0.60:80` Connection exists in the TIME-WAIT state. Until this TIME-WAIT state ends, a new Connection with `192.168.0.60:80` cannot be established using the `192.168.0.61:30000` IP/Port. (If it is possible to connect to `192.168.0.60:80` using a different Local IP, a new Connection with `192.168.0.60:80` can be established through the different Local IP/`30000`.)

```console {caption="[Shell 2] TIME-WAIT State with curl(Client)", linenos=table}
(server)$ -na | grep 192.168.0.61
tcp        0      0 192.168.0.60:80         192.168.0.61:30000      TIME-WAIT

(client)$ echo 30000 30000 > /proc/sys/net/ipv4/ip-local-port-range
(client)$ curl 192.168.0.60:80
OK
...

(server)$ -na | grep 192.168.0.61
Empty
```

In general, between a Server and a Client with an established Connection, the Client often closes the Connection first. However, depending on the situation, the Server may also close the Connection first, so the TIME-WAIT state can also occur on the Server. However, when a new Connection request identical to a Connection in the TIME-WAIT state on the Server arrives, the existing Connection in the TIME-WAIT state is removed and the new Connection is established. Therefore, Connections in the TIME-WAIT state on the Server do not interfere with the Server's Connections.

### 1.1. TCP Connection Issue with Short TIME-WAIT State

{{< figure caption="[Figure 1] TCP Connection Issue with Packet Delay" src="images/packet-delay.png" width="500px" >}}

When the TIME-WAIT state is short, a new TCP Connection can be affected if Packet Delay occurs or if the last ACK Flag is lost during the 4Way Handshake process. [Figure 1] shows a situation where a new TCP Connection is affected by Packet Delay when the TIME-WAIT state is short. In [Figure 1], in a situation where the Packet with SEQ=3 sent by the Client is not delivered to the Server immediately and is delayed by the Network, the Client and the Server closed the existing Connection and established a new Connection. Afterwards, the delayed SEQ=3 Packet of the previous Connection is delivered to the Server.

In most cases, since the SEQ that the Server should receive and the SEQ of the delayed Packet are different, even if the delayed Packet is delivered to the Server, the Server drops it and no problem occurs. However, as in the situation of [Figure 1], when the SEQ that the Server should receive and the SEQ of the delayed Packet happen to be identical, the Server may receive the delayed Packet without dropping it. In this case, Data integrity is broken.

{{< figure caption="[Figure 2] TCP Connection Issue with Lost Last ACK in 4Way Handshake" src="images/lost-last-ack.png" width="550px" >}}

[Figure 2] shows a situation where, when the TIME-WAIT state is short, the last ACK Flag of the TCP 4Way Handshake is not delivered to the Server (Passive Closer), and the Server remains in the LAST-ACK state. When the TIME-WAIT state is short, before the Server's LAST-ACK state changes to the CLOSED state by Timeout, the Client can send a SYN Flag to the Server using the same Local IP/Port for a new Connection. The problem is that a Server in the LAST-ACK state, upon receiving a SYN Flag, sends an RST Flag to block Connection creation, so the new Connection creation fails. For this reason, the Client experiences an unexpected Connection Error.

## 2. Short TIME-WAIT in Linux

In Linux, by default, a Connection in the TIME-WAIT state is set to persist for 60 seconds as a fixed value in the Linux Kernel Code. Since this is a relatively long time, when there are many Connections in the TIME-WAIT state, a problem can occur where the Client cannot establish new Connections because no usable Local IP/Port exists due to the Local IP/Ports occupied by the Connections in the TIME-WAIT state. In addition, as the number of Connections in the TIME-WAIT state increases, a problem of occupying Kernel-space Memory also occurs. To solve these problems, Linux provides several techniques that can make the TIME-WAIT shorter.

### 2.1. `tcp-timestamps` (`/proc/sys/net/ipv4/tcp-timestamps`)

To understand the techniques for solving the problems caused by many Connections in the TIME-WAIT state in Linux, the `tcp-timestamps` setting must be understood. The `tcp-timestamps` setting is an Option that sets a Timestamp in the TCP Packet Header. It is set to `1` by default, so it is configured to use the Timestamp. The Timestamp Field consists of the `TS Value Field`, which stores the Timestamp of the Packet sender, and the `TS Echo Reply Field`, which exists for the purpose of copying the `TS Value Field` of the received Packet and delivering it back to the sender.

The `tcp-tw-reuse` and `tcp-tw-recycle` settings provided by Linux, described below, work properly only when the Timestamp value is set in the TCP Header. Therefore, for the `tcp-tw-reuse` and `tcp-tw-recycle` settings to work properly, `tcp-timestamps` must be set so that the Timestamp value is set in the TCP Header.

### 2.2. `tcp-tw-reuse` (`/proc/sys/net/ipv4/tcp-tw-reuse`)

```console {caption="[Shell 3] TIME-WAIT State through curl(Client) with tcp-tw-reuse", linenos=table}
(client)$ echo 1 > /proc/sys/net/ipv4/tcp-tw-reuse
(client)$ echo 30000 30000 > /proc/sys/net/ipv4/ip-local-port-range
(client)$ curl 192.168.0.60:80
OK
...

(client)$ netstat -na | grep 192.168.0.60
tcp        0      0 192.168.0.61:30000      192.168.0.60:80         TIME-WAIT
...

(client)$ curl 192.168.0.60:80
OK
...
```

The `tcp-tw-reuse` setting makes it possible to reuse Connections in the TIME-WAIT state. It is mainly set on the Client and solves the Local IP/Port shortage that the Client may experience. [Shell 3] shows the process of setting `tcp-tw-reuse` and then sending requests to the Server twice through the `curl` command in the same way as [Shell 1]. In [Shell 1] the second `curl` request failed, but in [Shell 3], thanks to the `tcp-tw-reuse` setting, the `192.168.0.61:30000`/`192.168.0.60:80` Connection in the TIME-WAIT state can be reused, so it can be seen that the second `curl` command also succeeded.

The problems of [Figure 1] and [Figure 2] that can occur when the TIME-WAIT state becomes short can be solved through the Timestamp included in the TCP Packet Header. If a Timestamp exists in the TCP Packet, Linux compares not only the SEQ but also the Timestamp value when receiving a TCP Packet. If the Timestamp is an old Timestamp, that Packet is dropped. Therefore, in the situation of [Figure 1], the Server sees the old Timestamp of the delayed Packet and drops the delayed Packet.

In the situation of [Figure 1], even if the delayed Packet is delivered to the Server after the original SEQ=3 Packet, the Server sees the Timestamp and drops the delayed Packet. In other words, even if a situation occurs where Packets with the same SEQ are received, it is not a problem because the Timestamp of the TCP Packet makes it possible to know which Packet is valid.

{{< figure caption="[Figure 3] Lost Last ACK Recovery with Timestamp in 4Way Handshake" src="images/lost-last-ack-recovery.png" width="550px" >}}

[Figure 3] shows the process where, in the same situation as [Figure 2], the Timestamp of the Packet is used to end the Server's LAST-ACK state, and the Client and the Server establish a new Connection. The difference between [Figure 3] and [Figure 2] is that the Server, by checking the Timestamp of the Packet, does not send an RST Flag to the Client but ignores the SYN Flag and delivers no response Packet to the Client. Therefore, the Client's Connection attempt is not aborted.

Afterwards, the Server retransmits the FIN Flag to get out of the LAST-ACK state. Since the FIN Flag is not the response the Client wants, the Client sends an RST Flag to the Server as the response to the SYN SYN Flag. The Server that received the RST Flag ends the LAST-ACK state. Since the Client's Connection attempt was not aborted, the Client sends a SYN Flag to the Server again after 1 second according to the TCP Retranmission policy and establishes a Connection with the Server. This process is handled without being exposed to the Client App.

The `tcp-tw-reuse` setting is known not to affect TCP Connections even when actually used. Therefore, the Default value of most OSes is set to use it.

### 2.3. `tcp-tw-recycle` (`/proc/sys/net/ipv4/tcp-tw-recycle`)

The `tcp-tw-recycle` setting reduces the TIME-WAIT state to the RTO (Retransmission Timeout) of the TCP Connection instead of 60 seconds, making the TIME-WAIT state very short. It is mainly set on the Server and removes the Connections in the TIME-WAIT state on the Server, solving the problem of Connections in the TIME-WAIT state occupying Kernel Memory. Since the minimum RTO in Linux is 200ms, setting `tcp-tw-recycle` allows the TIME-WAIT state to exist for as little as 200ms.

When `tcp-tw-recycle` is set, the Server stores the last Timestamp of a Connection when the Connection enters the TIME-WAIT state. Afterwards, when the Server receives a Packet from a Client with the same IP/Port, the Server checks the Timestamp of the Packet and compares the Timestamp with the last Timestamp of the previous Connection stored by the Server. If the Timestamp of the Packet received by the Server is smaller than the last Timestamp stored by the Server, the Server drops that Packet.

The reason for performing this behavior is that it is a simple way to drop delayed Packets when a delayed Packet occurs as in [Figure 1] while the TIME-WAIT state becomes short. However, this method of dropping Packets by comparing only the Timestamp of the Packet can cause problems in a Network environment where the Client communicates with the Server through SNAT.

{{< figure caption="[Figure 4] DROP Packet Issue with Client SNAT" src="images/snat-syn-packet-drop.png" width="700px" >}}

[Figure 4] shows the problem that can occur when the Client communicates with the Server through SNAT due to the `tcp-tw-recycle` setting. Client A and Client B have different Timestamps, and Client A has a higher Timestamp than Client B. Client A first established a Connection with the Server through SNAT. Afterwards, Client B also tries to establish a Connection with the Server through SNAT. At this point, Client B was also SNATed to the same SRC IP/Port as Client A. Therefore, the Server cannot distinguish Client A from Client B and regards them as the same Client.

The Server stores 200, the last Timestamp value sent by Client A. Afterwards, if Client B sends a Packet with a Timestamp value of 100, the Server regards it as a delayed Packet sent by the same Client as before and drops Client B's Packet. In most cases, the **SYN Flag**, which is sent first when establishing a Connection, is dropped at the Server due to this problem. Therefore, a situation occurs where Client B sent a SYN Flag but receives no response to it.

To prevent the above problem, the two Clients must have exactly the same Timestamp. However, it is impossible for multiple Clients to have exactly the same Timestamp. Therefore, the Linux Manpage also recommends not using `tcp-tw-recycle` in a Network environment where the Client is SNATed.

As the Memory capacity of Servers has greatly increased, the Kernel Memory area occupied by Connections in the TIME-WAIT state is no longer a big problem, unlike in the past. Therefore, there is no need to use the `tcp-tw-recycle` setting in most environments. In addition, in [Linux Kernel 4.10](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=95a22caee396cef0bb2ca8fafdd82966a49367bb), the Timestamp was changed to use a Random Offset for each Connection, and accordingly the `tcp-tw-recycle` setting became meaningless regardless of whether the Client is SNATed or not, and it was removed in Linux Kernel 4.10.

The `tcp-tw-recycle` setting cannot be used in an environment where Client SNAT occurs or on recent Kernels. Therefore, it may not be possible to remove Connections in the TIME-WAIT state on the Server through the `tcp-tw-recycle` setting. The fundamental way to remove Connections in the TIME-WAIT state on the Server is to design the Server and the Client so that, if possible, the Client becomes the Active Closer instead of the Server. In other words, the Server and the Client should be developed so that the Client closes the TCP Connection between the Server and the Client first whenever possible, so that Connections in the TIME-WAIT state do not occur on the Server.

### 2.4. Socket Lingering (`SO-LINGER` Socket Option)

In Linux, Socket Lingering can be performed on a Socket through the `SO-LINGER` Option. When a Socket with the `SO-LINGER` Option set is closed by the App through the `close()` System Call, the `close()` System Call sends all the Data in the Socket Buffer to the peer and blocks until the Socket is closed. At this point, the Blocking waits at most for the time passed to the Socket along with the `SO-LINGER` Option. If all the Data in the Socket Buffer cannot be sent to the peer even after waiting for the maximum time, an RST Flag is sent to the peer to forcibly close the Connection.

If the time passed along with the `SO-LINGER` Option is set to `0` on the Socket, the Connection associated with that Socket is forcibly closed through the RST Flag, so no TIME-WAIT state remains. However, the `SO-LINGER` Option is not an Option for reducing the TIME-WAIT state, but an Option provided to guarantee Data transmission when closing a Socket. Therefore, in general situations, removing the TIME-WAIT state using the `SO-LINGER` Option is not recommended.

## 3. References

* Coping with the TCP TIME-WAIT state on busy Linux servers : [https://vincent.bernat.ch/en/blog/2014-tcp-time-wait-state-linux](https://vincent.bernat.ch/en/blog/2014-tcp-time-wait-state-linux)
* 리눅스 서버의 TCP 네트워크 성능을 결정짓는 커널 파라미터 이야기 - 3편 : [https://meetup.toast.com/posts/55](https://meetup.toast.com/posts/55)
* TIME_WAIT 소켓이 서비스에 미치는 영향 : [https://brunch.co.kr/@alden/3](https://brunch.co.kr/@alden/3)
* TCP TIME_WAIT - brunch @alden : [https://brunch.co.kr/@alden/19](https://brunch.co.kr/@alden/19)
* Dropping of connections with tcp_tw_recycle : [https://stackoverflow.com/questions/8893888/dropping-of-connections-with-tcp-tw-recycle](https://stackoverflow.com/questions/8893888/dropping-of-connections-with-tcp-tw-recycle)
* tcp(7) - Linux manual page : [https://man7.org/linux/man-pages/man7/tcp.7.html](https://man7.org/linux/man-pages/man7/tcp.7.html)
* TCP의 TIME_WAIT를 없애는 법 : [https://sunyzero.tistory.com/198](https://sunyzero.tistory.com/198)
* Why Are Linux Kernel Protocol Stacks Dropping SYN Packets : [https://www.alibabacloud.com/blog/why-are-linux-kernel-protocol-stacks-dropping-syn-packets-595251](https://www.alibabacloud.com/blog/why-are-linux-kernel-protocol-stacks-dropping-syn-packets-595251)
* CLOSE_WAIT & TIME_WAIT 최종 분석 : [https://tech.kakao.com/2016/04/21/closewait-timewait/](https://tech.kakao.com/2016/04/21/closewait-timewait/)
* tcp: randomize tcp timestamp offsets for each connection - Linux kernel commit : [https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=95a22caee396cef0bb2ca8fafdd82966a49367bb](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=95a22caee396cef0bb2ca8fafdd82966a49367bb)
