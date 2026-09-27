---
title: AWS EKS Network, Load Balancer
---

This post analyzes the Network and Load Balancer of AWS EKS.

## 1. AWS EKS Network

{{< figure caption="[Figure 1] AWS EKS Network" src="images/aws-eks-network.png" width="900px" >}}

[Figure 1] shows the Network configuration of AWS EKS. The EKS Control Plane and Nodes belong to separate VPCs (Networks). The Control Plane consists of multiple AZs to provide high availability. The Kubernetes API Servers located inside the Control Plane can be configured whether to be exposed to the External Network. If they are not exposed to the External Network, the Kubernetes API Server can only be accessed from inside the Node VPC.

The path a Kubernetes Client (kubectl, kubelet) takes to access the Kubernetes API Server differs depending on the location of the Kubernetes Client. When the Kubernetes Client exists in the External Network, it accesses an arbitrary Kubernetes API Server through the Kubernetes API Load Balancer that groups the Kubernetes API Servers. When the Kubernetes Client accesses the Kubernetes API Server from inside the EKS Node VPC, it accesses the Kubernetes API Server in the same AZ through the ENI in the same AZ.

The reason the Network path can be configured differently depending on the location of the Kubernetes Client is that Route 53 is utilized appropriately. A Domain in the form of `xxx.eks.amazonaws.com` is assigned to the Kubernetes API Server. When the Domain of the Kubernetes API Server is queried from inside the External Network, Route 53 returns the IP of the Kubernetes API LB, and when the Domain of the Kubernetes API Server is queried from inside an EKS Node VPC AZ, Route 53 returns the IP of the ENI in the same AZ.

When creating a Node Group, the AZs the Node Group will use can be configured, and when configured to use multiple AZs, the Nodes of the Node Group are evenly distributed across the multiple AZs. Therefore, even if a failure occurs in a specific AZ, some Nodes of the Node Group are still available, securing high availability for the App Service. [Figure 1] also shows that the Nodes of Node Group A and B belong to different Subnets.

For an App Service Client outside the EKS Cluster to access an App Service Server inside the EKS Cluster, it must go through an AWS Load Balancer (NLB, CLB, ALB) configured by the EKS Load Balancer.

{{< figure caption="[Figure 2] AWS EKS Pod Network" src="images/aws-eks-pod-network.png" width="700px" >}}

[Figure 2] shows the Network of Pods inside the EKS Cluster. The **AWS VPC CNI**, which is installed by default when configuring an EKS Cluster, does not build an Overlay Network for Pods but shares the Subnet the Node belongs to. Therefore, the Pod's IP belongs to the Subnet of the Node where the Pod is located. In [Figure 2], since Node A belongs to the `192.168.0.0/24` Subnet, the Pods on Node A also belong to the `192.168.0.0/24` Subnet.

```shell {caption="[Shell 1] Node, Pod Address"}
$ kubectl get node
NAME                                                STATUS   ROLES    AGE     VERSION              INTERNAL-IP      EXTERNAL-IP     OS-IMAGE         KERNEL-VERSION                  CONTAINER-RUNTIME
ip-192-168-46-6.ap-northeast-2.compute.internal     Ready    <none>   2d21h   v1.18.9-eks-d1db3c   192.168.46.6     52.79.236.233   Amazon Linux 2   4.14.225-169.362.amzn2.x86_64   docker://19.3.13
ip-192-168-48-175.ap-northeast-2.compute.internal   Ready    <none>   2d21h   v1.18.9-eks-d1db3c   192.168.48.175   3.35.24.235     Amazon Linux 2   4.14.225-169.362.amzn2.x86_64   docker://19.3.13
ip-192-168-75-136.ap-northeast-2.compute.internal   Ready    <none>   2d21h   v1.18.9-eks-d1db3c   192.168.75.136   52.78.17.141    Amazon Linux 2   4.14.225-169.362.amzn2.x86_64   docker://19.3.13
ip-192-168-90-3.ap-northeast-2.compute.internal     Ready    <none>   2d21h   v1.18.9-eks-d1db3c   192.168.90.3     3.36.73.81      Amazon Linux 2   4.14.225-169.362.amzn2.x86_64   docker://19.3.13

$ kubectl get pod -o wide
NAME                        READY   STATUS    RESTARTS   AGE     IP               NODE                                                NOMINATED NODE   READINESS GATES
my-nginx-5dc4865748-6pr9g   1/1     Running   0          7m51s   192.168.68.109   ip-192-168-90-3.ap-northeast-2.compute.internal     <none>           <none>
my-nginx-5dc4865748-8snkt   1/1     Running   0          7m51s   192.168.73.93    ip-192-168-75-136.ap-northeast-2.compute.internal   <none>           <none>
my-nginx-5dc4865748-g2xzk   1/1     Running   0          7m51s   192.168.36.89    ip-192-168-46-6.ap-northeast-2.compute.internal     <none>           <none>
my-nginx-5dc4865748-m5fhq   1/1     Running   0          7m51s   192.168.63.206   ip-192-168-48-175.ap-northeast-2.compute.internal   <none>           <none>
```

[Shell 1] shows the IPs of actual EKS Cluster Nodes and EKS Cluster Pods. The `ip-192-168-46-6.ap-northeast-2.compute.internal` and `ip-192-168-48-175.ap-northeast-2.compute.internal` Nodes belong to the `192.168.32.0/19` Subnet, and the `ip-192-168-75-136.ap-northeast-2.compute.internal` and `ip-192-168-90-3.ap-northeast-2.compute.internal` Nodes belong to the `192.168.64.0/19` Subnet. It can be seen that the Pods on each Node also belong to the corresponding Subnet.

{{< figure caption="[Figure 3] AWS EKS Pod Network in Node" src="images/aws-eks-pod-network-node.png" width="800px" >}}

[Figure 3] shows how the Pod Network is configured inside a Node. The EKS CNI (Container Network Interface) Plugin is responsible for configuring the Pod Network inside the Node. `eth0` assigned to the Node is the Network Interface the Node uses by default when the Node is created. `eth1` and `eth2` are ENIs (Elastic Network Interfaces) that the EKS CNI Plugin dynamically creates by requesting them from AWS. The Pod's IP is assigned here as a **Secondary IP**. Therefore, when a Packet whose Dest IP is a Pod IP is transmitted in the Subnet, the Packet is transmitted to the Node where the destination Pod exists. Afterwards, the Packet is transmitted again to the Pod according to the Node's Routing Table.

Since the Pod Network uses ENIs and the Secondary IPs assigned to ENIs, the maximum number of Pods that can be created on a single Node is determined by the number of ENIs that can be created on the Node and the number of Secondary IPs that can be assigned to each ENI. The number of ENIs that can be created on a Node and the number of Secondary IPs that can be assigned to each ENI vary depending on the Node's specification (Flavor). The higher the specification, the more ENIs can be created and the more Secondary IPs can be assigned to each ENI, so the number of Pods that can be created also increases.

```text {caption="[Formula 1] Maximum Number of Pods per Node"}
Node의 최대 ENI 개수 × (ENI에 설정될 수 있는 최대 IP 개수 - 1)
```

The number of ENIs and the number of Secondary IPs that can be assigned to each ENI according to the Node's specification can be found in the [Guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html), and the maximum number of Pods that can be assigned can be calculated by [Formula 1]. Even if no Pod exists on a Node, the EKS CNI Plugin always creates one ENI on the Node.

## 2. AWS EKS Load Balancer

For an App Client outside the EKS Cluster to access an App Server inside the EKS Cluster, the EKS Load Balancer must be used. In an EKS Cluster, all the Load Balancers provided by AWS — CLB, NLB, and ALB — can be used.

#### 2.1. CLB (Classic Load Balancer), NLB (Network Load Balancer)

{{< figure caption="[Figure 4] AWS EKS CLB, NLB" src="images/aws-eks-clb-nlb.png" width="900px" >}}

In an EKS Cluster, creating a **LoadBalancer Service** makes the Service accessible from outside the EKS Cluster through a CLB or NLB. When using a CLB or NLB, the Packet path changes according to a setting called the **Target Type** and the **ExternalTrafficPolicy** setting of the LoadBalancer Service. [Figure 4] shows the Packet paths according to the settings when using CLB and NLB in an EKS Cluster.

The Target Type is a setting that determines how the Dst IP/Port of the Packets sent by the CLB or NLB is set. The Target Type has an **Instance Type** and an **IP Type**. The Instance Type can be used with both CLB and NLB. In the case of the Instance Type, the CLB or NLB sets the Dst IP/Port of the Packets it sends to the **NodePort** of the LoadBalancer Service and transmits them. Afterwards, the Packet the Node receives through the NodePort of the LoadBalancer Service is delivered to the Pod by the iptables/IPVS Rules configured by kube-proxy.

In the case of the Instance Type, the Target Node to which the CLB or NLB sends Packets differs depending on the ExternalTrafficPolicy setting of the LoadBalancer Service. When set to **Cluster**, the CLB or NLB performs Health Checks on the Worker Nodes using the NodePort of the LoadBalancer Service against all Nodes. It then distributes and transmits Packets to all Nodes in a healthy state. When set to **Local**, it checks whether a Target Pod is running on each Node through the **HealthCheckNodePort** of the LoadBalancer Service against all Nodes. It then distributes and transmits Packets only to the Nodes where Target Pods are running.

The IP Type can only be used with NLB. In the case of the IP Type, the NLB sets the Dst IP/Port of the Packets it sends to the Target Pod and transmits them. Afterwards, when the Node receives a Packet whose Dst IP/Port is the IP/Port of the Target Pod, the Node transmits the Packet directly to the Pod according to the Routing Table configured by the AWS VPC CNI.

```shell {caption="[Shell 2] CLB, Instance Target Example"}
$ kubectl get service
NAME       TYPE           CLUSTER-IP     EXTERNAL-IP                                                                    PORT(S)        AGE
my-nginx   LoadBalancer   10.100.51.23   ad39ba2b8a05d44d2b88e3e11c9706b7-1845382141.ap-northeast-2.elb.amazonaws.com   80:30686/TCP   11m
```

```shell {caption="[Shell 3] NLB, Instance Target Example"}
$ kubectl get service
NAME       TYPE           CLUSTER-IP     EXTERNAL-IP                                                                    PORT(S)        AGE
my-nginx   LoadBalancer   10.100.51.23   ad39ba2b8a05d44d2b88e3e11c9706b7-033c32321465326e.elb.ap-northeast-2.amazonaws.com   80:30686/TCP   22m
```

```shell {caption="[Shell 4] NLB, IP Target Example"}
$ kubectl get service
NAME            TYPE           CLUSTER-IP     EXTERNAL-IP                                                                         PORT(S)          AGE
my-nginx-ipv4   LoadBalancer   10.100.51.23   k8s-default-mynginxi-f9350243cc-a75a0e7eb684cc04.elb.ap-northeast-2.amazonaws.com   8080:30686/TCP   22m
```

[Shell 2] shows the LoadBalancer Service when using CLB with an Instance Target, [Shell 3] when using NLB with an Instance Target, and [Shell 4] when using NLB with an IP Target. Which LB to use and which Target Type to use can be configured through the following Annotation settings on the LoadBalancer Service.

* **CLB + Instance Type** : `service.beta.kubernetes.io/aws-load-balancer-type: clb`
* **NLB + Instance Type** : `service.beta.kubernetes.io/aws-load-balancer-type: nlb`
* **NLB + IP Type** : `service.beta.kubernetes.io/aws-load-balancer-type: nlb-ip`

#### 2.2. ALB (Application Load Balancer)

{{< figure caption="[Figure 5] AWS EKS ALB" src="images/aws-eks-alb.png" width="900px" >}}

In an EKS Cluster, creating an **Ingress** makes the Service accessible from outside the EKS Cluster through an ALB. Like CLB and NLB, the Target Type exists, and the Packet paths are also identical. However, when using the Instance Type, the Service connected to the Ingress must be set to NodePort or LoadBalancer Type so that a NodePort is always assigned to the Service. This is because, in the case of the Instance Type, the ALB sends Packets to the Service's NodePort. [Figure 5] shows the Packet paths according to the settings when using ALB in an EKS Cluster.

```shell {caption="[Shell 5] Ingress without Group"}
$ kubectl get ingress
NAME       CLASS    HOSTS   ADDRESS                                                                      PORTS   AGE
my-nginx   <none>   *       k8s-default-mynginx-290ac4e9b9-1853125440.ap-northeast-2.elb.amazonaws.com   80      3m37s
```

[Shell 5] shows the state of an Ingress using an ALB. To configure an Ingress to use an ALB, the following Annotations must be set on the Ingress.

* **ALB Class setting** (required) : `kubernetes.io/ingress.class: alb`
* **ALB Public Network connection** : `alb.ingress.kubernetes.io/scheme: internet-facing`
* **ALB Instance Target Type** : `alb.ingress.kubernetes.io/target-type: instance`
* **ALB IP Target Type** : `alb.ingress.kubernetes.io/target-type: ip`

```shell {caption="[Shell 6] Ingress with Group"}
$ kubectl get ingress
NAME       CLASS    HOSTS   ADDRESS                                                             PORTS   AGE
my-nginx   <none>   *       k8s-mygroup-9758714285-724452701.ap-northeast-2.elb.amazonaws.com   80      12m
```

ALB provides a Group feature that allows multiple Ingresses to use a single VIP. [Shell 6] shows the state of an Ingress using the Group feature. To use the Group feature, the Annotation below must be set.

* **ALB Group name** : `alb.ingress.kubernetes.io/group.name: <group-name>`

## 2. References

* Amazon EKS란 무엇입니까? : [https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/what-is-eks.html](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/what-is-eks.html)
* De-mystifying cluster networking for Amazon EKS worker nodes : [https://aws.amazon.com/blogs/containers/de-mystifying-cluster-networking-for-amazon-eks-worker-nodes/](https://aws.amazon.com/blogs/containers/de-mystifying-cluster-networking-for-amazon-eks-worker-nodes/)
* Amazon EKS 클러스터에 대한 네트워킹 구성 : [https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/eks-networking.html](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/eks-networking.html)
* Assign IPs to Pods with the Amazon VPC CNI : [https://docs.aws.amazon.com/eks/latest/userguide/pod-networking.html](https://docs.aws.amazon.com/eks/latest/userguide/pod-networking.html)
* Route TCP and UDP traffic with Network Load Balancers : [https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html](https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html)
* aws/amazon-vpc-cni-k8s : [https://github.com/aws/amazon-vpc-cni-k8s](https://github.com/aws/amazon-vpc-cni-k8s)
