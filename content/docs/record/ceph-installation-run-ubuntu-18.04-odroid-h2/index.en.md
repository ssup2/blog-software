---
title: Ceph Installation, Execution / Ubuntu 18.04, ODROID-H2 Cluster Environment
---

## 1. Installation Environment

{{< figure caption="[Figure 1] Ceph Installation Environment (ODROID-H2 Cluster)" src="images/environment.png" width="1000px" >}}

[Figure 1] shows the Ceph installation environment using ODROID-H2 Cluster. Since Ceph will not be used as File Storage and Object Storage, MDS (Meta Data Server) and radosgw are not installed. The main installation environment is as follows.

* Node : Ubuntu 18.04
  * ODROID-H2 : Node 01, 02, 03 - Monitor, OSD, Manager
  * VM : Node 04 - Deploy
* Network
  * NAT Network : 192.168.0.0/24
  * Private Network : 10.0.0.0/24
* Storage
  * /dev/mmcblk0 : Root Filesystem
  * /dev/nvme0n1 : Ceph

## 2. Package Installation

### 2.1. Ceph Node

```shell
(Ceph)$ sudo apt install ntp
(Ceph)$ sudo apt install python
```

Install ntp and python Packages.

```shell
(Ceph)$ sudo useradd -d /home/cephnode -m cephnode
(Ceph)$ sudo passwd cephnode
Enter new UNIX password:
Retype new UNIX password:
passwd: password updated successfully

(Ceph)$ echo "cephnode ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephnode
(Ceph)$ sudo chmod 0440 /etc/sudoers.d/cephnode
```

Create a cephnode User.
* Password : cephnode

### 2.2. Deploy Node

```text {caption="[Text 1] Deploy Node - /etc/hosts", linenos=table}
...
10.0.0.11 node01
10.0.0.12 node02
10.0.0.13 node03
10.0.0.19 node09
...
```

Modify the /etc/hosts file as shown in [Text 1].

```shell
(Deploy)$ wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
(Deploy)$ echo deb https://download.ceph.com/debian-luminous/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
(Deploy)$ sudo apt update
(Deploy)$ sudo apt install ceph-deploy
```

Install the ceph-deploy Package.

```shell
(Deploy)$ sudo useradd -d /home/cephdeploy -m cephdeploy
(Deploy)$ sudo passwd cephdeploy
Enter new UNIX password:
Retype new UNIX password:
passwd: password updated successfully

(Deploy)$ echo "cephdeploy ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephdeploy
(Deploy)$ sudo chmod 0440 /etc/sudoers.d/cephdeploy
```

Create a cephdeploy User.
* Password : cephdeploy

```shell
(Deploy)$ login cephdeploy
(Deploy)$ ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
...

(Deploy)$ ssh-copy-id cephnode@node01
(Deploy)$ ssh-copy-id cephnode@node02
(Deploy)$ ssh-copy-id cephnode@node03
```

Generate and copy SSH Keys.
* Keep passphrases Empty.

```text {caption="[Text 2] Deploy Node - /home/cephdeploy/.ssh/config", linenos=table}
Host node01
   Hostname node01
   User cephnode
Host node02
   Hostname node02
   User cephnode
Host node03
   Hostname node03
   User cephnode
```

Modify the /home/cephdeploy/.ssh/config file as shown in [Text 2].

## 3. Ceph Cluster Configuration

### 3.1. Deploy Node

```shell
(Deploy)$ login cephdeploy
(Deploy)$ mkdir my-cluster
```

Create a Ceph Cluster Config folder.

```shell
(Deploy)$ login cephdeploy
(Deploy)$ cd ~/my-cluster
(Deploy)$ ceph-deploy purge node01 node02 node03
(Deploy)$ ceph-deploy purgedata node01 node02 node03
(Deploy)$ ceph-deploy forgetkeys
(Deploy)$ rm ceph.*
```

Initialize the Ceph Cluster.

```shell
(Deploy)$ login cephdeploy
(Deploy)$ cd ~/my-cluster
(Deploy)$ ceph-deploy new node01 node02 node03
(Deploy)$ ceph-deploy install node01 node02 node03
(Deploy)$ ceph-deploy mon create-initial
(Deploy)$ ceph-deploy admin node01 node02 node03
(Deploy)$ ceph-deploy mgr create node01 node02 node03
(Deploy)$ ceph-deploy osd create --data /dev/nvme0n1 node01
(Deploy)$ ceph-deploy osd create --data /dev/nvme0n1 node02
(Deploy)$ ceph-deploy osd create --data /dev/nvme0n1 node03
```

Build the Ceph Cluster. Install MON (Monitor Daemon) and MGR (Manager Daemon) on Node 01, Node 02, and Node 03.

## 4. Operation Verification

```shell
(Ceph)$ ceph -s
  cluster:
    id:     f2aeccb9-dac1-4271-8b06-19141d26e4cb
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum node01,node02,node03
    mgr: node01(active), standbys: node02, node03
    osd: 3 osds: 3 up, 3 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0  objects, 0 B
    usage:   3.0 GiB used, 712 GiB / 715 GiB avail
    pgs:  
```

Verify that the Ceph Cluster has been built correctly.

### 4.1. Block Storage

```shell
(Ceph)$ ceph osd pool create rbd 16
(Ceph)$ rbd pool init rbd
```

Create and initialize a Pool.

```shell
(Ceph)$ rbd create foo --size 4096 --image-feature layering
(Ceph)$ rbd map foo --name client.admin
/dev/rbd0
```

Create and map Block Storage.

## 5. References

* [http://docs.ceph.com/docs/master/start/](http://docs.ceph.com/docs/master/start/)
* [https://kubernetes.io/docs/concepts/storage/storage-classes/#ceph-rbd](https://kubernetes.io/docs/concepts/storage/storage-classes/#ceph-rbd)

