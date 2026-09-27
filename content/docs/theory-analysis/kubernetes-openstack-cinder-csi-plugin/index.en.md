---
title: Kubernetes with OpenStack Cinder CSI Plugin
---

This post analyzes the OpenStack Cinder CSI (Container Storage Interface) Plugin working with Kubernetes.

## 1. Kubernetes OpenStack Cinder CSI(Container Storage Interface) Plugin

{{< figure caption="[Figure 1] Kubernetes OpenStack Cinder CSI Plugin" src="images/openstack-cinder-csi-plugin.png" width="1000px" >}}

[Figure 1] shows the OpenStack Cinder CSI Plugin working with Kubernetes. **The Cinder CSI Plugin can perform both the Controller Plugin role and the Node Plugin role of the CSI Spec.** Therefore, the Cinder CSI Plugin supports the three Interfaces of the CSI Spec: Identity Service, Controller Service, and Node Service. Among the Cinder CSI Plugins, the one operating as the Controller Plugin runs in the Controller Plugin Pod, and the one operating as the Node Plugin runs in the Node Plugin Pod. The Controller Plugin Pod runs on a Master Node or a Worker Node, and the Node Plugin Pod belongs to a K8s Daemonset and runs on every Worker Node.

The Apps running in the Controller Plugin Pod are cinder-csi-plugin, csi-provisioner, csi-attacher, csi-snapshotter, and csi-resizer, each running in its own Container. When multiple Controller Plugin Pods run for HA (High Availability), the Apps other than the cinder-csi-plugin App operate in an Active-Standby form. The role of each App is as follows.

* **cinder-csi-plugin** : Represents the Cinder CSI Plugin performing the **Controller Plugin** role. cinder-csi-plugin creates the `csi.sock` file and plays the role of controlling Cinder according to the requests of the other Apps in the Controller Plugin Pod delivered through the created `csi.sock` file. Requests are made through the Identity Service and Controller Service Interfaces of CSI.
* **csi-provisioner** : Watches changes of PersistentVolumeClaim Objects from the Kubernetes API Server and sends CSI CreateVolume/DeleteVolume requests to the CSI Plugin.
* **csi-attacher** : Watches changes of VolumeAttachment Objects from the Kubernetes API Server and sends CSI ControllerPublish/ControllerUnpublish requests to the CSI Plugin.
* **csi-snapshotter** : Watches changes of Snapshot CRDs (Custom Resource Definitions) from the Kubernetes API Server and sends CSI CreateSnapshot/DeleteSnapshot requests to the CSI Plugin.
* **csi-resizer** : Watches changes of PersistentVolumeClaim Objects from the Kubernetes API Server and sends CSI ControllerExpandVolume requests to the CSI Plugin.

The Apps running in the Node Plugin Pod are cinder-csi-plugin and node-driver-registrar, each running in its own Container. The role of each App is as follows.

* **cinder-csi-plugin** : Represents the Cinder CSI Plugin performing the **Node Plugin** role. cinder-csi-plugin creates the `csi.sock` file and plays the role of controlling Cinder according to the requests of kubelet delivered through the created `csi.sock` file. Requests are made through the Identity Service and Node Service Interfaces of CSI. kubelet sends four requests to cinder-csi-plugin: CSI NodeStageVolume/NodeUnstageVolume and CSI NodePublishVolume/NodeUnpublishVolume.
* **node-driver-registrar** : Registers cinder-csi-plugin to kubelet using **kubelet's Plugin Registration**. The registration information also includes the path of cinder-csi-plugin's `csi.sock` file. kubelet sends CSI requests to cinder-csi-plugin based on the path information of the `csi.sock` file. The `regi.sock` file is created by node-driver-registrar and is used only when registering cinder-csi-plugin to kubelet.

cinder-csi-plugin belongs to the OpenStack Provider Project, and the remaining Apps belong to the Kubernetes CSI Project. When using a different CSI Plugin, only cinder-csi-plugin needs to be replaced with the desired CSI Plugin.

{{< figure caption="[Figure 2] Kubernetes OpenStack Cinder CSI Volume Lifecycle" src="images/openstack-cinder-csi-volume-lifecycle.png" width="500px" >}}

[Figure 2] shows the Lifecycle of a Cinder Volume supported by the Cinder CSI Plugin. It uses a Volume Lifecycle with four stages: Created, Node Ready, Volume Ready, and Published. It can be seen that Cinder Volume Create/Delete, Cinder Volume Attach/Detach, Cinder Volume Format, Mount/Unmount, and Create/Delete Bind Mount are performed at each stage. Bind Mount refers to the process of connecting the mounted Cinder Volume to the Pod's Volume.

## 2. References

* Container Storage Interface (CSI) Spec : [https://github.com/container-storage-interface/spec/blob/master/spec.md](https://github.com/container-storage-interface/spec/blob/master/spec.md)
* Kubernetes CSI Developer Documentation : [https://kubernetes-csi.github.io/docs/](https://kubernetes-csi.github.io/docs/)
* Understanding the Container Storage Interface (CSI) : [https://medium.com/google-cloud/understanding-the-container-storage-interface-csi-ddbeb966a3b](https://medium.com/google-cloud/understanding-the-container-storage-interface-csi-ddbeb966a3b)
* Using CSI drivers (Docker UCP) : [https://docs.docker.com/ee/ucp/kubernetes/storage/use-csi/](https://docs.docker.com/ee/ucp/kubernetes/storage/use-csi/)
* CSI Spec : [https://github.com/container-storage-interface/spec/blob/master/spec.md](https://github.com/container-storage-interface/spec/blob/master/spec.md)
* csi-attacher : [https://github.com/kubernetes-csi/external-attacher](https://github.com/kubernetes-csi/external-attacher)
* csi-provisioner : [https://github.com/kubernetes-csi/external-provisioner](https://github.com/kubernetes-csi/external-provisioner)
* csi-snapshotter : [https://github.com/kubernetes-csi/external-snapshotter](https://github.com/kubernetes-csi/external-snapshotter)
* csi-resizer : [https://github.com/kubernetes-csi/external-resizer](https://github.com/kubernetes-csi/external-resizer)
* node-driver-registrar : [https://github.com/kubernetes-csi/node-driver-registrar](https://github.com/kubernetes-csi/node-driver-registrar)
* Device plugin registration : [https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/#device-plugin-registration](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/#device-plugin-registration)
