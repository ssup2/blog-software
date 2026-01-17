---
title: ethtool
---

This document summarizes the usage of `ethtool` for controlling NICs.

## 1. ethtool

### 1.1. ethtool [Interface]

```shell {caption="[Shell 1] ethtool eth0"}
# ethtool eth0
Settings for eth0:
        Supported ports: [ ]
        Supported link modes:   Not reported
        Supported pause frame use: No
        Supports auto-negotiation: No
        Supported FEC modes: Not reported
        Advertised link modes:  Not reported
        Advertised pause frame use: No
        Advertised auto-negotiation: No
        Advertised FEC modes: Not reported
        Speed: 1000Mb/s
        Duplex: Full
        Port: Other
        PHYAD: 0
        Transceiver: internal
        Auto-negotiation: off
        Link detected: yes
```

Displays [Interface] NIC information. [Shell 1] shows the output of `ethtool eth0` displaying eth0 interface information. In [Shell 1], you can check the bandwidth (speed) and duplex mode of eth0.

### 1.2. ethtool [Interface] [speed 10|100|1000] [duplex half|full]

Sets the bandwidth (speed) and duplex mode of [Interface] NIC.

