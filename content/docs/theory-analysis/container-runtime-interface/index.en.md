---
title: Container Runtime Interface (CRI)
---

Analyze Container Runtime Interface (CRI).

# 1. Container Runtime Interface (CRI)

{{< figure caption="[Figure 1] CRI" src="images/cri.png" width="400px" >}}

Container Runtime Interface (CRI) means the defined Interface between kubelet and Container Runtime among Kubernetes Components. kubelet operates on all Nodes of Kubernetes Cluster and performs the role of managing Node's Containers using Container Runtime. [Figure 1] shows CRI. CRI communicates using gRPC. Container Runtimes that support CRI receive commands directly from kubelet and control Containers. Container Runtimes that do not support CRI can connect to kubelet through a Layer called CRI Shim.

Docker Container Runtime does not support CRI. Therefore, kubelet controls Docker Container through **dockershim**, a CRI shim developed by Kubernetes. containerd Container Runtime supports CRI internally through **CRI Plugin**. **crictl** command is a command used when controlling containerd through CRI.

## 1.1. Interface

```text {caption="[File 1] CRI protobuf", linenos=table}
service RuntimeService {
    rpc RunPodSandbox(RunPodSandboxRequest) returns (RunPodSandboxResponse) {}
    rpc StopPodSandbox(StopPodSandboxRequest) returns (StopPodSandboxResponse) {}
    rpc RemovePodSandbox(RemovePodSandboxRequest) returns (RemovePodSandboxResponse) {}
    rpc PodSandboxStatus(PodSandboxStatusRequest) returns (PodSandboxStatusResponse) {}
    rpc ListPodSandbox(ListPodSandboxRequest) returns (ListPodSandboxResponse) {}

    rpc CreateContainer(CreateContainerRequest) returns (CreateContainerResponse) {}
    rpc StartContainer(StartContainerRequest) returns (StartContainerResponse) {}
    rpc StopContainer(StopContainerRequest) returns (StopContainerResponse) {}
    rpc RemoveContainer(RemoveContainerRequest) returns (RemoveContainerResponse) {}
    rpc ListContainers(ListContainersRequest) returns (ListContainersResponse) {}
    rpc ContainerStatus(ContainerStatusRequest) returns (ContainerStatusResponse) {}
    rpc UpdateContainerResources(UpdateContainerResourcesRequest) returns (UpdateContainerResourcesResponse) {}
    rpc ReopenContainerLog(ReopenContainerLogRequest) returns (ReopenContainerLogResponse) {}

    rpc ExecSync(ExecSyncRequest) returns (ExecSyncResponse) {}
    rpc Exec(ExecRequest) returns (ExecResponse) {}
    rpc Attach(AttachRequest) returns (AttachResponse) {}
    rpc PortForward(PortForwardRequest) returns (PortForwardResponse) {}
}

service ImageService {
    rpc ListImages(ListImagesRequest) returns (ListImagesResponse) {}
    rpc ImageStatus(ImageStatusRequest) returns (ImageStatusResponse) {}
    rpc PullImage(PullImageRequest) returns (PullImageResponse) {}
    rpc RemoveImage(RemoveImageRequest) returns (RemoveImageResponse) {}
    rpc ImageFsInfo(ImageFsInfoRequest) returns (ImageFsInfoResponse) {}
}
```

[File 1] shows a part of CRI's protobuf file. Through protobuf file, you can identify what Interface CRI defines. In Runtime Service, you can see functions that manage Containers and Pods, which are collections of Containers. In Image Service, you can see functions that manage Container Images.

## 2. References

* [https://kubernetes.io/blog/2016/12/container-runtime-interface-cri-in-kubernetes/](https://kubernetes.io/blog/2016/12/container-runtime-interface-cri-in-kubernetes/)
* [https://github.com/kubernetes/cri-api/blob/master/pkg/apis/runtime/v1alpha2/api.proto](https://github.com/kubernetes/cri-api/blob/master/pkg/apis/runtime/v1alpha2/api.proto)

