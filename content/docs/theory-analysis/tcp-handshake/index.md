---
title: TCP Handshake
---

TCP Handshake를 분석한다.

## 1. TCP Handshake

### 1.1. TCP 3Way, 4Way Handshake

{{< figure caption="[Figure 1] TCP 3Way, 4Way Handshake" src="images/tcp-3way-4way-handshake.png" width="750px" >}}

3Way Handshake는 TCP Connection을 생성하기 위한 Handshake이며, 4Way Handshake는 생성되어 있는 TCP Connection을 우아하게 종료하는 Handshake이다. [Figure 1]의 윗부분은 TCP 3Way Handshake를 나타내고 있고, [Figure 2]의 아랫부분은 4Way Handshake를 나타내고 있다.

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

[Shell 1]은 Linux에서 tcpdump 명령어를 이용하여 TCP 3Way Handshake, 4Way Handshake 수행시 Packet을 Dump한 모습을 나타내고 있다. [Shell 1]에서 Flags의 S는 Sync Flag, F는 Fin Flag, Dot(.)은 ACK Flag를 나타낸다. 따라서 [Shell 1]의 윗부분은 3Way Handshake 과정을 나타내고 있고, [Shell 1]의 아랫 부분은 4Way Handshake 과정을 나타내고 있다.

[Shell 1]에서 3Way Handshake는 TCP 표준과 동일하지만, 4Way Handshake는 표준과 다르게 3WAY로 수행하는 것을 확인할 수 있다. Linux에서는 기본적으로 FIN과 ACK를 동시에 보내 Network Bandwidth를 절약하는 방법을 이용하고 있다. 따라서 Linux에서는 4Way Handshake 과정이 실제로 Packet을 4번 주고 받지는 않는다.

#### 1.1.1. 3Way Handshake

[Figure 1]의 윗부분은 3Way Handshake를 나타낸다. Client를 시작으로 SYN, SYN+ACK, ACK Flag를 주고받으며 3Way Handshake를 수행한다. TCP 표준에서는 Client가 먼저 3Way Handshake를 시작하기 때문에 Client를 Active Opener라고 표현하며, Server는 Passive Opener라고 표현한다. Client는 connect() System Call을 호출하여 Server에게 SYN Flag를 전송하고 SYN-SENT 상태가 된다. Client의 SYN-SENT 상태는 Server로부터 SYN+ACK Flag를 받거나 Timeout이 발생할 때까지 유지된다.

bind(), listen() System Call을 호출하여 LISTEN 상태가 된 Server는 Client에게 SYN Flag를 받은 다음 accept() System Call을 호출하여 Client에게 SYN+ACK Flag를 전송하고 SYN-RECEIVED 상태가 된다. Server의 SYN-RECEIVED 상태는 Client로부터 ACK FLAG 또는 Data Packet을 수신하거나 Timeout이 발생할 때까지 유지된다. SYN-SENT의 및 SYN-RECEIVED의 Timeout 값은 OS 설정마다 다르다.

Client의 connect() System Call은 Server로부터 SYN+ACK Flag를 수신한 다음에 종료된다. 이후에 Client는 Server에게 ACK Flag를 전송하고 ESTABLISHED 상태가 되어 send()/recv() System Call 호출을 통해서 Server와 Data를 주고 받는다. Server의 accept() System Call은 Client로 부터 ACK Flag를 수신하거나 SYN-RECEIVED의 Timeout에 의해서 종료된다.

Client가 SYN+ACK Flag의 응답으로 전송한 ACK Flag가 유실되어 Server가 ACK Flag를 수신하지 못하는 상태가 발생해도 큰 문제는 발생하지 않는다. 이후에 Client가 Data Packet안에 함께 전송하는 ACK Flag 및 Sequence Number를 통해서 Server는 자신이 전송한 ACK+SYN Flag를 Client가 수신했다는 사실을 간접적으로 알 수 있기 때문이다. 따라서 Client로부터 Data Packet을 수신하여도 Server의 accept() System Call 호출은 종료되고, Server는 ESTABLISHED 상태가 되어 send()/recv() System Call 호출을 통해서 Client와 Data를 주고 받는다.

#### 1.1.2. 4Way Handshake

[Figure 1]의 아랫부분은 Client가 먼저 FIN Flag를 전송하여 수행하는 4Way Handshake를 나타낸다. Client 뿐만 아니라 Server가 먼저 FIN Flag를 전송하여 4Way Handshake를 시작할 수도 있다. TCP 표준에서는 4Way Handshake를 먼저 시작하는 쪽을 Active Closer라고 표현하며, 반대쪽을 Passive Closer라고 표현한다. 따라서 [Figure 1]에서 Client가 Active Closer가 되며 Server는 Passive Closer가 된다.

Active Closer에서 close() System Call 호출하거나 Active Closer의 Process가 종료되면 Active Closer가 이용하던 Socket은 Close가 된다. Socket이 Close가 되면 FIN Flag를 상대에게 전송한다. 이후에 Active Closer는 FIN-WAIT-1 상태가 되며 Passive Closer로부터 ACK Flag를 받을때 까지 유지된다. FIN Flag를 받은 Passive Closer는 ACK FLAG를 전송하고 CLOSE-WAIT 상태가 된다. 

CLOSE-WAIT는 이름에서 유츄할 수 있는것 처럼 Socket이 Close 될때까지 대기를 하는 상태를 의미한다. 즉 Active Closer와 동일하게 Passive Closer에서 close() System Call 호출하거나 Passive Closer의 Process가 종료되어 Socket이 Close가 되기를 기다리는 상태이다. 이후 Passive Closer의 Socket이 Close되면 Passive Closer는 FIN Flag를 Active Closer에게 전송하고 LASK-ACK 상태가 된다. 이후 Passive Closer는 Active Closer의 ACK Flag를 받고 CLOSE 상태가 된다.

Passive Closer의 ACK Flag와 FIN Flag를 받은 Active Closer는 FIN-WAIT-2 상태 및 TIME-WAIT 상태가 되며 특정 시간 이후에 CLOSE 상태가 된다. TIME-WAIT 상태는 TCP 표준에는 2MSL(2 * Maximum Segment Lifetime)만큼 유지되야 한다고 정의하고 있다. 즉 Network 상에서 종료된 Connection 관련 Packet(Segment)이 완전히 제거 될때까지 대기하여, 이후에 생성되는 새로운 Connection에 영향을 미치지 않기 위한 상태이다.

### 1.2. TCP Reset

{{< figure caption="[Figure 2] TCP Reset at Connection Start" src="images/tcp-reset-connection-start.png" width="550px" >}}

```console {caption="[Shell 2] TCP Reset at Connection Start", linenos=table}
13:32:50.672429 IP 192.168.0.60.33214 > 192.168.0.61.81: Flags [S], seq 292716723, win 64240, options [mss 1460,sackOK,TS val 2672676949 ecr 0,nop,wscale 7], length 0
13:32:50.672648 IP 192.168.0.61.81 > 192.168.0.60.33214: Flags [R.], seq 0, ack 292716724, win 0, length 0
```

TCP RST Flag는 예상치 못한 상황으로 인해서 생성된 TCP Connection을 급하게 종료할때 이용한다. [Figure 2]는 Client가 TCP Connection을 생성하기 위해서 잘못된 IP/Port로 Sync Flag를 전송할 경우 발생하는 RST Flag를 나타내고 있고, [Shell 2]는 이때의 실제 Packet을 tcpdump 명령어를 통해서 Dump한 모습이다. [Shell 2]에서 Flags의 R은 RST Flag를 나타낸다. Client의 SYN Flag를 받은 Server는 RST Flag를 전송하여 바로 Connection을 종료한다.

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

[Figure 3]은 TCP Connection이 생성되어 있는 상태에서 Server가 먼저 RST Flag를 전송한 경우를 나타내고 있고, [Shell 2]는 이때의 실제 Packet을 tcpdump 명령어를 통해서 Dump한 모습이다. RST Flag를 받은 Client는 더 이상의 Handshake 없이 TCP Connection을 종료한다.

## 2. 참조

* [http://intronetworks.cs.luc.edu/1/html/tcp.html](http://intronetworks.cs.luc.edu/1/html/tcp.html)
* [https://unix.stackexchange.com/questions/386536/when-how-does-linux-decides-to-close-a-socket-on-application-kill](https://unix.stackexchange.com/questions/386536/when-how-does-linux-decides-to-close-a-socket-on-application-kill)
* [https://unix.stackexchange.com/questions/282613/can-you-send-a-tcp-packet-with-rst-flag-set-using-iptables-as-a-way-to-trick-nma](https://unix.stackexchange.com/questions/282613/can-you-send-a-tcp-packet-with-rst-flag-set-using-iptables-as-a-way-to-trick-nma)
* [https://stackoverflow.com/questions/16259774/what-if-a-tcp-handshake-segment-is-lost](https://stackoverflow.com/questions/16259774/what-if-a-tcp-handshake-segment-is-lost)
* [https://tech.kakao.com/2016/04/21/closewait-timewait/](https://tech.kakao.com/2016/04/21/closewait-timewait/)
* [https://stackoverflow.com/questions/25338862/why-time-wait-state-need-to-be-2msl-long](https://stackoverflow.com/questions/25338862/why-time-wait-state-need-to-be-2msl-long)
* [https://cs.stackexchange.com/questions/76393/tcp-connection-termination-fin-fin-ack-ack](https://cs.stackexchange.com/questions/76393/tcp-connection-termination-fin-fin-ack-ack)
* [https://stackoverflow.com/questions/30043126/what-is-a-finack-message-in-tcp](https://stackoverflow.com/questions/30043126/what-is-a-finack-message-in-tcp)