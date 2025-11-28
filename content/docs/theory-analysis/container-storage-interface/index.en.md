---
title: Container Storage Interface (CSI)
---

Analyze Container Storage Interface (CSI) used when setting up Container Storage.

## 1. Container Storage Interface (CSI)

{{< figure caption="[Figure 1] CSI" src="images/csi.png" width="400px" >}}

Container Storage Interface (CSI) means the Interface between Container Orchestration System (CO) such as Kubernetes and Mesos and Plugin (Storage Controller) that controls Storage. [Figure 1] shows CSI. CSI defines the following three things.

* Plugin that controls Storage
* Life Cycle of Storage (Volume)
* Interface between CO and Plugin

### 1.1. Plugin

Plugin means Storage Controller that controls Storage according to CO's commands. Plugins are divided into **Controller Plugin** and **Node Plugin**. Controller Plugin means a Plugin that can operate on any Node. Controller Plugin performs Storage central management functions. Node Plugin means a Plugin that operates on all Nodes where Containers operate. Node Plugin performs the role of controlling specific Nodes.

CSI has left the composition and deployment of Controller Plugin and Node Plugin relatively open. CSI distinguishes Controller Plugin and Node Plugin, but defines that they can be composed as one Program. It even defines that Controller Plugin can be absent and only Node Plugin can be composed. CSI does not define Plugin's Life Cycle.

### 1.2. Volume(Storage) Lifecycle

{{< figure caption="[Figure 2] CSI Volume Lifecycle" src="images/csi-volume-lifecycle.png" width="450px" >}}

CSI defines Storage's Lifecycle. CSI uses the term Volume Lifecycle instead of Storage Lifecycle. CSI does not define only one Volume Lifecycle but defines multiple Life Cycles to satisfy various Storage characteristics and configuration environments. [Figure 2] shows the longest Lifecycle among Volume Lifecycles defined in CSI. CO determines Volume Lifecycle through Capability information (ControllerGetCapabilities) obtained from Controller Plugin and Capability information (NodeGetCapabilities) obtained from Node Plugin.

### 1.3. Interface

CSI defines Interface between CO and Plugin based on defined Plugin and Volume Lifecycle. Interface is composed based on gRPC. Interface is divided into **Identity Service**, **Controller Service**, and **Node Service**. Identity Service is an Interface commonly used by Controller Plugin and Node Plugin. Controller Service is an Interface used by Controller Plugin, and Node Service is an Interface used by Node Plugin. The Interface list is as follows.

* Identity Service
  * GetPluginInfo
  * GetPluginCapabilities
  * Probe

* Controller Service
  * CreateVolume
  * DeleteVolume
  * ControllerPublishVolume
  * ControllerUnpublishVolume
  * ValidateVolumeCapabilities
  * ListVolumes 
  * GetCapacity 
  * ControllerGetCapabilities 
  * CreateSnapshot 
  * DeleteSnapshot 
  * ListSnapshots 
  * ControllerExpandVolume 

* Node Service
  * NodeStageVolume
  * NodeUnstageVolume
  * NodePublishVolume 
  * NodeUnpublishVolume 
  * NodeGetVolumeStats 
  * NodeExpandVolume
  * NodeGetCapabilities 
  * NodeGetInfo

Each Interface is composed in the form of defining Request/Response. CSI also defines Error Code and Secret rules. Interface can be classified into Interface that controls Storage and Interface that obtains Plugin information. Looking only at Interface that controls Storage, Controller Service defines Interface for CreateVolume/DeleteVolume, ControllerPublishVolume/ControllerUnpublishVolume corresponding to the front and back parts of Volume LifeCycle, and requests related to Storage and Snapshot. Node Service defines Interface for requests related to NodeStageVolume/NodeUnstageVolume, NodePublishVolume/NodeUnpublishVolume corresponding to the middle part of Volume LifeCycle.
 
As CSI's Plugin and Volume Lifecycle exist in various forms, CO must obtain Plugin information and Volume Lifecycle information from Plugin. CO identifies Interface list and Volume Lifecycle provided by Plugin through Interface that obtains Plugin information, and controls Storage based on the identified information. GetPluginCapabilities tells whether that Plugin provides Controller Service Interface. ControllerGetCapabilities tells the Controller Service Interface list provided by that Plugin. NodeGetCapabilities tells the Node Service Interface list provided by that Plugin. CO identifies and controls Volume's Lifecycle through information obtained through ControllerGetCapabilities and NodeGetCapabilities.

## 2. References

* [https://github.com/container-storage-interface/spec/blob/master/spec.md](https://github.com/container-storage-interface/spec/blob/master/spec.md)
* [https://kubernetes-csi.github.io/docs/](https://kubernetes-csi.github.io/docs/)
* [https://medium.com/google-cloud/understanding-the-container-storage-interface-csi-ddbeb966a3b](https://medium.com/google-cloud/understanding-the-container-storage-interface-csi-ddbeb966a3b)

