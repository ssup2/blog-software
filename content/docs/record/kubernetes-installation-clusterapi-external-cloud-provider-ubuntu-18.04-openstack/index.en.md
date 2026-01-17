---
title: Kubernetes Installation / Using ClusterAPI and External Cloud Provider / Ubuntu 18.04, OpenStack Environment
---

## 1. Installation Environment

{{< figure caption="[Figure 1] Kubernetes Installation Environment" src="images/environment.png" width="1000px" >}}

[Figure 1] shows the Kubernetes installation environment. The installation environment is as follows.

* Local Node: Ubuntu 18.04, KVM Enabled, 4 CPU, 4GB Memory
* Master, Worker Node: Ubuntu 18.04, 4 vCPU, 4GB Memory
* Network
  * External Network: 192.168.0.0/24
  * Octavia Network: 20.0.0.0/24
  * Tenant Network: 10.6.0.0/24
* Kubernetes: 1.17.11
  * CNI: Cilium 1.7.11 Plugin
* External Cloud Provider
  * OpenStack Cloud Controller Manager: v1.17.0

## 2. OpenStack OpenRC Configuration

Create an OpenRC file according to the OpenStack configuration.

```text {caption="[Text 1] admin-openrc.sh", linenos=table}
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=admin
export OS_AUTH_URL=http://192.168.0.40:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
```

Create an admin-openrc.sh file with the content from [Text 1].

## 3. Local Kubernetes Cluster Installation

```shell
(Local)$ GO111MODULE="on" go get sigs.k8s.io/kind@v0.9.0 && kind create cluster
(Local)$ kubectl cluster-info
Kubernetes master is running at https://127.0.0.1:34839
KubeDNS is running at https://127.0.0.1:34839/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

Install and verify the Local Kubernetes Cluster for running Cluster API.

## 4. clusterctl Installation

```shell
(Local)$ snap install yq
```

Install yq used by clusterctl.

```shell
(Local)$ curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.3.11/clusterctl-linux-amd64 -o clusterctl
(Local)$ chmod +x ./clusterctl
(Local)$ sudo mv ./clusterctl /usr/local/bin/clusterctl
(Local)$ clusterctl version                                                                                                   [15:57:48]
clusterctl version: &version.Info{Major:"0", Minor:"3", GitVersion:"v0.3.11", GitCommit:"e9cf6846b6d93dedadfcf44c00357d15f5ccba64", GitTreeState:"clean", BuildDate:"2020-11-19T18:49:17Z", GoVersion:"go1.13.15", Compiler:"gc", Platform:"linux/amd64"}
```

Install clusterctl to help install and use Cluster API in the Local Kubernetes Cluster.

## 5. Cluster API Installation

```shell
(Local)$ clusterctl init --infrastructure openstack
(Local)$ kubectl get pod --all-namespaces
capi-kubeadm-bootstrap-system       capi-kubeadm-bootstrap-controller-manager-6b6579d56d-q7cfm       2/2     Running   0          2m44s
capi-kubeadm-control-plane-system   capi-kubeadm-control-plane-controller-manager-6d878bb599-4wh7h   2/2     Running   0          2m43s
capi-system                         capi-controller-manager-7ff4999d6c-252dk                         2/2     Running   0          2m45s
capi-webhook-system                 capi-controller-manager-6c48f8f9bb-qknwx                         2/2     Running   0          2m45s
capi-webhook-system                 capi-kubeadm-bootstrap-controller-manager-56f98bc7f9-whkgb       2/2     Running   0          2m44s
capi-webhook-system                 capi-kubeadm-control-plane-controller-manager-85bcfd7fcd-hxs4v   2/2     Running   0          2m43s
capi-webhook-system                 capo-controller-manager-cc997bf9-vpqxd                           2/2     Running   0          2m43s
capo-system                         capo-controller-manager-64f4d7f476-95fln                         2/2     Running   0          2m42s
cert-manager                        cert-manager-cainjector-fc6c787db-jknzr                          1/1     Running   0          3m17s
cert-manager                        cert-manager-d994d94d7-rrbjg                                     1/1     Running   0          3m17s
cert-manager                        cert-manager-webhook-845d9df8bf-9m4l8                            1/1     Running   0          3m17s
...
```

Install Cluster API in the Local Kubernetes Cluster using clusterctl.

```shell
(Local)$ kubectl -n capo-system set env deployment/capo-controller-manager CLUSTER_API_OPENSTACK_INSTANCE_CREATE_TIMEOUT=60
```

Configure the OpenStack Controller Manager to wait up to 60 minutes when creating instances.

## 6. VM Image Build and Import

Build the VM image for Kubernetes Cluster nodes to be created via Cluster API.

```shell
(Local)$ apt install qemu-kvm libvirt-bin qemu-utils
```

Install Ubuntu packages required for VM image building.

```shell
(Local)$ apt install python3-pip
(Local)$ pip3 install ansible --user
(Local)$ export PATH=$PATH:$HOME/.local/bin
```

Install Ansible.

```shell
(Local)$ export VER="1.6.5"
(Local)$ wget "https://releases.hashicorp.com/packer/${VER}/packer_${VER}_linux_amd64.zip"
(Local)$ unzip packer_1.6.5_linux_amd64.zip 
(Local)$ sudo mv packer /usr/local/bin 
```

Install packer.

```shell
(Local)$ curl -L https://github.com/kubernetes-sigs/image-builder/tarball/master -o image-builder.tgz
(Local)$ tar xzf image-builder.tgz
(Local)$ cd kubernetes-sigs-image-builder-3c3a17/images/capi
(Local)$ make build-qemu-ubuntu-1804
```

Build the VM image and reduce its size. The environment must support **KVM** to build the image. The built image has QCOW2 format.

```shell
(Local)$ . admin-openrc.sh
(Local)$ openstack image create --disk-format qcow2 --container-format bare --public --file ./output/ubuntu-1804-kube-v1.17.11/ubuntu-1804-kube-v1.17.11 ubuntu-18.04-capi
```

Import the built image into OpenStack.

## 7. OpenStack Configuration

Configure OpenStack for Cluster API.

```shell
(Local)$ . admin-openrc.sh
(Local)$ openstack keypair create --private-key ssup2_pri.key ssup2
```

Create a keypair to configure on Kubernetes Cluster nodes to be created via Cluster API.

```shell
(Local)$ . admin-openrc.sh
(Local)$ openstack application credential create cloud-controller-manager
+--------------+----------------------------------------------------------------------------------------+
| Field        | Value                                                                                  |
+--------------+----------------------------------------------------------------------------------------+
| description  | None                                                                                   |
| expires_at   | None                                                                                   |
| id           | 96e2f01837884a59b5d70fa8a6960c9a                                                       |
| name         | cloud-controller-manager                                                               |
| project_id   | b21b68637237488bbb5f33ac8d86b848                                                       |
| roles        | admin member reader                                                                    |
| secret       | nKhWeYW0zEbkIqO4V8ubVXoHQDsfc8U8Z-eJ-up2JtvyxHWujeCB47XKJcvmaLcQjX0Qxg7CffgqwM0pdyeaww |
| system       | None                                                                                   |
| unrestricted | False                                                                                  |
| user_id      | f2bf159333f245b49240d1444f449e33                                                       |
+--------------+----------------------------------------------------------------------------------------+
```

Create an application credential for use by the OpenStack Cloud Controller Manager.

## 8. Kubernetes Cluster Creation

```yaml {caption="[Text 2] clouds.yaml", linenos=table}
clouds:
  openstack:
    insecure: true
    verify: false
    identity_api_version: 3
    auth:
      auth_url: http://192.168.0.40:5000/v3
      project_name: admin
      username: admin
      password: admin
      project_domain_name: default
      user_domain_name: default
    region: RegionOne
```

Create a clouds.yaml file with the content from [Text 2] for use by clusterctl.

```yaml {caption="[Text 3] template.yaml", linenos=table}
---
apiVersion: cluster.x-k8s.io/v1alpha3
kind: Cluster
metadata:
  name: ${CLUSTER_NAME}
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["192.167.0.0/16"]
    serviceDomain: "cluster.local"
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
    kind: OpenStackCluster
    name: ${CLUSTER_NAME}
  controlPlaneRef:
    kind: KubeadmControlPlane
    apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
    name: ${CLUSTER_NAME}-control-plane
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
kind: OpenStackCluster
metadata:
  name: ${CLUSTER_NAME}
spec:
  cloudName: ${OPENSTACK_CLOUD}
  cloudsSecret:
    name: ${CLUSTER_NAME}-cloud-config
    namespace: ${NAMESPACE}
  managedAPIServerLoadBalancer: true
  managedSecurityGroups: true
  nodeCidr: 10.6.0.0/24
  dnsNameservers:
  - ${OPENSTACK_DNS_NAMESERVERS}
  disablePortSecurity: false
  useOctavia: true
  bastion:
    enabled: true
    flavor: m1.medium
    image: ubuntu-18.04-capi
    sshKeyName: ssup2
---
apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
kind: KubeadmControlPlane
metadata:
  name: "${CLUSTER_NAME}-control-plane"
spec:
  replicas: ${CONTROL_PLANE_MACHINE_COUNT}
  infrastructureTemplate:
    kind: OpenStackMachineTemplate
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
    name: "${CLUSTER_NAME}-control-plane"
  kubeadmConfigSpec:
    initConfiguration:
      nodeRegistration:
        name: '{{ local_hostname }}'
        kubeletExtraArgs:
          cloud-provider: external
    clusterConfiguration:
      imageRepository: k8s.gcr.io
      apiServer:
        extraArgs:
          cloud-provider: external
      controllerManager:
        extraArgs:
          cloud-provider: external
    joinConfiguration:
      nodeRegistration:
        name: '{{ local_hostname }}'
        kubeletExtraArgs:
          cloud-provider: external
  version: "${KUBERNETES_VERSION}"
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
kind: OpenStackMachineTemplate
metadata:
  name: ${CLUSTER_NAME}-control-plane
spec:
  template:
    spec:
      flavor: ${OPENSTACK_CONTROL_PLANE_MACHINE_FLAVOR}
      image: ${OPENSTACK_IMAGE_NAME}
      sshKeyName: ${OPENSTACK_SSH_KEY_NAME}
      cloudName: ${OPENSTACK_CLOUD}
      cloudsSecret:
        name: ${CLUSTER_NAME}-cloud-config
        namespace: ${NAMESPACE}
---
apiVersion: cluster.x-k8s.io/v1alpha3
kind: MachineDeployment
metadata:
  name: "${CLUSTER_NAME}-md-0"
spec:
  clusterName: "${CLUSTER_NAME}"
  replicas: ${WORKER_MACHINE_COUNT}
  selector:
    matchLabels:
  template:
    spec:
      clusterName: "${CLUSTER_NAME}"
      version: "${KUBERNETES_VERSION}"
      failureDomain: ${OPENSTACK_FAILURE_DOMAIN}
      bootstrap:
        configRef:
          name: "${CLUSTER_NAME}-md-0"
          apiVersion: bootstrap.cluster.x-k8s.io/v1alpha3
          kind: KubeadmConfigTemplate
      infrastructureRef:
        name: "${CLUSTER_NAME}-md-0"
        apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
        kind: OpenStackMachineTemplate
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
kind: OpenStackMachineTemplate
metadata:
  name: ${CLUSTER_NAME}-md-0
spec:
  template:
    spec:
      cloudName: ${OPENSTACK_CLOUD}
      cloudsSecret:
        name: ${CLUSTER_NAME}-cloud-config
        namespace: ${NAMESPACE}
      flavor: ${OPENSTACK_NODE_MACHINE_FLAVOR}
      image: ${OPENSTACK_IMAGE_NAME}
      sshKeyName: ${OPENSTACK_SSH_KEY_NAME}
---
apiVersion: bootstrap.cluster.x-k8s.io/v1alpha3
kind: KubeadmConfigTemplate
metadata:
  name: ${CLUSTER_NAME}-md-0
spec:
  template:
    spec:
      joinConfiguration:
        nodeRegistration:
          name: '{{ local_hostname }}'
          kubeletExtraArgs:
            cloud-provider: external
---
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-cloud-config
  labels:
    clusterctl.cluster.x-k8s.io/move: "true"
data:
  clouds.yaml: ${OPENSTACK_CLOUD_YAML_B64}
  cacert: ${OPENSTACK_CLOUD_CACERT_B64}
```

Create a template.yaml file with the content from [Text 3] that serves as a Cluster Manifest Template. From the https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-openstack/v0.3.3/templates/cluster-template-external-cloud-provider.yaml file, removed "disableServerTags: true", changed cidrBlocks to "192.167.0.0/16", and added Bastion VM configuration.

ClusterAPI by default configures Security Groups to prevent SSH access to nodes of the created Kubernetes Cluster. The Bastion VM serves as a gateway to enable SSH access to nodes of the Kubernetes Cluster created via ClusterAPI.

```shell
(Local)$ wget https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-openstack/master/templates/env.rc -O env.rc
```

Download the env.rc script file that sets environment variables for use by clusterctl.

```shell
(Local)$ source env.rc clouds.yaml openstack
(Local)$ export OPENSTACK_SSH_KEY_NAME=ssup2 \
export OPENSTACK_IMAGE_NAME=ubuntu-18.04-capi \
export OPENSTACK_FAILURE_DOMAIN=nova \
export OPENSTACK_DNS_NAMESERVERS=8.8.8.8 \
export OPENSTACK_CONTROL_PLANE_MACHINE_FLAVOR=m1.medium \
export OPENSTACK_NODE_MACHINE_FLAVOR=m1.medium
```

Set environment variables for use by clusterctl. Set VM Image, VM Flavor, DNS, etc. as environment variables.

```shell
(Local)$ clusterctl config cluster ssup2 --from template.yaml --kubernetes-version v1.17.11 --control-plane-machine-count=3 --worker-machine-count=1 > ssup2_cluster.yaml
(Local)$ kubectl apply -f ssup2_cluster.yaml
```

Create the Cluster Manifest file and create the Kubernetes Cluster using the created Cluster Manifest file.

## 9. Cilium CNI & OpenStack External Cloud Provider Installation

When creating a Kubernetes Cluster, only one Control Plane (Master Node) VM is created, and no more Control Planes are created. This is because the "spec.providerID" value of the Node Object of the Control Plane Node VM is not set. The "spec.providerID" value is set only after the OpenStack External Cloud Provider is installed.

```shell
(Local)$ clusterctl get kubeconfig ssup2 > /root/.kube/ssup2.kubeconfig
```

Create the kubeconfig file for the Kubernetes Cluster created using clusterctl.

```shell
(Local)$ kubectl --kubeconfig='/root/.kube/ssup2.kubeconfig' create -f https://raw.githubusercontent.com/cilium/cilium/1.7.11/install/kubernetes/quick-install.yaml
```

Install the Cilium CNI Plugin before installing the OpenStack External Cloud Provider to enable the OpenStack External Cloud Provider to be installed.

```text {caption="[Text 4] cloud.conf", linenos=table}
[Global]
auth-url="http://192.168.0.40:5000/v3"
application-credential-id="96e2f01837884a59b5d70fa8a6960c9a"
application-credential-secret="nKhWeYW0zEbkIqO4V8ubVXoHQDsfc8U8Z-eJ-up2JtvyxHWujeCB47XKJcvmaLcQjX0Qxg7CffgqwM0pdyeaww"

[BlockStorage]
bs-version=v3

[LoadBalancer]
use-octavia=True
subnet-id=67ca5cfd-0c3f-434d-a16c-c709d1ab37fb
floating-network-id=00a8e738-c81e-45f6-9788-3e58186076b6
lb-method=ROUND_ROBIN
```

Create a cloud.conf file with the content from [Text 4] for use by the OpenStack External Cloud Controller Manager.

```shell
(Local)$ kubectl --kubeconfig='/root/.kube/ssup2.kubeconfig' create secret -n kube-system generic cloud-config --from-file=cloud.conf
(Local)$ kubectl --kubeconfig='/root/.kube/ssup2.kubeconfig' apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/v1.17.0/cluster/addons/rbac/cloud-controller-manager-roles.yaml
(Local)$ kubectl --kubeconfig='/root/.kube/ssup2.kubeconfig' apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/v1.17.0/cluster/addons/rbac/cloud-controller-manager-role-bindings.yaml
(Local)$ kubectl --kubeconfig='/root/.kube/ssup2.kubeconfig' apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/v1.17.0/manifests/controller-manager/openstack-cloud-controller-manager-ds.yaml
```

Create the cloud-config Secret and deploy the OpenStack External Cloud Provider.

```shell
```

After deploying the OpenStack External Cloud Provider, you can see that the remaining Control Plane (Master Node) VMs are created.

## 10. Kubernetes Cluster Operation Verification

```shell
(Local)$ kubectl get cluster
NAME    PHASE
ssup2   Provisioned

(Local)$ kubectl get openstackclusters.infrastructure.cluster.x-k8s.io
NAME    CLUSTER   READY   NETWORK                                SUBNET                                 BASTION
ssup2   ssup2     true    678c082d-1b80-4d5b-ad74-4daced3f9379   170d5b4b-6c05-4388-84af-e952dde31e59   192.168.0.56

(Local)$ kubectl get kubeadmcontrolplane
NAME                  INITIALIZED   API SERVER AVAILABLE   VERSION    REPLICAS   READY   UPDATED   UNAVAILABLE
ssup2-control-plane   true          true                   v1.17.11   3          3       3

(Local)$ kubectl get machine
NAME                          PROVIDERID                                         PHASE     VERSION
ssup2-control-plane-88c9w     openstack://2dcc2ba4-2968-4e5a-8c85-11c61054b015   Running   v1.17.11
ssup2-control-plane-m6hkz     openstack://79608e3b-d863-46ae-84a2-7855175b4450   Running   v1.17.11
ssup2-control-plane-smlkx     openstack://f3214c23-a011-4353-bf9f-6a440097dd5e   Running   v1.17.11
ssup2-md-0-7b7b86d6f7-whvwh   openstack://2facf68d-95e5-4d1a-882f-43b3bcafc2ba   Running   v1.17.11

(Local)$ kubectl get openstackmachine
NAME                        CLUSTER   INSTANCESTATE   READY   PROVIDERID                                         MACHINE
ssup2-control-plane-b74l9   ssup2     ACTIVE          true    openstack://f3214c23-a011-4353-bf9f-6a440097dd5e   ssup2-control-plane-smlkx
ssup2-control-plane-l28lt   ssup2     ACTIVE          true    openstack://2dcc2ba4-2968-4e5a-8c85-11c61054b015   ssup2-control-plane-88c9w
ssup2-control-plane-pcrxg   ssup2     ACTIVE          true    openstack://79608e3b-d863-46ae-84a2-7855175b4450   ssup2-control-plane-m6hkz
ssup2-md-0-t5jtt            ssup2     ACTIVE          true    openstack://2facf68d-95e5-4d1a-882f-43b3bcafc2ba   ssup2-md-0-7b7b86d6f7-whvwh

(Local)$ kubectl get secrets | grep ssup2
ssup2-ca                    Opaque                                2      28d
ssup2-cloud-config          Opaque                                2      28d
ssup2-control-plane-5wcw6   cluster.x-k8s.io/secret               1      28d
ssup2-control-plane-jlm5n   cluster.x-k8s.io/secret               1      28d
ssup2-control-plane-pwpzr   cluster.x-k8s.io/secret               1      28d
ssup2-etcd                  Opaque                                2      28d
ssup2-kubeconfig            Opaque                                1      28d
ssup2-md-0-sjlj9            cluster.x-k8s.io/secret               1      28d
ssup2-proxy                 Opaque                                2      28d
ssup2-sa                    Opaque                                2      28d

(Local)$ kubectl --kubeconfig='/root/.kube/ssup2.kubeconfig' get nodes
NAME                        STATUS   ROLES    AGE     VERSION
ssup2-control-plane-b74l9   Ready    master   94m     v1.17.11
ssup2-control-plane-l28lt   Ready    master   8m28s   v1.17.11
ssup2-control-plane-pcrxg   Ready    master   70m     v1.17.11
ssup2-md-0-t5jtt            Ready    <none>   89m     v1.17.11
```

Verify Kubernetes Cluster operation.

## 11. SSH Access to Kubernetes Cluster VM Nodes

SSH into the Bastion VM using the ssup2 keypair, then use the ssup2 keypair again from inside the Bastion VM to access the Kubernetes Cluster VM nodes.

## 12. References

* [https://kind.sigs.k8s.io/](https://kind.sigs.k8s.io/)
* [https://cluster-api.sigs.k8s.io/](https://cluster-api.sigs.k8s.io/)
* [https://cluster-api.sigs.k8s.io/user/quick-start.html](https://cluster-api.sigs.k8s.io/user/quick-start.html)
* [https://image-builder.sigs.k8s.io/capi/providers/openstack.html](https://image-builder.sigs.k8s.io/capi/providers/openstack.html)
* [https://github.com/kubernetes-sigs/cluster-api-provider-openstack](https://github.com/kubernetes-sigs/cluster-api-provider-openstack)
* [https://github.com/kubernetes-sigs/cluster-api-provider-openstack/blob/master/docs/configuration.md](https://github.com/kubernetes-sigs/cluster-api-provider-openstack/blob/master/docs/configuration.md)
* [https://github.com/kubernetes-sigs/cluster-api-provider-openstack/blob/v0.3.3/docs/external-cloud-provider.md](https://github.com/kubernetes-sigs/cluster-api-provider-openstack/blob/v0.3.3/docs/external-cloud-provider.md)

