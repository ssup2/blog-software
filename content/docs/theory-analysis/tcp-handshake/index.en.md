---
title: TCP Handshake
---

This post analyzes the TCP Handshake.

## 1. TCP Handshake

### 1.1. TCP 3Way, 4Way Handshake

{{< figure caption="[Figure 1] TCP 3Way, 4Way Handshake" src="images/tcp-3way-4way-handshake.png" width="750px" >}}

The **3Way Handshake** is the Handshake for creating a TCP Connection, and the **4Way Handshake** is the Handshake for gracefully terminating an established TCP Connection. The upper part of [Figure 1] shows the TCP 3Way Handshake, and the lower part of [Figure 2] shows the 4Way Handshake.

```console {caption="[Shell 1] TCP 3Way, 4Way Handshake", linenos=table}
12:49:33.192719 IP 192.168.0.60.39002 > 192.168.0.61.80: Flags [S], seq 284972257, win 64240, options [mss 1460,sackOK,TS val 2670079469 ecr 0,nop,wscale 7], length 0
12:49:33.192983 IP 192.168.0.61.80 > 192.168.0.60.39002: Flags [S.], seq 1986854381, ack 284972258, win 65160, options [mss 1460,sackOK,TS val 1699876837 ecr 2670079469,nop,wscale 7], length 0
12:49:33.193013 IP 192.168.0.60.39002 > 192.168.0.61.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2670079470 ecr 1699876837], length 0
12:49:33.193037 IP 192.168.0.60.39002 > 192.168.0.61.80: Flags [P.], seq 1:77, ack 1, win 502, options [nop,nop,TS val 2670079470 ecr 1699876837], length 76: HTTP: GET / HTTP/1.1
12:49:33.193256 IP 192.168.0.61.80 > 192.168.0.60.39002: Flags [.], ack 77, win 509, options [nop,nop,TS val 1699876837 ecr 2670079470], length 0
...
12:49:33.193389 IP 192.168.0.61.80 > 192.168.0.60.39002: Flags [P.], seq 239:851, ack 77, win 509, options [nop,nop,TS val 1699876838 ecr 2670079470], length 612: HTTP
12:49:33.193393 IP 192.168.0.60.39002 > 192.168.0.61.80: Flags [.], ack 851, win 501, options [nop,nop,TS val 2670079470 ecr 1699876838], length 0
12:49:33.193563 IP 192.168.0.60.39002 > 192.168.0.61.80: Flags [F.], seq 77, ack 851, win 501, options [nop,nop,TS val 2670079470 ecr 1699876838], length 0
12:49:33.193818 IP 192.168.0.61.80 > 192.168.0.60.39002: Flags [F.], seq 851, ack 78, win 509, options [nop,nop,TS val 1699876838 ecr 2670079470], length 0
12:49:33.193842 IP 192.168.0.60.39002 > 192.168.0.61.80: Flags [.], ack 852, win 501, options [nop,nop,TS val 2670079471 ecr 1699876838], length 0
```

[Shell 1] shows the Packets dumped using the `tcpdump` command on Linux while the TCP 3Way Handshake and 4Way Handshake are performed. In [Shell 1], `S` in `Flags` represents the Sync Flag, `F` represents the Fin Flag, and Dot(`.`) represents the ACK Flag. Therefore, the upper part of [Shell 1] shows the 3Way Handshake process, and the lower part of [Shell 1] shows the 4Way Handshake process.

In [Shell 1], the 3Way Handshake is identical to the TCP standard, but it can be seen that the 4Way Handshake is performed in 3WAY, differently from the standard. Linux by default uses a method that saves Network Bandwidth by sending FIN and ACK at the same time. Therefore, on Linux, the 4Way Handshake process does not actually exchange Packets four times.

#### 1.1.1. 3Way Handshake

The upper part of [Figure 1] shows the 3Way Handshake. Starting with the Client, the 3Way Handshake is performed by exchanging the SYN, SYN+ACK, and ACK Flags. In the TCP standard, since the Client starts the 3Way Handshake first, the Client is referred to as the Active Opener, and the Server is referred to as the Passive Opener. The Client calls the `connect()` System Call to send the SYN Flag to the Server and enters the SYN-SENT state. The Client's SYN-SENT state is maintained until it receives the SYN+ACK Flag from the Server or a Timeout occurs.

The Server, which entered the LISTEN state by calling the `bind()` and `listen()` System Calls, receives the SYN Flag from the Client, then calls the `accept()` System Call to send the SYN+ACK Flag to the Client and enters the SYN-RECEIVED state. The Server's SYN-RECEIVED state is maintained until it receives the ACK Flag or a Data Packet from the Client, or a Timeout occurs. The Timeout values of SYN-SENT and SYN-RECEIVED differ depending on the OS configuration.

The Client's `connect()` System Call terminates after receiving the SYN+ACK Flag from the Server. After that, the Client sends the ACK Flag to the Server, enters the ESTABLISHED state, and exchanges Data with the Server through `send()`/`recv()` System Calls. The Server's `accept()` System Call terminates upon receiving the ACK Flag from the Client or by the SYN-RECEIVED Timeout.

Even if the ACK Flag that the Client sent in response to the SYN+ACK Flag is lost and the Server fails to receive the ACK Flag, no serious problem occurs. This is because, through the ACK Flag and Sequence Number that the Client subsequently sends along with a Data Packet, the Server can indirectly know that the Client received the ACK+SYN Flag it sent. Therefore, even when a Data Packet is received from the Client, the Server's `accept()` System Call terminates, and the Server enters the ESTABLISHED state and exchanges Data with the Client through `send()`/`recv()` System Calls.

#### 1.1.2. 4Way Handshake

The lower part of [Figure 1] shows the 4Way Handshake performed with the Client sending the FIN Flag first. Not only the Client but also the Server can start the 4Way Handshake by sending the FIN Flag first. In the TCP standard, the side that starts the 4Way Handshake first is referred to as the Active Closer, and the other side is referred to as the Passive Closer. Therefore, in [Figure 1], the Client becomes the Active Closer and the Server becomes the Passive Closer.

When the `close()` System Call is called on the Active Closer or the Active Closer's Process terminates, the Socket used by the Active Closer is Closed. When the Socket is Closed, the FIN Flag is sent to the other side. After that, the Active Closer enters the FIN-WAIT-1 state, which is maintained until it receives the ACK Flag from the Passive Closer. The Passive Closer that receives the FIN Flag sends the ACK Flag and enters the CLOSE-WAIT state. 

CLOSE-WAIT, as can be inferred from its name, refers to the state of waiting until the Socket is Closed. That is, just like the Active Closer, it is the state of waiting for the Socket to be Closed by the `close()` System Call being called on the Passive Closer or the Passive Closer's Process terminating. After that, when the Passive Closer's Socket is Closed, the Passive Closer sends the FIN Flag to the Active Closer and enters the LAST-ACK state. Then the Passive Closer receives the ACK Flag from the Active Closer and enters the CLOSE state.

The Active Closer, having received the ACK Flag and FIN Flag from the Passive Closer, enters the FIN-WAIT-2 state and then the TIME-WAIT state, and enters the CLOSE state after a certain amount of time. The TCP standard defines that the TIME-WAIT state must be maintained for 2MSL (2 * Maximum Segment Lifetime). That is, it is a state that waits until the Packets (Segments) related to the terminated Connection are completely removed from the Network, so as not to affect new Connections created afterwards.

### 1.2. TCP Reset

{{< figure caption="[Figure 2] TCP Reset at Connection Start" src="images/tcp-reset-connection-start.png" width="550px" >}}

```console {caption="[Shell 2] TCP Reset at Connection Start", linenos=table}
13:32:50.672429 IP 192.168.0.60.33214 > 192.168.0.61.81: Flags [S], seq 292716723, win 64240, options [mss 1460,sackOK,TS val 2672676949 ecr 0,nop,wscale 7], length 0
13:32:50.672648 IP 192.168.0.61.81 > 192.168.0.60.33214: Flags [R.], seq 0, ack 292716724, win 0, length 0
```

The TCP RST Flag is used to urgently terminate a TCP Connection created due to an unexpected situation. [Figure 2] shows the RST Flag that occurs when a Client sends the Sync Flag to an incorrect IP/Port to create a TCP Connection, and [Shell 2] shows the actual Packets at that moment dumped using the `tcpdump` command. In [Shell 2], `R` in `Flags` represents the RST Flag. The Server that receives the Client's SYN Flag sends the RST Flag and immediately terminates the Connection.

{{< figure caption="[Figure 3] TCP Reset in Connection" src="images/tcp-reset-connection.png" width="550px" >}}

```console {caption="[Shell 3] TCP Reset in Connection", linenos=table}
14:22:47.003693 IP 192.168.0.60.59904 > 192.168.0.61.80: Flags [S], seq 2377770701, win 64240, options [mss 1460,sackOK,TS val 2675673280 ecr 0,nop,wscale 7], length 0
14:22:47.003932 IP 192.168.0.61.80 > 192.168.0.60.59904: Flags [S.], seq 3834916885, ack 2377770702, win 65160, options [mss 1460,sackOK,TS val 1705470647 ecr 2675673280,nop,wscale 7], length 0
14:22:47.003962 IP 192.168.0.60.59904 > 192.168.0.61.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2675673281 ecr 1705470647], length 0
14:22:48.071533 IP 192.168.0.60.43478 > 192.168.0.61.22: Flags [P.], seq 26216:26260, ack 124345, win 501, options [nop,nop,TS val 2675674348 ecr 2444573493], length 44
14:22:48.072274 IP 192.168.0.61.22 > 192.168.0.60.43478: Flags [P.], seq 124345:124669, ack 26260, win 501, options [nop,nop,TS val 2444589375 ecr 2675674348], length 324
14:22:48.072300 IP 192.168.0.60.43478 > 192.168.0.61.22: Flags [.], ack 124669, win 501, options [nop,nop,TS val 2675674349 ecr 2444589375], length 0
...
14:22:50.341815 IP 192.168.0.61.22 > 192.168.0.60.43478: Flags [P.], seq 125029:125097, ack 26376, win 501, options [nop,nop,TS val 2444591644 ecr 2675676617], length 68
14:22:50.341839 IP 192.168.0.60.43478 > 192.168.0.61.22: Flags [.], ack 125097, win 501, options [nop,nop,TS val 2675676619 ecr 2444591644], length 0
14:22:53.840281 IP 192.168.0.60.59904 > 192.168.0.61.80: Flags [P.], seq 1:3, ack 1, win 502, options [nop,nop,TS val 2675680117 ecr 1705470647], length 2: HTTP
14:22:53.840520 IP 192.168.0.61.80 > 192.168.0.60.59904: Flags [R], seq 3834916886, win 0, length 0
```

[Figure 3] shows the case where the Server sends the RST Flag first while a TCP Connection is established, and [Shell 2] shows the actual Packets at that moment dumped using the `tcpdump` command. The Client that receives the RST Flag terminates the TCP Connection without any further Handshake.

## 2. References

* TCP Transport - An Introduction to Computer Networks : [http://intronetworks.cs.luc.edu/1/html/tcp.html](http://intronetworks.cs.luc.edu/1/html/tcp.html)
* When/how does Linux decide to close a socket on application kill : [https://unix.stackexchange.com/questions/386536/when-how-does-linux-decides-to-close-a-socket-on-application-kill](https://unix.stackexchange.com/questions/386536/when-how-does-linux-decides-to-close-a-socket-on-application-kill)
* Can you send a TCP packet with RST flag set using iptables : [https://unix.stackexchange.com/questions/282613/can-you-send-a-tcp-packet-with-rst-flag-set-using-iptables-as-a-way-to-trick-nma](https://unix.stackexchange.com/questions/282613/can-you-send-a-tcp-packet-with-rst-flag-set-using-iptables-as-a-way-to-trick-nma)
* What if a TCP handshake segment is lost : [https://stackoverflow.com/questions/16259774/what-if-a-tcp-handshake-segment-is-lost](https://stackoverflow.com/questions/16259774/what-if-a-tcp-handshake-segment-is-lost)
* Final Analysis of CLOSE_WAIT & TIME_WAIT : [https://tech.kakao.com/2016/04/21/closewait-timewait/](https://tech.kakao.com/2016/04/21/closewait-timewait/)
* Why TIME_WAIT state need to be 2MSL long : [https://stackoverflow.com/questions/25338862/why-time-wait-state-need-to-be-2msl-long](https://stackoverflow.com/questions/25338862/why-time-wait-state-need-to-be-2msl-long)
* TCP connection termination FIN, FIN ACK, ACK : [https://cs.stackexchange.com/questions/76393/tcp-connection-termination-fin-fin-ack-ack](https://cs.stackexchange.com/questions/76393/tcp-connection-termination-fin-fin-ack-ack)
* What is a FIN/ACK message in TCP : [https://stackoverflow.com/questions/30043126/what-is-a-finack-message-in-tcp](https://stackoverflow.com/questions/30043126/what-is-a-finack-message-in-tcp)
