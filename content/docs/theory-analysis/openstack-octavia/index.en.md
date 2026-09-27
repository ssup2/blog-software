---
title: OpenStack Octavia
---

This post analyzes OpenStack's Octavia.

## 1. OpenStack Octavia

{{< figure caption="[Figure 1] OpenStack Octavia Concept" src="images/octavia-concept.png" width="800px" >}}

**Octavia** is an OpenStack Service that provides LBaaS (Load Balancer as a Service). [Figure 1] shows the Concept of Octavia. A Load Balancer means one VIP (Virtual IP). A Listener means one Port. In [Figure 1], there is one Listener each in charge of Port A and Port B. A Pool means a set of Members, which are the Servers that become the destinations of Packets, and each Listener is mapped to a specific Pool. In [Figure 1], Listeners and Pools are mapped 1:1, but multiple Listeners can also share a single Pool. A Health Monitor is responsible for the Health Check of the Members in a Pool, and performs the role of preventing Packets from being load balanced to Members that fail the Health Check.

```console {caption="[Shell 1] OpenStack Octavia Resource", linenos=table}
# openstack loadbalancer show b13ce3b9-381f-4d33-9443-b7fc30619350
+---------------------+-------------------------------------------------------------------+
| Field               | Value                                                             |
+---------------------+-------------------------------------------------------------------+
| admin-state-up      | True                                                              |
| created-at          | 2020-03-27T13:36:28                                               |
| description         | Kubernetes external service default/a-svc from cluster kubernetes |
| flavor-id           | None                                                              |
| id                  | b13ce3b9-381f-4d33-9443-b7fc30619350                              |
| listeners           | e69d05f9-87cf-4952-b090-6ff9a78f6420                              |
| name                | kube-service-kubernetes-default-a-svc                             |
| operating-status    | DEGRADED                                                          |
| pools               | d335f906-01c3-4d25-ae6b-77a21e72fe2f                              |
| project-id          | b21b68637237488bbb5f33ac8d86b848                                  |
| provider            | amphora                                                           |
| provisioning-status | ACTIVE                                                            |
| updated-at          | 2020-03-29T12:06:32                                               |
| vip-address         | 30.0.0.117                                                        |
| vip-network-id      | e1427325-87d0-4478-a6a3-301b8fdf15a3                              |
| vip-port-id         | 3cb932d3-7ae8-4e27-a8ea-66583eee2f37                              |
| vip-qos-policy-id   | None                                                              |
| vip-subnet-id       | 67ca5cfd-0c3f-434d-a16c-c709d1ab37fb                              |
+---------------------+-------------------------------------------------------------------+

# openstack loadbalancer listener show e69d05f9-87cf-4952-b090-6ff9a78f6420
+-----------------------------+--------------------------------------------------+
| Field                       | Value                                            |
+-----------------------------+--------------------------------------------------+
| admin-state-up              | True                                             |
| connection-limit            | -1                                               |
| created-at                  | 2020-03-27T13:39:34                              |
| default-pool-id             | d335f906-01c3-4d25-ae6b-77a21e72fe2f             |
| default-tls-container-ref   | None                                             |
| description                 |                                                  |
| id                          | e69d05f9-87cf-4952-b090-6ff9a78f6420             |
| insert-headers              | None                                             |
| l7policies                  |                                                  |
| loadbalancers               | b13ce3b9-381f-4d33-9443-b7fc30619350             |
| name                        | listener-0-kube-service-kubernetes-default-a-svc |
| operating-status            | ONLINE                                           |
| project-id                  | b21b68637237488bbb5f33ac8d86b848                 |
| protocol                    | TCP                                              |
| protocol-port               | 80                                               |
| provisioning-status         | ACTIVE                                           |
| sni-container-refs          | []                                               |
| timeout-client-data         | 50000                                            |
| timeout-member-connect      | 5000                                             |
| timeout-member-data         | 50000                                            |
| timeout-tcp-inspect         | 0                                                |
| updated-at                  | 2020-03-27T13:39:54                              |
| client-ca-tls-container-ref | None                                             |
| client-authentication       | NONE                                             |
| client-crl-container-ref    | None                                             |
+-----------------------------+--------------------------------------------------+

# openstack loadbalancer pool show d335f906-01c3-4d25-ae6b-77a21e72fe2f
+----------------------+----------------------------------------------+
| Field                | Value                                        |
+----------------------+----------------------------------------------+
| admin-state-up       | True                                         |
| created-at           | 2020-03-27T13:39:40                          |
| description          |                                              |
| healthmonitor-id     | 9eea2d84-6e65-471b-ac86-bbf5f7e849ed         |
| id                   | d335f906-01c3-4d25-ae6b-77a21e72fe2f         |
| lb-algorithm         | ROUND-ROBIN                                  |
| listeners            | e69d05f9-87cf-4952-b090-6ff9a78f6420         |
| loadbalancers        | b13ce3b9-381f-4d33-9443-b7fc30619350         |
| members              | 9e5d179f-8b89-4ede-af5b-70560e6775d3         |
|                      | 642665e0-9552-4afd-bcde-9dcd769ad225         |
| name                 | pool-0-kube-service-kubernetes-default-a-svc |
| operating-status     | DEGRADED                                     |
| project-id           | b21b68637237488bbb5f33ac8d86b848             |
| protocol             | TCP                                          |
| provisioning-status  | ACTIVE                                       |
| session-persistence  | None                                         |
| updated-at           | 2020-03-29T12:11:43                          |
| tls-container-ref    | None                                         |
| ca-tls-container-ref | None                                         |
| crl-container-ref    | None                                         |
| tls-enabled          | False                                        |
+----------------------+----------------------------------------------+

# openstack loadbalancer healthmonitor show 9eea2d84-6e65-471b-ac86-bbf5f7e849ed
+---------------------+--------------------------------------------------+
| Field               | Value                                            |
+---------------------+--------------------------------------------------+
| project-id          | b21b68637237488bbb5f33ac8d86b848                 |
| name                | monitor-0-kube-service-kubernetes-default-a-svc) |
| admin-state-up      | True                                             |
| pools               | d335f906-01c3-4d25-ae6b-77a21e72fe2f             |
| created-at          | 2020-03-27T13:39:51                              |
| provisioning-status | ACTIVE                                           |
| updated-at          | 2020-03-27T13:39:54                              |
| delay               | 60                                               |
| expected-codes      | None                                             |
| max-retries         | 3                                                |
| http-method         | None                                             |
| timeout             | 30                                               |
| max-retries-down    | 3                                                |
| url-path            | None                                             |
| type                | TCP                                              |
| id                  | 9eea2d84-6e65-471b-ac86-bbf5f7e849ed             |
| operating-status    | ONLINE                                           |
| http-version        | None                                             |
| domain-name         | None                                             |
+---------------------+--------------------------------------------------+
```

These Concept Components of Octavia are managed as Octavia Resources. [Shell 1] shows the Shell that queries Octavia's Resources using the `openstack` CLI. This Octavia Concept is identical to Neutron LBaaS V2, and Octavia also has the characteristic of supporting the Neutron LBaaS V2 API as is.

### 1.1. Architecture

{{< figure caption="[Figure 2] OpenStack Octavia Architecture" src="images/octavia-architecture.png" width="900px" >}}

[Figure 2] shows the Architecture of Octavia. The Octavia Service runs on the Controller Node, and Amphora, Octavia's Load Balancer Instance, runs on the Compute Node. Amphora can be configured as a VM, PM, or Container. Communication between the Octavia Service and Amphora generally takes place through a dedicated Octavia Network created by the Provider.

When the Octavia Client requests LB creation from the API Controller of the Octavia Service, the API Controller creates an Amphora with the help of other OpenStack Services such as Nova and Neutron. When the Amphora creation is complete, the Controller Worker of the Octavia Service creates the HAProxy Config file through the Amphora's Agent and starts HAProxy. The Health Check of Members is performed by HAProxy according to the Agent's configuration. The Health status of Members collected by HAProxy is delivered to the Agent through a Unix Socket, and the Agent in turn delivers it to the Controller Worker.

The Controller Worker reflects the received Health status of Members in Octavia's Member Resource. The Housekeeping Manager performs the role of completely removing deleted Resources from the Octavia DB and managing the Certificates of Amphora. Amphora operates as Standalone or as Active-Standby for HA. [Figure 1] shows Amphora operating in the Active-Standby form.

```text {caption="[File 1] amphora-agent.conf", linenos=table}
[DEFAULT]
debug = False

[haproxy-amphora]
base-cert-dir = /var/lib/octavia/certs
base-path = /var/lib/octavia
bind-host = ::
bind-port = 9443
haproxy-cmd = /usr/sbin/haproxy
respawn-count = 2
respawn-interval = 2
use-upstart = True

[health-manager]
controller-ip-port-list = 192.168.0.31:5555
heartbeat-interval = 10
heartbeat-key = insecure

[amphora-agent]
agent-server-ca = /etc/octavia/certs/client-ca.pem
agent-server-cert = /etc/octavia/certs/server.pem
agent-request-read-timeout = 180
amphora-id = c7e877d5-f1c6-4fb2-a9fb-214cb7cc793a
amphora-udp-driver = keepalived-lvs

[controller-worker]
loadbalancer-topology = ACTIVE-STANDBY
```

[File 1] shows the Agent's Config file. The HAProxy configuration, Health Manager configuration, and Amphora operation mode configuration can be found in it.

```console {caption="[Shell 2] HAProxy Network Namespace in Amphora", linenos=table}
# ip netns list
amphora-haproxy

# ip netns exec amphora-haproxy ip a
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
3: eth1: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1450 qdisc pfifo-fast state UP group default qlen 1000
    link/ether fa:16:3e:f0:b8:43 brd ff:ff:ff:ff:ff:ff
    inet 30.0.0.123/24 brd 30.0.0.255 scope global eth1
       valid-lft forever preferred-lft forever
```

HAProxy uses a dedicated HAProxy Network Namespace rather than the Amphora's Network Namespace. [Shell 2] shows the Interface that holds the VIP in the HAProxy Network Namespace.

## 2. References

* OpenInfra Days Korea 2018 - Neutron LBaaS & Octavia : [https://www.slideshare.net/openstack-kr/openinfra-days-korea-2018-track-2-neutron-lbaas-octavia](https://www.slideshare.net/openstack-kr/openinfra-days-korea-2018-track-2-neutron-lbaas-octavia)
* Load Balancer as a Service (LBaaS) - OpenStack Docs : [https://docs.openstack.org/mitaka/networking-guide/config-lbaas.html](https://docs.openstack.org/mitaka/networking-guide/config-lbaas.html)
* Introducing Octavia - OpenStack Docs : [https://docs.openstack.org/octavia/queens/reference/introduction.html](https://docs.openstack.org/octavia/queens/reference/introduction.html)
* Octavia - Red Hat OpenStack Platform Networking Guide : [https://access.redhat.com/documentation/en-us/red-hat-openstack-platform/13/html/networking-guide/sec-octavia](https://access.redhat.com/documentation/en-us/red-hat-openstack-platform/13/html/networking-guide/sec-octavia)
