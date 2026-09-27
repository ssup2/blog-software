---
title: OpenStack Network, Neutron
---

This post examines the Network Concept of OpenStack and analyzes Neutron, the Service that controls the Network in OpenStack.

## 1. OpenStack Network

{{< figure caption="[Figure 1] OpenStack Network Classification" src="images/openstack-network.png" width="700px" >}}

OpenStack Network can be approached from the perspective of the Provider, who provides the Cloud using OpenStack, and from the perspective of the User, who uses the Cloud. [Figure 1] shows the OpenStack Network. From the Provider's perspective, the Network can be classified into four types: Management, Guest, External, and API.

* **Management Network** : The Network used by the Services that make up OpenStack. It generally uses the physical Network (VLAN) between Nodes.
* **Guest Network** : The Network used for communication between VMs. It generally uses a VXLAN/GRE-based virtual Network, but it can also be configured with a physical Network (VLAN).
* **External Network** : The Network used when VMs communicate with the outside. It generally uses the physical Network (VLAN) between Nodes.
* **API Network** : The Network that serves as the channel exposing OpenStack's Service APIs to Users. It generally uses the physical Network (VLAN) between Nodes.

From the User's perspective, the Network can be classified into two types: Provider Network and Self-service Network.

* **Provider Network** : A Network created by the Provider. The Provider can create both a physical Network (VLAN)-based Network and a VXLAN/GRE-based virtual Network. The Guest and External Networks from the Provider's perspective can be considered Provider Networks. For a VM to be connected to a physical Network (VLAN)-based Provider Network, that physical Network must also be connected to the Compute Node.
* **Self-service Network** : A virtual Network created by the User. The User can only create VXLAN/GRE-based virtual Networks. The Guest Network from the Provider's perspective can be considered a Self-service Network.

## 2. OpenStack Neutron

{{< figure caption="[Figure 2] Neutorn Architecture" src="images/neutron-architecture.png" width="700px" >}}

**Neutron** is the Service responsible for all Networks in OpenStack. Neutron helps Providers or Users easily create and configure most of the Network components required for Infra configuration, such as Networks, Subnets, Routers, and LBs. [Figure 2] shows the Architecture of Neutron. Neutron consists of the Neutron Server, which performs the Master role, and the ML2 Plugin Agent, L3 Agent, DHCP Agent, Meta Agent, and others, which perform the Slave role.

Communication between the Neutron Server and the Agents uses a Message Queue. The Neutron Server and Agents use RPC (Remote Procedure Call) when communicating with the Message Queue. When a separate SDN Service cooperates with Neutron to control the Network, Neutron and the SDN Service communicate via REST API.

* **Neutron Server** : The Neutron Server runs on the Controller Node, provides the Network API to Providers or Users, and performs the Master role of controlling the overall OpenStack Network according to requests. The Neutron Server is composed of Plugins, which are divided into Core Plugins and Service Plugins. The Core Plugin performs functions related to Networks and Subnets. The Service Plugin performs functions related to Network L3, such as Routers, LBs, and Firewalls.
* **ML2 Plugin Agent** : Runs on the Network Node or Compute Node and controls Network L2, such as VLANs, Bridges, and OVS (Open V Switch), according to commands from the Neutron Server.
* **L3 Agent** : Runs on the Network Node and controls Network L3, such as Routers and Firewalls, according to commands from the Neutron Server.
* **Meta Agent** : Obtains the VM Metadata needed for VM initialization from Nova and delivers it to Cloud-Init or Cloudbase, which performs VM initialization inside the VM. VM Metadata requests coming from Cloud-Init or Cloudbase are delivered to the Meta Agent through the Router's Routing Rule and the Meta Proxy, of which one exists per Router. The Meta Agent obtains the VM ID by passing the ID of the Router from which the VM Metadata request came and the VM IP information in the VM Metadata request Packet to the Neutron Server. Then, the Meta Agent uses the VM ID to deliver the VM Metadata obtained from Nova to the Cloud-Init or Cloudbase of that VM.
* **DHCP Agent** : Controls the DHCP Server that assigns IPs to VMs. It also manages a separate Meta Proxy that takes the place of the Router's Meta Proxy. When a VM is connected to an isolated network not connected to a Router, the DHCP Agent's Meta Proxy passes the isolated Network ID and the VM IP information in the VM Metadata request Packet to the Meta Agent, helping the Meta Agent obtain the VM Metadata.

### 2.1. Management/Provider/Self-service Network, Router, DHCP

This section analyzes how the Management Network, Provider Network, Self-service Network, Router, and DHCP Server are actually configured depending on the presence or absence of OVS (Open vSwitch). It is assumed that the Management Network is configured as a Flat Network that directly uses the Node's Network without using VLAN. It is also assumed that the first Guest Network is configured as the VLAN 10 Network and the second Guest Network is configured as the VXLAN 20 Network.

#### 2.1.1. Without OVS

{{< figure caption="[Figure 3] Compute Node Network without OVS" src="images/compute-node-no-ovs.png" width="700px" >}}

[Figure 3] shows the Network configuration of the Compute Node without OVS. `eth0` is connected to the Management Network. Since the first Guest Network uses VLAN 10, a VLAN 10 Interface is set on the `eth0` Interface along with a Bridge used to attach VMs to VLAN 10. Similarly, since the second Guest Network uses VXLAN 20, a VXLAN 20 Interface is set on the `eth0` Interface along with a Bridge used to attach VMs to VXLAN 20. All Inbound/Outbound Packets of a VM pass through the Bridge and are filtered by the Filter Table of iptables configured according to the Rules of OpenStack's Security Group.

Since VM A is connected only to the Provider Network, VM A's TAP Interface is connected only to the Bridge connected to the VLAN 10 Interface. Since VM C is connected only to the Self-serviced Network, VM C's TAP Interface is connected only to the Bridge connected to the VLAN 20 Interface. Since VM B is connected to both Networks, it is connected to all Bridges using VM B's two TAP Interfaces. The Bridges, VLAN Interface, and VXLAN Interface are all configured by the ML2 Plugin Agent.

{{< figure caption="[Figure 4] Network Node Network without OVS" src="images/network-node-no-ovs.png" width="700px" >}}

[Figure 4] shows the Network configuration of the Network Node without OVS. `eth1` is connected to the Management Network, and `eth0` is connected to the External/Provider Network. Similar to the Compute Node, the VLAN 10 Interface, VXLAN 20 Interface, and related Bridges are configured. In addition, a separate Bridge is configured for connection to the External/Provider Network. The Bridges, VLAN Interface, and VXLAN Interface are configured by the ML2 Plugin Agent.

A Router and a Network Namespace have a 1:1 relationship. Since each Router uses a separate Network Namespace, each Router can configure a completely independent Routing Table. The Router in [Figure 4] is a Router that connects the External/Provider Network, Guest/Provider Network, and Guest/Self-service Network. Packets are sent to the Router Network Namespace using VETH Interfaces on the Bridge connecting each Network. Packets sent to the Router Network Namespace are routed by the Routing Rules configured through iptables. Router configuration is performed by the L3 Agent.

The DHCP Server is configured by attaching dnsmasq to the Guest Network's Bridge on the Network Node. Since each dnsmasq runs in a separate Network Namespace, no conflicts occur even when multiple dnsmasq instances run on the Network Node. To send Packets to the dnsmasq's Network Namespace, VETH is used in the same way as the Router. dnsmasq configuration is performed by the DHCP Agent.

#### 2.1.2. With OVS

{{< figure caption="[Figure 5] Compute Node Network with OVS" src="images/compute-node-with-ovs.png" width="700px" >}}

[Figure 5] shows the Network configuration of the Compute Node using OVS. It is the same Network configuration as [Figure 3], but the difference is that it is configured using OVS. All TAP Interfaces connected to VMs are connected to the `br-int` OVS, which serves as the integration OVS, through Bridges and VETH. From `br-int`, VXLAN and GRE-based Guest Networks use the `br-tun` OVS. VLAN-based Networks use the `br-vlan` OVS. Since the first Guest Network uses VLAN, it uses the `br-vlan` OVS, and since the second Guest Network uses VXLAN, it uses the `br-tun` OVS.

All Inbound/Outbound Packets of a VM pass through the Bridge connected to the TAP Interface and are filtered by the Filter Table of iptables configured according to the Rules of OpenStack's Security Group. The TAP Interfaces, Bridges, VETH, and OVS are all configured by the ML2 Plugin Agent.

{{< figure caption="[Figure 6] Network Node Network with OVS" src="images/network-node-with-ovs.png" width="700px" >}}

[Figure 6] shows the Network configuration of the Network Node using OVS. It is the same Network configuration as [Figure 4], but the difference is that it is configured using OVS. All VETH Interfaces are connected to the `br-int` OVS, which serves as the integration OVS. From `br-int`, VXLAN and GRE-based Guest Networks use the `br-tun` OVS, and VLAN-based Networks use the `br-vlan` OVS. Additionally, the External Network uses the `br-ex` OVS. The OVS is configured by the ML2 Plugin Agent.

## 3. References

* OpenStack Installation Guide : [https://docs.openstack.org/install-guide/](https://docs.openstack.org/install-guide/)
* OpenStack Networking Architecture : [https://docs.openstack.org/security-guide/networking/architecture.html](https://docs.openstack.org/security-guide/networking/architecture.html)
* Scenario: Classic with Open vSwitch : [https://docs.openstack.org/liberty/networking-guide/scenario-classic-ovs.html](https://docs.openstack.org/liberty/networking-guide/scenario-classic-ovs.html)
* Scenario: Classic with Linux Bridge : [https://docs.openstack.org/liberty/networking-guide/scenario-classic-lb.html](https://docs.openstack.org/liberty/networking-guide/scenario-classic-lb.html)
* How VMs Get Access to the Metadata in Neutron : [https://www.suse.com/c/vms-get-access-metadata-neutron/](https://www.suse.com/c/vms-get-access-metadata-neutron/)
