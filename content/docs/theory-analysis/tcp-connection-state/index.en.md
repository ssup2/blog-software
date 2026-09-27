---
title: TCP Connection State
---

This post analyzes the TCP Connection State.

## 1. TCP Connection State

{{< figure caption="[Figure 1] TCP Connection State Diagram" src="images/tcp-connection-state-diagram.png" width="900px" >}}

{{< figure caption="[Figure 2] TCP Handshake Connection State" src="images/tcp-handshake-connection-state.png" width="750px" >}}

[Figure 1] shows the TCP Connection State Diagram, and [Figure 2] shows the TCP Connection States during the TCP 3-Way Handshake and 4-Way Handshake. In the TCP standard, the Client that sends the SYN Flag first when performing the TCP 3-Way Handshake is called the Active Opener, and the Server on the opposite side is called the Passive Opener. Also, in the TCP standard, the Client or Server that sends the FIN Flag first when performing the TCP 4-Way Handshake is called the Active Closer, and the opposite side is called the Passive Closer. [Figure 1] assumes that the Client is the Active Closer.

Therefore, in [Figure 1], the process in which the Client sends the SYN Flag and enters the SYN-SENT state is shown as the "active open" operation, and the process in which the Server enters the LISTEN state is shown as the "passive open" operation. Similarly, the states of the Client related to the 4-Way Handshake are classified as the "active close" process, and the states of the Server related to the 4-Way Handshake are classified as the "passive close" process.

Two Apps may exist, and each App can play the roles of Server and Client at the same time. The two Apps may also try to establish a Connection with each other simultaneously by sending SYN Flags to each other after the LISTEN state. The process of going from the LISTEN state through the SYN-SENT state to the SYN-RECEIVED state occurs in such a situation. This situation is called a "simultaneous open". Similarly, two Apps may close the Connection at the same time. This situation is called a "simultaneous close", and it corresponds to the process of transitioning from the FIN-WAIT-1 state through the CLOSING state to the TIME-WAIT state.

### 1.1. LISTEN

The LISTEN state means the state in which the Server can receive a SYN Flag from the Client and create a new Connection. In a Linux environment, the Server can enter the LISTEN state through the `bind()` and `listen()` System Calls.

### 1.2. SYN-SENT

The SYN-SENT state is the state a Client in the Closed state transitions to after sending a SYN Flag. In a Linux environment, the Client can enter the SYN-SENT state through the `connect()` System Call. Also, in a Linux environment, the Client waits while sending the SYN Flag up to the number of times set in `/proc/sys/net/ipv4/tcp-syn-retries`, at intervals of up to the RTO (Retransmission Timeout). The default value of `/proc/sys/net/ipv4/tcp-syn-retries` is `6`.

### 1.3. SYN-RECEIVED

The SYN-RECEIVED state is the state a Server in the LISTEN state transitions to after sending a SYN+ACK Flag to the Client when it receives a SYN Flag from the Client. In a Linux environment, the Server can enter the SYN-RECEIVED state through the `accept()` System Call. Also, in a Linux environment, the Server waits while sending the SYN Flag up to the number of times set in `/proc/sys/net/ipv4/tcp-synack-retries`, at intervals of up to the RTO (Retransmission Timeout). The default value of `/proc/sys/net/ipv4/tcp-synack-retries` is `5`.

### 1.4. ESTABLISHED

The ESTABLISHED state is the state in which a Connection has been established between the Server and the Client after the 3-Way Handshake. In the ESTABLISHED state, the Server and the Client can exchange Data. In a Linux environment, Data can be exchanged through the `send()` and `recv()` System Calls.

In a Linux environment, the `SO-KEEPALIVE` Option can be set on a Socket. When the Server or Client does not exchange Data for a long time over a Socket with the `SO-KEEPALIVE` Option set, it periodically sends the peer a Probe Packet, which is a Packet containing an ACK with empty Data, to check whether the TCP Connection is still valid. The Server or Client that receives the Probe Packet sends an ACK if the Connection is still valid, and sends an RST Flag if the Connection is not valid so that the peer removes the Connection information. This technique is called TCP Keepalive.

In a Linux environment, when no Data is exchanged on a Socket with the `SO-KEEPALIVE` Option set for the amount of time set in `/proc/sys/net/ipv4/tcp-keepalive-time`, a Probe Packet is sent. If no response to the Probe Packet is received, the Probe Packet is sent repeatedly up to the number of times set in `/proc/sys/net/ipv4/tcp-keepalive-probes`, at intervals of `/proc/sys/net/ipv4/tcp-keepalive-intvl`. The default value of `/proc/sys/net/ipv4/tcp-keepalive-time` is `7200` (seconds), the default value of `/proc/sys/net/ipv4/tcp-keepalive-probes` is `9`, and the default value of `/proc/sys/net/ipv4/tcp-keepalive-intvl` is `72` (seconds).

### 1.5. FIN-WAIT-1

The FIN-WAIT-1 state is the state the Active Closer in the ESTABLISHED state transitions to when it is closed. After the Active Closer enters the FIN-WAIT-1 state, it sends a FIN Flag to the Passive Closer. In a Linux environment, when the Active Closer calls the `close()` System Call or the Process of the Active Closer terminates, the Socket of the Active Closer is closed, so the Active Closer sends a FIN Flag and enters the FIN-WAIT-1 state.

Also, in a Linux environment, there is no Timeout for FIN-WAIT-1, and it remains until it receives an ACK Flag from the Passive Closer and enters the FIN-WAIT-2 state, or until the total number of FIN-WAIT-1 states stored by the Linux Kernel exceeds a certain number and it is removed by the Linux Kernel. The number of states the Linux Kernel can store is set in the value of `/proc/sys/net/ipv4/tcp-max-orphans`. The default value of `/proc/sys/net/ipv4/tcp-max-orphans` is `16384`.

### 1.6. FIN-WAIT-2

The FIN-WAIT-2 state is the state the Active Closer in the FIN-WAIT-1 state transitions to after receiving an ACK Flag from the Passive Closer. In a Linux environment, the FIN-WAIT-2 state is maintained until it receives a FIN Flag from the Passive Closer and enters the TIME-WAIT state, or until the FIN-WAIT-2 Timeout set by the Linux Kernel elapses. The FIN-WAIT-2 Timeout of the Linux Kernel is set in `/proc/sys/net/ipv4/tcp-fin-timeout`, and the default value is `60` (seconds).

### 1.7. TIME-WAIT

The TIME-WAIT state is the state the Active Closer in the FIN-WAIT-2 state transitions to after receiving a FIN Flag from the Passive Closer. The TCP standard defines that the TIME-WAIT state must be maintained for 2MSL (2 * Maximum Segment Lifetime). In other words, it is a state that waits until the Packets (Segments) related to the closed Connection are completely removed from the Network, in order not to affect new Connections created afterwards.

In a Linux environment, the TIME-WAIT state lasts for 60 seconds, and it cannot be changed because it is set in the Code. Also, the Linux environment provides an Option to reuse Sockets in the TIME-WAIT state when Sockets (Ports) are insufficient. The related Option can be enabled by setting the value of `/proc/sys/net/ipv4/tcp-tw-reuse` to `1`.

### 1.8. CLOSING

The CLOSING state is the state the Active Closer in the FIN-WAIT-1 state transitions to when it receives a FIN Flag due to a simultaneous close.

### 1.9. CLOSE-WAIT

The CLOSE-WAIT state is the state the Passive Closer transitions to after receiving a FIN Flag from the Active Closer. In a Linux environment, when the Passive Closer calls the `close()` System Call or the Process of the Passive Closer terminates, the Socket of the Passive Closer is closed, so the Passive Closer sends a FIN Flag and enters the LAST-ACK state. In a Linux environment, there is no Timeout for the CLOSE-WAIT state, and it ends only when the Socket of the Passive Closer is closed and it becomes LAST-ACK.

### 1.10. LAST-ACK

The LAST-ACK state is the state maintained after the Passive Closer in the CLOSE-WAIT state sends a FIN Flag to the Active Closer, until it receives the corresponding ACK.

## 2. References

* TCP Connection Status (IBM Documentation) : [https://www.ibm.com/support/knowledgecenter/en/SSLTBW-2.1.0/com.ibm.zos.v2r1.halu101/constatus.htm](https://www.ibm.com/support/knowledgecenter/en/SSLTBW-2.1.0/com.ibm.zos.v2r1.halu101/constatus.htm)
* TCP State Diagram (TCP Session Connection Process) : [https://m.blog.naver.com/PostView.nhn?blogId=jgenius&logNo=221124990186&categoryNo=0&proxyReferer=&proxyReferer=https:%2F%2Fwww.google.com%2F](https://m.blog.naver.com/PostView.nhn?blogId=jgenius&logNo=221124990186&categoryNo=0&proxyReferer=&proxyReferer=https:%2F%2Fwww.google.com%2F)
* TCP Transport - An Introduction to Computer Networks : [http://intronetworks.cs.luc.edu/1/html/tcp.html](http://intronetworks.cs.luc.edu/1/html/tcp.html)
* TIME_WAIT (2MSL wait status) : [https://m.blog.naver.com/PostView.nhn?blogId=cmw1728&logNo=220448146710&proxyReferer=https:%2F%2Fwww.google.com%2F](https://m.blog.naver.com/PostView.nhn?blogId=cmw1728&logNo=220448146710&proxyReferer=https:%2F%2Fwww.google.com%2F)
* Why TIME_WAIT state need to be 2MSL long : [https://stackoverflow.com/questions/25338862/why-time-wait-state-need-to-be-2msl-long](https://stackoverflow.com/questions/25338862/why-time-wait-state-need-to-be-2msl-long)
* TCP: two sides trying to connect simultaneously : [https://stackoverflow.com/questions/2231283/tcp-two-sides-trying-to-connect-simultaneously](https://stackoverflow.com/questions/2231283/tcp-two-sides-trying-to-connect-simultaneously)
* ip-sysctl.txt - Linux Kernel Documentation : [https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt](https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt)
