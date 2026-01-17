---
title: Ansible Installation / Ubuntu 18.04 Environment
---

## 1. Installation Environment

{{< figure caption="[Figure 1] Node Configuration Diagram for Ansible Installation" src="images/node-setting.png" width="700px" >}}

* Ubuntu 18.04 LTS 64bit, root user
* Ansible 2.5.1

## 2. Ansible Installation

```shell
(Control)$ apt-get install software-properties-common
(Control)$ apt-add-repository ppa:ansible/ansible
(Control)$ apt-get update
(Control)$ apt-get install ansible
```

Install Ansible on the Control Node.

## 3. Inventory Configuration

```text {caption="[File 1] Control Node - /etc/ansible/hosts", linenos=table}
[cluster]
172.35.0.101
172.35.0.102
```

Store IP information of Managed Nodes in the /etc/ansible/hosts file of the Control Node as in [File 1].

## 4. SSH Key Generation and Setting

```shell
(Control)$ ssh-keygen -t rsa
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
||   oBB@=         |
||  .+o+.*o        |
|| .. o.+  .       |
||  o..ooo..       |
||   +.=ooS        |
||  . o.=o     . o |
||     +..    . = .|
||      o    ..o o |
||     ..oooo...o.E|
+----[SHA256]-----+
```

Generate an ssh key on the Control Node. Enter blank for passphrase (Password) to not set it. If set, you must enter the passphrase every time accessing Managed Nodes from the Control Node through SSH.

```shell
(Control)$ ssh-copy-id root@172.35.0.101 
(Control)$ ssh-copy-id root@172.35.0.102
```

Copy the generated ssh Public Key to the ~/.ssh/authorized-keys file of all Managed Nodes using the ssh-copy-id command from the Control Node.

## 5. Ansible Execution

```shell
(Control)$ ansible all -m ping
172.35.0.101 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
172.35.0.102 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Check if ssh connection from Control Node to Managed Nodes is possible using the ansible all -m ping command from the Control Node.

## 6. References

* [https://docs.ansible.com/ansible/latest/installation-guide/index.html](https://docs.ansible.com/ansible/latest/installation-guide/index.html)
