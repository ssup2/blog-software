---
title: AWS EKS Storage
---

## 1. AWS EKS Storage

AWS EKS provides various Storage Classes based on EBS (Elastic Block Storage), EFS (Elastic File Storage), and FSx.

### 1.1. Default Storage Class

```shell {caption="[Shell 1] AWS EKS Storage Class"}
# kubectl get sc
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  3d1h
```

When configuring a Kubernetes Cluster with EKS, EBS's gp2 is set as the Default Storage Class. [Shell 1] shows the Storage Class with gp2 configured.

```shell {caption="[Shell 2] AWS EKS kubelet"}
# ps -ef | grep kubelet
root      3801     1  1 Apr06 ?        06:09:14 /usr/bin/kubelet --node-ip=192.168.75.136 --node-labels=alpha.eksctl.io/cluster-name=ssup2-eks-cluster,alpha.eksctl.io/nodegroup-name=nodegroup-1,node-lifecycle=on-demand,alpha.eksctl.io/instance-id=i-0b923780d29147e03 --max-pods=17 --register-node=true --register-with-taints= --cloud-provider=aws --container-runtime=docker --network-plugin=cni --cni-bin-dir=/opt/cni/bin --cni-conf-dir=/etc/cni/net.d --pod-infra-container-image=602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/eks/pause:3.3-eksbuild.1 --kubeconfig=/etc/eksctl/kubeconfig.yaml --config=/etc/eksctl/kubelet.yaml
```

When accessing an EKS Node via SSH and checking kubelet's parameters, you can see that the cloud-provider option is configured. [Shell 2] shows kubelet's parameters. You can see that the Cloud Provider is set to "aws".

```shell {caption="[Shell 3] AWS EKS kubelet Volume Mount Log"}
Apr 09 15:55:32 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:32.183634    3801 topology_manager.go:233] [topologymanager] Topology Admit Handler
Apr 09 15:55:32 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:32.336844    3801 reconciler.go:224] operationExecutor.VerifyControllerAttachedVolume started for volume "pvc-1b5dd043-40fc-4924-b1af-03bfa9630751" (UniqueName: "kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89") pod "web-1" (UID: "6681c826-f599-4549-b2e1-707c69c26837")
Apr 09 15:55:32 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:32.336896    3801 reconciler.go:224] operationExecutor.VerifyControllerAttachedVolume started for volume "default-token-7m864" (UniqueName: "kubernetes.io/secret/6681c826-f599-4549-b2e1-707c69c26837-default-token-7m864") pod "web-1" (UID: "6681c826-f599-4549-b2e1-707c69c26837")
Apr 09 15:55:32 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: E0409 15:55:32.337007    3801 nestedpendingoperations.go:301] Operation for "{volumeName:kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89 podName: nodeName:}" failed. No retries permitted until 2021-04-09 15:55:32.836974851 +0000 UTC m=+263922.787528156 (durationBeforeRetry 500ms). Error: "Volume has not been added to the list of VolumesInUse in the node's volume status for volume \"pvc-1b5dd043-40fc-4924-b1af-03bfa9630751\" (UniqueName: \"kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89\") pod \"web-1\" (UID: \"6681c826-f599-4549-b2e1-707c69c26837\") "
Apr 09 15:55:32 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:32.841678    3801 reconciler.go:224] operationExecutor.VerifyControllerAttachedVolume started for volume "pvc-1b5dd043-40fc-4924-b1af-03bfa9630751" (UniqueName: "kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89") pod "web-1" (UID: "6681c826-f599-4549-b2e1-707c69c26837")
Apr 09 15:55:32 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: E0409 15:55:32.841780    3801 nestedpendingoperations.go:301] Operation for "{volumeName:kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89 podName: nodeName:}" failed. No retries permitted until 2021-04-09 15:55:33.841752915 +0000 UTC m=+263923.792306216 (durationBeforeRetry 1s). Error: "Volume has not been added to the list of VolumesInUse in the node's volume status for volume \"pvc-1b5dd043-40fc-4924-b1af-03bfa9630751\" (UniqueName: \"kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89\") pod \"web-1\" (UID: \"6681c826-f599-4549-b2e1-707c69c26837\") "
Apr 09 15:55:33 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:33.844677    3801 reconciler.go:224] operationExecutor.VerifyControllerAttachedVolume started for volume "pvc-1b5dd043-40fc-4924-b1af-03bfa9630751" (UniqueName: "kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89") pod "web-1" (UID: "6681c826-f599-4549-b2e1-707c69c26837")
Apr 09 15:55:33 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: E0409 15:55:33.850478    3801 nestedpendingoperations.go:301] Operation for "{volumeName:kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89 podName: nodeName:}" failed. No retries permitted until 2021-04-09 15:55:35.850450415 +0000 UTC m=+263925.801003754 (durationBeforeRetry 2s). Error: "Volume not attached according to node status for volume \"pvc-1b5dd043-40fc-4924-b1af-03bfa9630751\" (UniqueName: \"kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89\") pod \"web-1\" (UID: \"6681c826-f599-4549-b2e1-707c69c26837\") "
Apr 09 15:55:34 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: {"level":"info","ts":"2021-04-09T15:55:34.244Z","caller":"/usr/local/go/src/runtime/proc.go:203","msg":"CNI Plugin version: v1.7.5 ..."}
Apr 09 15:55:35 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:35.949997    3801 reconciler.go:224] operationExecutor.VerifyControllerAttachedVolume started for volume "pvc-1b5dd043-40fc-4924-b1af-03bfa9630751" (UniqueName: "kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89") pod "web-1" (UID: "6681c826-f599-4549-b2e1-707c69c26837")
Apr 09 15:55:35 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:35.955735    3801 operation_generator.go:1332] Controller attach succeeded for volume "pvc-1b5dd043-40fc-4924-b1af-03bfa9630751" (UniqueName: "kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89") pod "web-1" (UID: "6681c826-f599-4549-b2e1-707c69c26837") device path: "/dev/xvdbw"
Apr 09 15:55:36 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:36.050389    3801 operation_generator.go:558] MountVolume.WaitForAttach entering for volume "pvc-1b5dd043-40fc-4924-b1af-03bfa9630751" (UniqueName: "kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89") pod "web-1" (UID: "6681c826-f599-4549-b2e1-707c69c26837") DevicePath "/dev/xvdbw"
Apr 09 15:55:37 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:37.050635    3801 attacher.go:189] Successfully found attached AWS Volume "aws://ap-northeast-2a/vol-0c6206285b4820d89" at path "/dev/xvdbw".
Apr 09 15:55:37 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:37.050689    3801 operation_generator.go:567] MountVolume.WaitForAttach succeeded for volume "pvc-1b5dd043-40fc-4924-b1af-03bfa9630751" (UniqueName: "kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89") pod "web-1" (UID: "6681c826-f599-4549-b2e1-707c69c26837") DevicePath "/dev/xvdbw"
Apr 09 15:55:37 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:37.068352    3801 mount_linux.go:366] Disk "/dev/xvdbw" appears to be unformatted, attempting to format as type: "ext4" with options: [-F -m0 /dev/xvdbw]
Apr 09 15:55:37 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:37.286426    3801 mount_linux.go:376] Disk successfully formatted (mkfs): ext4 - /dev/xvdbw /var/lib/kubelet/plugins/kubernetes.io/aws-ebs/mounts/aws/ap-northeast-2a/vol-0c6206285b4820d89
Apr 09 15:55:37 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: I0409 15:55:37.447140    3801 operation_generator.go:596] MountVolume.MountDevice succeeded for volume "pvc-1b5dd043-40fc-4924-b1af-03bfa9630751" (UniqueName: "kubernetes.io/aws-ebs/aws://ap-northeast-2a/vol-0c6206285b4820d89") pod "web-1" (UID: "6681c826-f599-4549-b2e1-707c69c26837") device mount path "/var/lib/kubelet/plugins/kubernetes.io/aws-ebs/mounts/aws/ap-northeast-2a/vol-0c6206285b4820d89"
Apr 09 15:55:38 ip-192-168-75-136.ap-northeast-2.compute.internal kubelet[3801]: W0409 15:55:38.128905    3801 pod_container_deletor.go:77] Container "d9165d9862d7d713871f40be45cf4f11224597a85edf68e893a6b3df36e313f9" not found in pod's containers
```

When using the Default Storage Class, kubelet performs Volume Format and Mount. [Shell 3] shows kubelet logs of the process of detecting an EBS gp2 Volume attached to the VM, formatting it as ext4, and mounting it.

```shell {caption="[Shell 4] EBS Mount"}
# ls -l /dev/ | grep xvda
lrwxrwxrwx 1 root root           7 Apr  6 14:36 xvda -> nvme0n1
lrwxrwxrwx 1 root root           9 Apr  6 14:36 xvda1 -> nvme0n1p1
lrwxrwxrwx 1 root root          11 Apr  6 14:36 xvda128 -> nvme0n1p128
lrwxrwxrwx 1 root root           7 Apr  9 15:55 xvdbw -> nvme1n1
```

[Shell 4] shows how an EBS Volume attached to a Node appears inside the Node. xvd[*] represents EBS Block Storage.

### 1.2. CSI (Container Storage Interface) Storage Class

Recently, Kubernetes recommends using CSI Controller, which performs the role of a separate Volume Controller, rather than the Volume Controller that exists inside kube-controller-manager and kubelet for Volume control. Since CSI Controller is independent of Kubernetes Components (kube-controller-manager, kubelet), using CSI Controller has the advantage of being able to use the same Volume Controller even after performing Kubernetes Component upgrades.

Accordingly, AWS EKS also provides CSI Controller. It provides EBS CSI Storage Class, and CSI Controller must be used to use EFS and FSx. From a Kubernetes perspective, the characteristics of EBS, EFS, and FSx Storage are as follows.

* EBS : EBS operates in **ReadWriteOnce** Mode. EBS is attached to the EC2 Instance where the Pod is running, and the attached EBS is formatted and mounted inside the EC2 Instance by CSI Controller. The mounted EBS is exposed to the Pod through Bind Mount.
* EFS : EFS operates in **ReadWriteMany** Mode. EFS is mounted to EC2 Instance through NFSv4 Protocol, and the mounted EFS is exposed to the Pod through Bind Mount.
* FSx : FSx operates in **ReadWriteMany** Mode. FSx is characterized by higher performance compared to EFS.

## 2. References

* [https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/what-is-eks.html](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/what-is-eks.html)
* [https://docs.aws.amazon.com/eks/latest/userguide/storage.html](https://docs.aws.amazon.com/eks/latest/userguide/storage.html)

