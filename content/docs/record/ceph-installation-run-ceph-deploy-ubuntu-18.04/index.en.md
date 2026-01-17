---
title: Ceph Installation, Execution / Using ceph-deploy / Ubuntu 18.04 Environment
---

## 1. Installation Environment

The installation and execution environment is as follows.
* Ubuntu 18.04 LTS 64bit, root user
* Ceph Luminous Version

## 2. Node Configuration

{{< figure caption="[Figure 1] Node Configuration Diagram for Ceph Installation" src="images/node-setting.png" width="900px" >}}

Create virtual Nodes (VMs) using VirtualBox as shown in [Figure 1].
* Hostname : Master Node - node01, Worker node01 - node02, Worker node02 - node03
* NAT : Build a 10.0.0.0/24 Network using the "NAT Network" provided by Virtual Box.
* HDD : Create and attach an additional HDD (/dev/sdb) for Ceph to use on each Node.
* Router : Build a 192.168.0.0/24 Network using a router. (NAT)

### 2.1. Ceph Node

```yaml {caption="[File 1] Node 01 - /etc/netplan/50-cloud-init.yaml", linenos=table}
network:
    version: 2
    ethernets:
        enp0s3:
            dhcp4: no
            addresses: [10.0.0.10/24]
            gateway4: 10.0.0.1
            nameservers:
                addresses: [8.8.8.8]
        enp0s8:
            dhcp4: no
            addresses: [192.168.0.150/24]
            nameservers:
                addresses: [8.8.8.8]
```

Create the /etc/netplan/50-cloud-init.yaml file of Ceph Node 01 with the contents of [File 1].

```yaml {caption="[File 2] Node 02 - /etc/netplan/50-cloud-init.yaml", linenos=table}
network:
    version: 2
    ethernets:
        enp0s3:
            dhcp4: no
            addresses: [10.0.0.20/24]
            gateway4: 10.0.0.1
            nameservers:
                addresses: [8.8.8.8]
```

Create the /etc/netplan/50-cloud-init.yaml file of Ceph Node 02 with the contents of [File 2].

```yaml {caption="[File 3] Node 03 - /etc/netplan/50-cloud-init.yaml", linenos=table}
network:
    version: 2
    ethernets:
        enp0s3:
            dhcp4: no
            addresses: [10.0.0.30/24]
            gateway4: 10.0.0.1
            nameservers:
                addresses: [8.8.8.8]
```

Create the /etc/netplan/50-cloud-init.yaml file of Ceph Node 03 with the contents of [File 3].

## 3. Package Installation

### 3.1. Ceph Node

```shell
(Ceph)# sudo apt install ntp
(Ceph)# sudo apt install python
```

Install ntp and python Packages.

```shell
(Ceph)# sudo useradd -d /home/cephnode -m cephnode
(Ceph)# sudo passwd cephnode
Enter new UNIX password:
Retype new UNIX password:
passwd: password updated successfully

(Ceph)# echo "cephnode ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephnode
(Ceph)# sudo chmod 0440 /etc/sudoers.d/cephnode
```

Create a cephnode User.
* Password : cephnode

### 3.2. Deploy Node

```text {caption="[File 4] Deploy Node - /etc/hosts", linenos=table}
...
10.0.0.10 node01
10.0.0.20 node02
10.0.0.30 node03
...
```

Modify the /etc/hosts file as shown in [File 4].

```shell
(Deploy)# wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
(Deploy)# echo deb https://download.ceph.com/debian-luminous/ $(lsb-release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
(Deploy)# sudo apt update
(Deploy)# sudo apt install ceph-deploy
```

Install the ceph-deploy Package.

```shell
(Deploy)# sudo useradd -d /home/cephdeploy -m cephdeploy
(Deploy)# sudo passwd cephdeploy
Enter new UNIX password:
Retype new UNIX password:
passwd: password updated successfully

(Deploy)# echo "cephdeploy ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephdeploy
(Deploy)# sudo chmod 0440 /etc/sudoers.d/cephdeploy
```

Create a cephdeploy User.
* Password : cephdeploy

```shell
(Deploy)# login cephdeploy
(Deploy)$ ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id-rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
...

(Deploy)$ ssh-copy-id cephnode@node01
(Deploy)$ ssh-copy-id cephnode@node02
(Deploy)$ ssh-copy-id cephnode@node03
```

Generate and copy SSH Keys.
* Keep passphrases Empty.

```text {caption="[File 5] Deploy Node - /home/cephdeploy/.ssh/config", linenos=table}
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

Modify the /home/cephdeploy/.ssh/config file as shown in [File 5].

## 4. Ceph Cluster Configuration

### 4.1. Deploy Node

```shell
(Deploy)# login cephdeploy
(Deploy)$ mkdir my-cluster
```

Create a Ceph Cluster Config folder.

```shell
(Deploy)# login cephdeploy
(Deploy)$ cd ~/my-cluster
(Deploy)$ ceph-deploy purge node01 node02 node03
(Deploy)$ ceph-deploy purgedata node01 node02 node03
(Deploy)$ ceph-deploy forgetkeys
(Deploy)$ rm ceph.*
```

Initialize the Ceph Cluster.

```shell
(Deploy)# login cephdeploy
(Deploy)$ cd ~/my-cluster
(Deploy)$ ceph-deploy new node01
(Deploy)$ ceph-deploy install node01 node02 node03
(Deploy)$ ceph-deploy mon create-initial
(Deploy)$ ceph-deploy admin node01 node02 node03
(Deploy)$ ceph-deploy mgr create node01
(Deploy)$ ceph-deploy osd create --data /dev/sdb node01
(Deploy)$ ceph-deploy osd create --data /dev/sdb node02
(Deploy)$ ceph-deploy osd create --data /dev/sdb node03
```

Build the Ceph Cluster. Install MON (Monitor Daemon) and MGR (Manager Daemon) on Ceph Node 01. If you want to install MON and MGR on other Nodes as well, include information about other Nodes to install when executing the "ceph-deploy new" command and "ceph-deploy mgr create" command, not just node01.

```shell
(Deploy)# login cephdeploy
(Deploy)$ cd ~/my-cluster
(Deploy)$ ceph-deploy mds create node01
```

Install MDS (Meta Data Server). MDS (Meta Data Server) is installed on Ceph Node 01. If you want to install MDS on other Nodes as well, include information about other Nodes where MDS will be installed when executing the "ceph-deploy mds create" command.

```shell
(Deploy)# login cephdeploy
(Deploy)$ cd ~/my-cluster
(Deploy)$ ceph-deploy rgw create node01
```

Install RGW (Rados Gateway). RGW is installed on Ceph Node 01.

## 5. Operation Verification

```shell
(Ceph)# ceph -s 
  cluster:
    id:     20261612-97fc-4a45-bd81-0d9c9b445e00
    health: HEALTH-OK

  services:
    mon: 1 daemons, quorum node01
    mgr: node01(active)
    osd: 3 osds: 3 up, 3 in
    rgw: 1 daemon active

  data:
    pools:   4 pools, 32 pgs
    objects: 187  objects, 1.1 KiB
    usage:   3.0 GiB used, 597 GiB / 600 GiB avail
    pgs:     32 active+clean
```

Verify that the Ceph Cluster has been built correctly.

### 5.1. Block Storage

```shell
(Ceph)# ceph osd pool create rbd 16
(Ceph)# rbd pool init rbd
```

Create and initialize a Pool.

```shell
(Ceph)# rbd create foo --size 4096 --image-feature layering
(Ceph)# rbd map foo --name client.admin
/dev/rbd0
```

Create and map Block Storage.

### 5.2. File Storage

```shell
(Ceph)# ceph osd pool create cephfs-data 16
(Ceph)# ceph osd pool create cephfs-metadata 16
(Ceph)# ceph fs new filesystem cephfs-metadata cephfs-data
```

Create a Pool and File Storage.

```shell
(Ceph)# cat /home/cephdeploy/my-cluster/ceph.client.admin.keyring
[client.admin]
        key = AQAk1SxcbTz/IBAAHCPTQ5x1SHFcA0fn2tTW7w==
        caps mds = "allow *"
        caps mgr = "allow *"
        caps mon = "allow *"
        caps osd = "allow *"
```

Check the admin Key.

```text {caption="[File 6] Ceph Node - /root/admin.secret", linenos=table}
AQAk1SxcbTz/IBAAHCPTQ5x1SHFcA0fn2tTW7w==
```

Create the /root/admin.secret file with the contents of [File 6] using the checked admin Key.

```shell
(Ceph)# mkdir mnt
(Ceph)# mount -t ceph 10.0.0.10:6789:/ mnt/ -o name=admin,secretfile=/root/admin.secret
(Ceph)# mount
...
10.0.0.10:6789:/ on /root/test/ceph/mnt type ceph (rw,relatime,name=admin,secret=<hidden>,acl,wsize=16777216)
```

Mount the Ceph File Server.

### 5.3. Object Storage

```shell
(Ceph)# curl 10.0.0.10:7480
<?xml version="1.0" encoding="UTF-8"?><ListAllMyBucketsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><Owner><ID>anonymous</ID><DisplayName></DisplayName></Owner><Buckets></Buckets></ListAllMyBucketsResult>
```

Verify RGW operation.

## 6. References

* [http://docs.ceph.com/docs/master/start/](http://docs.ceph.com/docs/master/start/)
* [https://kubernetes.io/docs/concepts/storage/storage-classes/#ceph-rbd](https://kubernetes.io/docs/concepts/storage/storage-classes/#ceph-rbd)

