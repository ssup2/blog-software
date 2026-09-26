---
title: Kubernetes Installation / Using kubespray / Ubuntu 18.04, OpenStack Environment
---

## 1. Installation Environment

{{< figure caption="[Figure 1] Kubernetes Installation Environment" src="images/environment.png" width="900px" >}}

[Figure 1] shows the Kubernetes installation environment. The installation environment is as follows.

* VM: Ubuntu 18.04, 4 vCPU, 4GB Memory
  * ETCD Node * 3
  * Master Node * 2
  * Slave Node * 3
  * Deploy Node * 1
* Network
  * NAT Network: 192.168.0.0/24
  * Octavia Network: 20.0.0.0/24
  * Tenant Network: 30.0.0.0/24
* OpenStack: Stein
  * API Server: 192.168.0.40:5000
  * Octavia
* Kubernetes
  * CNI: Cilium Plugin
* kubespray: 2.10.4

## 2. Ubuntu Package Installation

```shell
(All)$ apt-get update
(All)$ apt-get install python-pip python3-pip
```

Install Python and Pip on all nodes.

## 3. Ansible Configuration

```shell
(Deploy)$ ssh-keygen -t rsa
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:Sp0SUDPNKxTIYVObstB0QQPoG/csF9qe/v5+S5e8hf4 root@kube02
The key's randomart image is:
+---[RSA 2048]----+
|   oBB@=         |
|  .+o+.*o        |
| .. o.+  .       |
|  o..ooo..       |
|   +.=ooS        |
|  . o.=o     . o |
|     +..    . = .|
|      o    ..o o |
|     ..oooo...o.E|
+----[SHA256]-----+
```

Generate an SSH key on the Deploy Node. Enter a blank for passphrase (Password) to not set it. If set, you must enter the passphrase every time accessing Managed Nodes via SSH from the Deploy Node.

```shell
(Deploy)$ ssh-copy-id root@30.0.0.11
(Deploy)$ ssh-copy-id root@30.0.0.12
(Deploy)$ ssh-copy-id root@30.0.0.13
```

Use the `ssh-copy-id` command from the Deploy Node to copy the generated SSH public key to the `~/.ssh/authorized_keys` file of the remaining nodes.

## 4. kubespray Configuration and Execution

```shell
(Deploy)$ ~
(Deploy)$ git clone -b v2.10.4 https://github.com/kubernetes-sigs/kubespray.git
(Deploy)$ cd kubespray
(Deploy)$ pip3 install -r requirements.txt
(Deploy)$ cp -rfp inventory/sample inventory/mycluster
```

Install kubespray and copy the sample inventory.

```text {caption="[File 1] Deploy Node - ~/kubespray/inventory/mycluster/inventory.ini", linenos=table}
[all]
vm01 ansible_host=30.0.0.11 ip=30.0.0.11 etcd_member_name=etcd1
vm02 ansible_host=30.0.0.12 ip=30.0.0.12 etcd_member_name=etcd2
vm03 ansible_host=30.0.0.13 ip=30.0.0.13 etcd_member_name=etcd3

[kube-master]
vm01
vm02

[etcd]
vm01
vm02
vm03

[kube-node]
vm01
vm02
vm03

[k8s-cluster:children]
kube-master
kube-node   
```

Store information and roles for each VM in the `inventory/mycluster/inventory.ini` file on the Deploy Node.

```text {caption="[File 2] Deploy Node - ~/kubespray/inventory/mycluster/group_vars/all/all.yml", linenos=table}
...
## There are some changes specific to the cloud providers
## for instance we need to encapsulate packets with some network plugins
## If set the possible values are either 'gce', 'aws', 'azure', 'openstack', 'vsphere', 'oci', or 'external'
## When openstack is used make sure to source in the openstack credentials
## like you would do when using openstack-client before starting the playbook.
## Note: The 'external' cloud provider is not supported.
## TODO(riverzhang): https://kubernetes.io/docs/tasks/administer-cluster/running-cloud-controller/#running-cloud-controller-manager
cloud_provider: openstack
...
```

Set the Cloud Provider to OpenStack in the `inventory/mycluster/group_vars/all/all.yml` file on the Deploy Node.

```text {caption="[File 3] Deploy Node - ~/kubespray/inventory/mycluster/group_vars/all/openstack.yml", linenos=table}
# # When OpenStack is used, if LBaaSv2 is available you can enable it with the following 2 variables.
openstack_lbaas_enabled: True
openstack_lbaas_subnet_id: [Tenant Network Subnet ID]
# To enable automatic floating ip provisioning, specify a subnet.
openstack_lbaas_floating_network_id: [NAT (External) Network ID]
# # Override default LBaaS behavior
openstack_lbaas_use_octavia: True
openstack_lbaas_method: "ROUND_ROBIN"
#openstack_lbaas_provider: "haproxy"
openstack_lbaas_create_monitor: "yes"
openstack_lbaas_monitor_delay: "1m"
openstack_lbaas_monitor_timeout: "30s"
openstack_lbaas_monitor_max_retries: "3"     
```

Configure the Octavia Load Balancer for Kubernetes LoadBalancer Service in the `inventory/mycluster/group_vars/all/openstack.yml` file on the Deploy Node. Check and set the External Network ID and External Network Subnet ID.

```text {caption="[File 4] Deploy Node - ~/kubespray/inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml", linenos=table}
...
kube_network_plugin: cilium
...
persistent_volumes_enabled: true
...
```

Configure the CNI plugin to use `cilium` and enable Persistent Volume in the `inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml` file on the Deploy Node to configure Kubernetes to use OpenStack's Cinder.

```text {caption="[File 5] Deploy Node - ~/kubespray/roles/bootstrap-os/defaults/main.yml", linenos=table}
...
## General
# Set the hostname to inventory_hostname
override_system_hostname: false
```

Configure the `roles/bootstrap-os/defaults/main.yml` file on the Deploy Node to not override the hostname where Kubernetes is installed.

```text {caption="[File 6] Deploy Node - ~/kubespray/openstack-rc", linenos=table}
export OS_AUTH_URL=http://192.168.0.40:5000/v3
export OS_PROJECT_ID=[Project ID]
export OS_PROJECT_NAME="admin"
export OS_USER_DOMAIN_NAME="Default"
export OS_USERNAME="admin"
export OS_PASSWORD="admin"
export OS_REGION_NAME="RegionOne"
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
```

Create the `openstack-rc` file based on the OpenStack RC file information.

```shell
(Deploy)$ source ~/kubespray/openstack-rc
(Deploy)$ ansible-playbook -i ~/kubespray/inventory/mycluster/inventory.ini --become --become-user=root cluster.yml
```

Configure the Kubernetes Cluster from the Deploy Node.

## 5. Kubernetes Cluster Reset

```shell
(Deploy)$ source openstack-rc
(Deploy)$ ansible-playbook -i ~/kubespray/inventory/mycluster/inventory.ini --become --become-user=root reset.yml
```

Reset the Kubernetes Cluster from the Deploy Node.

## 6. References

* [https://kubespray.io/#/](https://kubespray.io/#/)
* [https://github.com/kubernetes-sigs/kubespray/blob/master/docs/openstack.md](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/openstack.md)

