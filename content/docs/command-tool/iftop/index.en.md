---
title: iftop
---

This document analyzes `iftop`, which classifies network bandwidth usage of a specific interface by source IP/destination IP and then outputs them sorted by usage in descending order.

## 1. iftop

### 1.1. iftop -i [Interface]

```shell {caption="[Shell 1] iftop -i eth0"}
 Press H or ? for help            25.0Kb            37.5Kb           50.0Kb      62.5Kb
└─┴─┴─┴─┴──
node09                        => dns.google                      672b   1.11Kb  1.05Kb
                              <=                                 672b   1.00Kb  1.04Kb
node09                        => 192.168.0.40 cast.net             0b      0b    931b
                              <=                                   0b      0b   3.33Kb
_gateway                      => all-systems.mcast.net             0b      0b     34b
                              <=                                   0b      0b      0b
node09                        => 106.247.248.106                   0b      0b     15b
                              <=                                   0b      0b     15b
node09                        => dadns.cdnetworks.co.kr            0b      0b     15b
                              <=                                   0b      0b     15b
node09                        => ch-ntp01.10g.ch                   0b      0b     15b
                              <=                                   0b      0b     15b
node09                        => ec2-13-209-84-50.ap-northeas      0b      0b     15b
                              <=                                   0b      0b     15b

──
TX:             cum:   11.2KB   peak:   19.1Kb         rates:    672b   1.11Kb  2.02Kb
RX:                    23.8KB           67.5Kb                   672b   1.00Kb  4.46Kb
TOTAL:                 35.0KB           86.6Kb                  1.31Kb  2.11Kb  6.48Kb 
```

Classifies network bandwidth usage of [Interface] by source IP/destination IP and then outputs them sorted by usage in descending order. [Shell 1] shows the output of `iftop -i eth0` displaying network bandwidth usage of eth0. Each column represents, in order: packet source/destination, packet direction, packet source/destination, packet amount moved in 2 seconds, packet amount moved in 10 seconds, packet amount moved in 40 seconds.

