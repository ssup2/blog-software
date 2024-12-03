---
title: OpenStack Octavia
---

OpenStack의 Octavia를 분석한다.

## 1. OpenStack Octavia

{{< figure caption="[Figure 1] OpenStack Octavia Concept" src="images/octavia-concept.png" width="800px" >}}

Octavia는 LBaaS (Load Balancer as a Service)를 제공하는 OpenStack의 Service이다. [Figure 1]은 Octavia의 Concept을 나타내고 있다. Load Balancer는 하나의 VIP (Virtual IP)를 의미한다. Listener는 하나의 Port를 의미한다. [Figure 1]에서는 Port A, Port B를 담당하는 Listener가 하나씩 존재하는걸 확인할 수 있다. Pool은 Packet의 목적지가 되는 Server를 의미하는 Member들의 집합을 의미하며, 각 Listener들은 특정 Pool과 Mapping된다. [Figure 1]에서는 Listener과 Pool은 1:1로 Mapping되어 있지만, 여러개의 Listener가 하나의 Pool을 공유할 수도 있다. Health Monitor는 Pool의 Member의 Health Check를 담당하며, Health Check에 실패한 Member로 Packet이 Load Balancing이 되지 않도록 하는 역할을 수행한다.

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

이러한 Octavia의 Concept Component는 Octavia의 Resource로 관리된다. [Shell 1]은 openstack CLI를 이용여 Octavia의 Resource를 조회하는 Shell을 나타내고 있다. 이러한 Octavia Concept은 Neutron LBaaS V2와 동일하며, Octavia는 Neutron LBaaS V2 API를 그대로 지원한다는 특징도 갖고 있다.

### 1.1. Architecture

{{< figure caption="[Figure 2] OpenStack Octavia Architecture" src="images/octavia-architecture.png" width="900px" >}}

[Figure 2]는 Octavia의 Architecture를 나타내고 있다. Controller Node에는 Octavia Service가 동작하고 있고, Octavia의 Load Balancer Instance인 Amphora는 Compute Node에서 동작한다. Amphora는 VM, PM, Container로 구성 가능하다. Octavia Service와 Amphora 사이의 통신은 일반적으로 Provider가 생성하는 Octvia 전용 Network를 통해서 이루어진다.

Octavia Client는 Octavia Service의 API Controller에게 LB 생성을 요청하면 API Controller는 Nova, Neutron 같은 다른 OpenStack Service의 도움을 받아 Amphora를 생성한다. Amphora 생성이 완료되면 Octavia Service의 Controller Worker는 Amphora의 Agent를 통해서 HAProxy의 Config 파일을 생성하고 HAProxy를 구동한다. Member의 Health Check는 Agent의 설정에 따라서 HAProxy가 수행한다. HAProxy가 수집한 Member의 Health 상태는 Unix Socket을 통해서 Agent에 전달되며, Agent는 다시 Controller Worker에게 전달한다.

Controller Worker는 전달 받은 Member의 Health 상태를 Octavia의 Member Resource에 반영한다. Housekeeping Manager는 삭제된 Resource를 Octavia DB에서 완전히 지우는 역할 및 Amphora의 Certificate를 관리하는 역할을 수행한다. Amphora는 Standalone 또는 HA를 위한 Active-Standby로 동작한다. [Figure 1]에서는 Active-Standby 형태로 동작하는 Amphora를 나타내고 있다.

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

[File 1]은 Agent의 Config 파일을 나타내고 있다. HAProxy 설정, Health Manager 설정, Amphora 동작 모드 설정들을 찾아볼수 있다. 

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

HAProxy는 Amphora의 Network Namespace가 아닌 HAProxy 전용 Network Namespace를 이용한다. [Shell 2]는 HAProxy Network Namespace에서 VIP를 갖고 있는 Interface를 나타내고 있다.

## 2. 참조

* [https://www.slideshare.net/openstack-kr/openinfra-days-korea-2018-track-2-neutron-lbaas-octavia](https://www.slideshare.net/openstack-kr/openinfra-days-korea-2018-track-2-neutron-lbaas-octavia)
* [https://docs.openstack.org/mitaka/networking-guide/config-lbaas.html](https://docs.openstack.org/mitaka/networking-guide/config-lbaas.html)
* [https://docs.openstack.org/octavia/queens/reference/introduction.html](https://docs.openstack.org/octavia/queens/reference/introduction.html)
* [https://access.redhat.com/documentation/en-us/red-hat-openstack-platform/13/html/networking-guide/sec-octavia](https://access.redhat.com/documentation/en-us/red-hat-openstack-platform/13/html/networking-guide/sec-octavia)

