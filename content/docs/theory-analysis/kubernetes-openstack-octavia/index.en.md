---
title: Kubernetes with OpenStack Octavia
---

This article analyzes the Load Balancer Service of Kubernetes that operates together with Octavia, the LBaaS (Load Balancer as a Service) of OpenStack.

## 1. Kubernetes with OpenStack Octavia

{{< figure caption="[Figure 1] Kubernetes with OpenStack Octavia" src="images/kubernetes-openstack-octavia.png" width="1000px" >}}

[Figure 1] shows Kubernetes operating with OpenStack Octavia. In [Figure 1], there is an OpenStack composed of one OpenStack Controller Node, one OpenStack Network Node, and two OpenStack Compute Nodes. On top of OpenStack, there is a single Kubernetes Cluster composed of one Kubernetes Master VM and three Kubernetes Slave VMs. Two Load Balancer Services, Service A and B, are configured in the Kubernetes Cluster. Therefore, two sets of Active-Standby LB VMs (Amphora VMs) exist, one for each Service.

[Figure 1] includes three Networks. The External Network is the Network that VMs use to communicate with the outside. The Octavia Network is the Network to which all of Octavia's LB VMs are connected. The Kubernetes Network is the Network that the Kubernetes VMs use to form the Kubernetes Cluster.

### 1.1. Octavia Operation

**Octavia** is the LBaaS of OpenStack. Kubernetes can provide the Load Balancer Service outside of OpenStack through Octavia. Octavia is composed of the Octavia Service running on the OpenStack Controller and LB VMs that load balance Packets. An LB VM is composed of HAProxy, which actually load balances Packets, and an Agent (Amphora Agent), which is in charge of communication with the Octavia Service. The Octavia Network is the Network used for communication between the Octavia Service and the Agent.

The Agent sends the Health information of HAProxy (LB VM) to the Octavia Service through the Octavia Network, and performs the role of receiving HAProxy configuration information from the Octavia Service and configuring HAProxy. The Agent also performs the role of sending the Health information of Octavia Member VMs, the VMs to which Packets are delivered through Load Balancing, to the Octavia Service. The Agent obtains the Health information of Octavia Member VMs through the `stats` Domain Socket provided by HAProxy. HAProxy performs Health Checks on the IP:Ports configured by the Agent, and sends Packets to those IP:Ports if their Health is normal. In a Kubernetes environment, the Agent configures HAProxy using the Slave IPs of the Kubernetes Cluster and the NodePort of the Kubernetes Service as the Port.

If a failure occurs in the Active HAProxy (LB VM), the Standby HAProxy is changed to the Active state through the VRRP Protocol and continues the Load Balancing operation. This Active/Standby operation of HAProxy proceeds without the intervention of the Octavia Service. The Octavia Service only updates the state information of the HAProxy it manages, based on the HAProxy state information sent from the Agent. If a failure occurs in an Octavia Member VM, the failed Octavia Member VM is excluded from Load Balancing by HAProxy's Health Check. This operation also proceeds without the intervention of the Octavia Service. The Octavia Service only performs the operation of adding/removing Octavia Member VMs in the Member Pool it manages, based on the Octavia Member VM state information that the Agent obtained from HAProxy.

In [Figure 1], the Octavia Service and the Agent are configured to use both the Octavia Network and the External Network at the same time, but it is not necessary to use the External Network together. It is sufficient to configure an environment where the Octavia Service and the Agent can communicate through the Octavia Network to which the LB VMs are connected. In [Figure 1], all LB VMs are shown to operate in the Active-Standby form, but they can be configured to operate Standalone through Octavia configuration.

### 1.2. Kubernetes Operation

When Kubernetes operates in integration with Octavia, the Kubernetes Controller Manager directly requests a Load Balancer from the Octavia Service and is allocated the required Load Balancer. Therefore, the Octavia Service does not know of the existence of Kubernetes and only performs the role of allocating and configuring Load Balancers as requested by the Kubernetes Controller Manager.

```text {caption="[Text 1] cloud_config", linenos=table}
[Global]
auth-url="http://192.168.0.40:5000/v3"
username="admin"
password="admin"
region="RegionOne"
tenant-id="b21b68637237488bbb5f33ac8d86b848"
domain-name="Default"

[LoadBalancer]
subnet-id=67ca5cfd-0c3f-434d-a16c-c709d1ab37fb
floating-network-id=00a8e738-c81e-45f6-9788-3e58186076b6
use-octavia=True
lb-method=ROUND_ROBIN

create-monitor=yes
monitor-delay=1m
monitor-timeout=30s
monitor-max-retries=3
```

For the Kubernetes Controller Manager to request a Load Balancer from the Octavia Service, various information is required, such as the URL of the Octavia Service, the User ID/PW for the Octavia Service, the Tenant ID of the OpenStack to which the Kubernetes VMs belong, the Subnet ID of the Kubernetes Network, and Load Balancer Options. All of this required information is stored in the `cloud_config` file of the Kubernetes Master VM. [Text 1] shows an actual `cloud_config` file.

The Global section of [Text 1] stores the User ID/PW, Tenant, and Region information of the Kubernetes VMs. The Load Balancer section stores Load Balancer related configuration information. `subnet-id` means the Subnet ID of the Kubernetes Network. `floating-network-id` means the External Network ID. `lb-method` means the Load Balancing algorithm. The monitor related settings determine the Octavia Member VM Monitoring policy.

The Kubernetes Controller Manager performs authentication/authorization through the `auth-url` in the Global section of [Text 1], finds out the URL of the Octavia Service, and sends a Load Balancer request to the Octavia Service. Therefore, the Network of the Kubernetes Master VM where the Kubernetes Controller Manager resides must be configured so that it can access the Octavia Service through the `auth-url`. [Figure 1] shows the state where the Kubernetes Master VM is configured to access the Octavia Service through the Kubernetes Network and the External Network. However, it is not necessary to use the Kubernetes Network and the External Network. Any Network environment where the Kubernetes Master VM can access the Octavia Service through the `auth-url` is sufficient.

Kubernetes always creates a NodePort when creating a Load Balancer Service, and configures iptables/IPVS on all VMs (Master, Slave) composing the Kubernetes Cluster so that a Packet whose Dest Port is the NodePort is delivered to the Load Balancer Service upon reception. After the NodePort creation and iptables/IPVS configuration are finished, the Kubernetes Controller Manager requests the Octavia Service to create a Load Balancer based on the created NodePort and the `cloud_config` file. At this time, the Kubernetes Controller Manager includes only the Slave VMs as Octavia Member VMs, excluding the Master VM to which the Master Role is assigned. When the Load Balancer creation is completed, the Kubernetes Controller Manager receives and stores the External Network IP of the created Load Balancer.

### 1.3. Packet Flow of the Load Balancer Service

When a Packet whose Dest IP is the IP of the Load Balancer Service is delivered to the External Network, the Virtual Router on the OpenStack Network Node DNATs the Packet and routes it to the Kubernetes Network. The Packet is delivered to the Active LB VM, and the Packet is DNATed by HAProxy to SlaveIP:NodePort and delivered to an arbitrary Kubernetes Slave VM that is an Octavia Member. The Kubernetes Slave VM DNATs and load balances the Packet once again according to the iptables/IPVS Rules and delivers the Packet to a Pod belonging to the Load Balancer Service.

Looking at the process where a Packet is delivered from the outside to a Pod, Load Balancing is performed once by HAProxy in the LB VM and once again by the iptables/IPVS Rules of the Slave VM. To remove the Load Balancing by the iptables/IPVS Rules of the Slave VM and perform only the Load Balancing by HAProxy, set the `externalTrafficPolicy Local` Option when creating the LoadBalancer Service in Kubernetes.

When the `externalTrafficPolicy Local` Option is set, the Slave VM does not perform Load Balancing by the iptables/IPVS Rules. Also, only the NodePort of the Slave VM where the destination Pod of the Packet is running operates normally. Therefore, when HAProxy performs a Health Check, only the Slave VMs where the destination Pod of the Packet is running succeed in the Health Check, and the Slave VMs where the destination Pod of the Packet is not running fail the Health Check. HAProxy performs Load Balancing only on the Slave VMs, where the destination Pod of the Packet is located, that succeeded in the Health Check, and delivers the Packet to the Pod. The `externalTrafficPolicy Local` Option also performs the role of preserving the Src IP:Port of the Packet.

## 2. Kubernetes with OpenStack Octavia and OpenStack CCM

{{< figure caption="[Figure 2] Kubernetes with OpenStack Octavia and OpenStack CCMs" src="images/kubernetes-openstack-octavia-ccm.png" width="1000px" >}}

Currently, Kubernetes is in the process of separating the parts dependent on existing Cloud Providers into separate Controllers. Kubernetes can be configured to use the OpenStack CCM (Cloud Controller Manager) for the parts dependent on OpenStack. [Figure 2] shows Kubernetes operating with Octavia when using the OpenStack CCM. It is identical to [Figure 1] except that the OpenStack CCM, instead of the Kubernetes Controller Manager, requests Load Balancers from the Octavia Service.

## 3. References

* kubernetes/cloud-provider: the shared interfaces which Kubernetes cloud providers implement : [https://github.com/kubernetes/cloud-provider](https://github.com/kubernetes/cloud-provider)
