---
title: Kubernetes 설치 / kubespray 이용 / Ubuntu 18.04, OpenStack 환경
---

## 1. 설치 환경

{{< figure caption="[Figure 1] Kubernetes 설치 환경" src="images/environment.png" width="900px" >}}

[Figure 1]은 Kubernetes 설치 환경을 나타내고 있다. 설치 환경은 다음과 같다.
* VM : Ubuntu 18.04, 4 vCPU, 4GB Memory
  * ETCD Node * 3
  * Master Node * 2
  * Slave Node * 3
  * Deploy Node * 1
* Network
  * NAT Network : 192.168.0.0/24
  * Octavia Network : 20.0.0.0/24
  * Tenant Network : 30.0.0.0/24
* OpenStack : Stein
  * API Server : 192.168.0.40:5000
  * Octavia
* Kubernetes
  * CNI : Cilium Plugin
* kubespray : 2.10.4

## 2. Ubuntu Package 설치

```shell
(All)$ apt-get update
(All)$ apt-get install python-pip python3-pip
```

모든 Node에 Python과 Pip를 설치한다.

## 3. Ansible 설정

```shell
(Deploy)$ ssh-keygen -t rsa
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id-rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id-rsa.
Your public key has been saved in /root/.ssh/id-rsa.pub.
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

Deploy Node에서 ssh key를 생성한다. passphrase (Password)는 공백을 입력하여 설정하지 않는다. 설정하게 되면 Deploy Node에서 Managed Node로 SSH를 통해서 접근 할때마다 passphrase를 입력해야 한다.

```shell
(Deploy)$ ssh-copy-id root@30.0.0.11
(Deploy)$ ssh-copy-id root@30.0.0.12
(Deploy)$ ssh-copy-id root@30.0.0.13
```

Deploy Node에서 ssh-copy-id 명령어를 이용하여 생성한 ssh Public Key를 나머지 Node의 ~/.ssh/authorized-keys 파일에 복사한다.

## 4. kubespray 설정, 구동

```shell
(Deploy)$ ~
(Deploy)$ git clone -b v2.10.4 https://github.com/kubernetes-sigs/kubespray.git
(Deploy)$ cd kubespray
(Deploy)$ pip3 install -r requirements.txt
(Deploy)$ cp -rfp inventory/sample inventory/mycluster
```

kubespray를 설치하고 Sample Inventory를 복사한다.

```text {caption="[File 1] Deploy Node - ~/kubespray/inventory/mycluster/inventory.ini", linenos=table}
[all]
vm01 ansible-host=30.0.0.11 ip=30.0.0.11 etcd-member-name=etcd1
vm02 ansible-host=30.0.0.12 ip=30.0.0.12 etcd-member-name=etcd2
vm03 ansible-host=30.0.0.13 ip=30.0.0.13 etcd-member-name=etcd3

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

Deploy Node의 inventory/mycluster/inventory.ini 파일에 각 VM의 정보 및 역할을 저장한다.

```text {caption="[File 2] Deploy Node - ~/kubespray/inventory/mycluster/group-vars/all/all.yml", linenos=table}
...
## There are some changes specific to the cloud providers
## for instance we need to encapsulate packets with some network plugins
## If set the possible values are either 'gce', 'aws', 'azure', 'openstack', 'vsphere', 'oci', or 'external'
## When openstack is used make sure to source in the openstack credentials
## like you would do when using openstack-client before starting the playbook.
## Note: The 'external' cloud provider is not supported.
## TODO(riverzhang): https://kubernetes.io/docs/tasks/administer-cluster/running-cloud-controller/#running-cloud-controller-manager
cloud-provider: openstack
...
```

Deploy Node의 inventory/mycluster/group-vars/all/all.yml 파일에 Cloud Provider를 OpenStack으로 설정한다.

```text {caption="[File 3] Deploy Node - ~/kubespray/inventory/mycluster/group-vars/all/openstack.yml", linenos=table}
# # When OpenStack is used, if LBaaSv2 is available you can enable it with the following 2 variables.
openstack-lbaas-enabled: True
openstack-lbaas-subnet-id: [Tenant Network Subnet ID]
# To enable automatic floating ip provisioning, specify a subnet.
openstack-lbaas-floating-network-id: [NAT (External) Network ID]
# # Override default LBaaS behavior
openstack-lbaas-use-octavia: True
openstack-lbaas-method: "ROUND-ROBIN"
#openstack-lbaas-provider: "haproxy"
openstack-lbaas-create-monitor: "yes"
openstack-lbaas-monitor-delay: "1m"
openstack-lbaas-monitor-timeout: "30s"
openstack-lbaas-monitor-max-retries: "3"     
```

Deploy Node의 inventory/mycluster/group-vars/all/openstack.yml 파일에 Kubernetes LoadBalancer Service를 위하여 Octavia Load Balancer를 설정한다. External Network의 ID와 External Network의 Subnet ID를 확인하여 설정한다.

```text {caption="[File 4] Deploy Node - ~/kubespray/inventory/mycluster/group-vars/k8s-cluster/k8s-cluster.yml", linenos=table}
...
kube-network-plugin: cilium
...
persistent-volumes-enabled: true
...
```

Deploy Node의 inventory/mycluster/group-vars/k8s-cluster/k8s-cluster.yml 파일에 CNI Plugin으로 cilium을 이용하도록 설정하고, Persistent Volume을 Enable 설정하여 Kubernetes가 OpenStack의 Cinder를 이용하도록 설정한다.

```text {caption="[File 5] Deploy Node - ~/kubespray/roles/bootstrap-os/defaults/main.yml", linenos=table}
...
## General
# Set the hostname to inventory-hostname
override-system-hostname: false
```

Deploy Node의 roles/bootstrap-os/defaults/main.yml 파일에 Kubernetes가 설치되는 Hostname을 Override하지 않도록 설정한다.

```text {caption="[File 6] Deploy Node - ~/kubespray/openstack-rc", linenos=table}
export OS-AUTH-URL=http://192.168.0.40:5000/v3
export OS-PROJECT-ID=[Project ID]
export OS-PROJECT-NAME="admin"
export OS-USER-DOMAIN-NAME="Default"
export OS-USERNAME="admin"
export OS-PASSWORD="admin"
export OS-REGION-NAME="RegionOne"
export OS-INTERFACE=public
export OS-IDENTITY-API-VERSION=3
```

OpenStack RC 파일의 정보를 바탕으로 openstack-rc 파일을 생성한다.

```shell
(Deploy)$ source ~/kubespray/openstack-rc
(Deploy)$ ansible-playbook -i ~/kubespray/inventory/mycluster/inventory.ini --become --become-user=root cluster.yml
```

Deploy Node에서 Kubernets Cluster를 구성한다.

## 5. Kubernetes Cluster 초기화

```shell
(Deploy)$ source openstack-rc
(Deploy)$ ansible-playbook -i ~/kubespray/inventory/mycluster/inventory.ini --become --become-user=root reset.yml
```

Deploy Node에서 Kubernetes Cluster를 초기화한다.

## 6. 참고

* [https://kubespray.io/#/](https://kubespray.io/#/)
* [https://github.com/kubernetes-sigs/kubespray/blob/master/docs/openstack.md](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/openstack.md)