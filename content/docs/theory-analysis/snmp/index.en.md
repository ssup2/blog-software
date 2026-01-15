---
title: SNMP
---

## 1. SNMP (Simple Network Management Protocol)

SNMP (Simple Network Management Protocol) is a UDP-based Protocol created for Network management, as the name suggests. Through SNMP, Network Topology can be drawn and Network performance and status information of each Network Segment can be understood. Also, using SNMP's flexibility, Metric information related to CPU, Memory, and Storage of devices participating in Network can also be collected. SNMP has three versions: v1, v2c, and v3. v2c added Bulk-related functionality to bring large amounts of data at once from Agent compared to v1, and v3 added authentication and security-related functionality compared to v2.

{{< figure caption="[Figure 1] SNMP Architecture" src="images/snmp-architecture.png" width="500px" >}}

[Figure 1] shows the Architecture of SNMP. SNMP consists of Manager and Agent, and the Protocol used for communication between Manager and Agent is SNMP. In [Figure 1], there is a Master Agent that manages multiple Agents, but from Manager's perspective, Master Agent is not treated differently from general Agents. Agents obtain related data from a Database called MIB by Manager's request or by themselves and deliver it to Manager.

### 1.1. MIB (Management Information Base)

{{< figure caption="[Figure 2] OID Tree for MIB" src="images/oid-tree.png" width="1000px" >}}

MIB (Management Information Base) refers to a Database that manages data held by devices participating in Network. Data in MIB is managed in Tree form and OID (Object ID) is used as data identifier. Since OID uses Tree-form hierarchical structure, it is suitable as an identifier for MIB data that manages data in Tree form.

[Figure 2] shows OID Tree to represent MIB. Through OID Tree, what data OID means can be understood. If OID starts with "1.3.6.1.2.1", following numbers from the front of OID from Root of OID Tree shows that it represents MIB-related data. Also, if OID is "1.3.6.1.2.1.4", it can be understood that it represents IP of MIB. If Manager wants to obtain IP information of a specific device through Agent, it requests OID "1.3.6.1.2.1.4" to obtain device's IP information.

### 1.2. SNMP Message Type

The following types exist in SNMP Protocol's Message Type. Message Type, SNMP Version where that Message Type was introduced, and direction where Message is transmitted are also shown.

* GetRequest / v1 / Manager->Agent : Used for Manager to obtain specific data of MIB through Agent.
* GetNextRequest / v1 / Manager->Agent : Used for Manager to traverse Tree structure data stored in MIB through Agent. Manager receives one data response each time it sends GetNextRequest request to Agent.
* GetBulkRequest/ v2 / Manager->Agent : Bulk version of GetNextRequest. Used to receive all data of Subtree among Tree structure data stored in MIB.
* SetRequest/ v1 / Manager->Agent : Used for Manager to set specific data in MIB through Agent.
* GetResponse/ v1 / Agent->Manager : Used for responses to Manager's Get/Set-related requests.
* Trap / v1 / Agent->Manager : Used when Agent sends MIB data to Manager first, not because of Manager's request.
* InfoRequest / v2 / Manager->Agent : Used for Manager to verify if Trap Message received from Agent is correct.

## 2. References

* [https://www.joinc.co.kr/w/Site/SNMP/document/Intro-net-snmp](https://www.joinc.co.kr/w/Site/SNMP/document/Intro-net-snmp)
* [https://blog.naver.com/koromoon/120183340921](https://blog.naver.com/koromoon/120183340921)
* [https://www.ittsystems.com/what-is-snmp/](https://www.ittsystems.com/what-is-snmp/)
* [https://www.comparitech.com/net-admin/snmp-mibs-oids-explained/](https://www.comparitech.com/net-admin/snmp-mibs-oids-explained/)
* [https://www.paessler.com/it-explained/snmp](https://www.paessler.com/it-explained/snmp)

