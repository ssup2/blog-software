---
title: Kubernetes ClusterAPI Architecture on OpenStack
---

This post analyzes the architecture of Kubernetes Cluster API running on an OpenStack environment.

## 1. Kubernetes ClusterAPI Architecture on OpenStack

{{< figure caption="[Figure 1] Kubernetes ClusterAPI Architecture on OpenStack" src="images/kubernetes-clusterapi-architecture-openstack.png" width="1000px" >}}

[Figure 1] shows the architecture of Kubernetes ClusterAPI on an OpenStack environment. A ClusterAPI User creates a Cluster by creating Cluster-related Objects (CRDs) in the ClusterAPI Kubernetes Cluster. Various ClusterAPI Clusters exist in the ClusterAPI Kubernetes Cluster. They can be largely classified into the ClusterAPI Controller, which serves as the ClusterAPI Interface, and the ClusterAPI OpenStack Provider Controller, which actually creates and manages User Kubernetes Clusters on OpenStack through this Interface.

Cluster-related Objects are defined through Kubernetes CRDs (Custom Resource Definitions) and are managed by the ClusterAPI Controller and the ClusterAPI OpenStack Provider Controller. Although various kinds of Cluster-related Objects exist, they largely consist of Control Plane information corresponding to the Master Nodes of a User Kubernetes Cluster, Machine information corresponding to the Worker Nodes of a User Kubernetes Cluster, and the Root CA (certificate authority) Certificate/Key Objects of a User Kubernetes Cluster.

[Figure 1] shows two ClusterAPI User Kubernetes Clusters created through ClusterAPI. Each User Kubernetes Cluster consists of four components: Master Nodes (Control Plane), Worker Nodes, a Load Balancer, and a Bastion Node. A Master Node refers to a Node that plays the Master role running the Kubernetes API Server and the Kubernetes Controller Manager in the Kubernetes Cluster, and a Worker Node refers to a Node where App Containers run in the Kubernetes Cluster.

The Load Balancer plays the role of bundling multiple Master Nodes and providing a single Master Node VIP (Endpoint). Here, the Master Node VIP created by the Load Balancer is a **VIP on the External Network**. Therefore, the `kubectl` Client of a Cluster User on the External Network communicates with the Kubernetes API Server through the Master Node VIP created by the Load Balancer. The Worker Nodes of a User Cluster also communicate with the Master Nodes using the Master Node VIP on the External Network created by the Load Balancer. Therefore, the Network must be configured so that the Master Node VIP on the External Network is reachable from inside each Cluster Network as well.

ClusterAPI configures Security Groups so that only the minimum Ports required to compose the Kubernetes Cluster are open on each Node of a User Cluster. Therefore, by default, each Node of a User Cluster cannot be accessed via SSH. The Bastion Node serves as a passage that helps the Cluster User access the Nodes of the User Cluster via SSH. The Cluster User accesses the Bastion Node via SSH, and then can access the Nodes of the User Cluster via SSH again from the Bastion Node.

## 2. References

* The Cluster API Book : [https://cluster-api.sigs.k8s.io/](https://cluster-api.sigs.k8s.io/)
* kubernetes-sigs/cluster-api-provider-openstack : [https://github.com/kubernetes-sigs/cluster-api-provider-openstack](https://github.com/kubernetes-sigs/cluster-api-provider-openstack)
