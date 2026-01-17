---
title: OpenStack Stein Installation / Using Kolla-Ansible / Ubuntu 18.04, ODROID-H2 Cluster Environment
---

## 1. Installation Environment

{{< figure caption="[Figure 1] OpenStack Stein Installation Environment (ODROID-H2 Cluster)" src="images/environment.png" width="1000px" >}}

[Figure 1] shows the OpenStack installation environment based on an ODROID-H2 cluster. Detailed environment information is as follows:

* OpenStack : Stein
* Kolla : 8.0.0
* Kolla-Ansible : 8.0.0
* Octiava : 4.0.1
* Node : Ubuntu 18.04, root user
  * ODROID-H2
    * Node 01 : Controller Node, Network Node, Ceph Node (MON, MGR, OSD)
    * Node 02, 03 : Compute Node, Ceph Node (OSD)
  * VM
    * Node 09 : Monitoring Node, Registry Node, Deploy Node
* Network
  * NAT Network : External Network (Provider Network), 192.168.0.0/24
    * Floating IP Range : 192.168.0.200 ~ 224
  * Private Network : Guest Network (Tenant Network), Management Network, 10.0.0.0/24
    * Node Default Gateway
* Storage
  * /dev/mmcblk0 : Root Filesystem, 64GB
  * /dev/nvme0n1 : Ceph, 256GB

## 2. OpenStack Components

The components to be installed among OpenStack components are as follows:

* Nova : Provides VM Service.
* Neutron : Provides Network Service.
* Octavia : Provides Load Balancer Service.
* Keystone : Provides Authentication and Authorization Service.
* Glance : Provides VM Image Service.
* Cinder : Provides VM Block Storage Service.
* Horizon : Provides Web Dashboard Service.
* Prometheus : Stores metric information.
* Grafana : Visualizes metric information stored in Prometheus in various graphs.
* Ceph : Acts as backend storage for Glance and Cinder.

## 3. Network Configuration

### 3.1. Node01 Node

```text {caption="[Text 1] Node01 - /etc/netplan/50-cloud-init.yaml", linenos=table}
network:
    ethernets:
        enx88366cf9f9ed:
            addresses:
            - 0.0.0.0/8
        enp2s0:
            addresses:
            - 192.168.0.31/24
            gateway4: 192.168.0.1
            nameservers:
                addresses:
                - 8.8.8.8
        enp3s0:
            addresses:
            - 10.0.0.11/24
    version: 2
```

Configure the IP of the Node01 interface.

### 3.2. Node02 Node

```text {caption="[Text 2] Node02 - /etc/netplan/50-cloud-init.yamls", linenos=table}
network:
    ethernets:
        enp2s0:
            addresses:
            - 192.168.0.32/24
            gateway4: 192.168.0.1
            nameservers:
                addresses:
                - 8.8.8.8
        enp3s0:
            addresses:
            - 10.0.0.12/24
    version: 2
```

Configure the IP of the Node02 interface.

### 3.3. Node03 Node

```text {caption="[Text 3] Node03 - /etc/netplan/50-cloud-init.yaml", linenos=table}
network:
    ethernets:
        enp2s0:
            addresses:
            - 192.168.0.33/24
            gateway4: 192.168.0.1
            nameservers:
                addresses:
                - 8.8.8.8
        enp3s0:
            addresses:
            - 10.0.0.13/24
    version: 2
```

Configure the IP of the Node03 interface.

### 3.4. Node09 Node

```text {caption="[Text 4] Node09 - /etc/netplan/50-cloud-init.yaml", linenos=table}
network:
    ethernets:
        eth0:
            addresses:
            - 192.168.0.39/24
            gateway4: 192.168.0.1
            nameservers:
                addresses:
                - 8.8.8.8
        eth1:
            addresses:
            - 10.0.0.19/24
    version: 2
```

Configure the IP of the Node04 interface.

## 4. Package Installation

### 4.1. Deploy Node

```shell
(Deploy)$ apt-get install software-properties-common
(Deploy)$ apt-add-repository ppa:ansible/ansible
(Deploy)$ apt-get update
(Deploy)$ apt-get install ansible python-pip python3-pip libguestfs-tools
(Deploy)$ pip install kolla==8.0.0 kolla-ansible==8.0.0 tox gitpython pbr requests jinja2 oslo_config
(Deploy)$ pip install python-openstackclient python-glanceclient python-neutronclient
```

Install Ansible, Kolla-ansible, and Ubuntu and Python packages required for building Kolla container images on the Deploy Node. Also install the OpenStack CLI client.

### 4.2. Registry Node

```shell
(Registry)$ apt-get install docker-ce
```

Install Docker on the Registry Node to run the Registry Node.

### 4.3. Network, Compute Node

```shell
(Network, Compute)$ apt-get remove --purge openvswitch-switch
```

If the Open vSwitch package is installed, remove it to eliminate Open vSwitch running on the host. Open vSwitch-related daemons must run only in containers. Running Open vSwitch-related daemons simultaneously on the host and in containers will cause improper operation.

### 4.4. All Node

```shell
(All Node)$ apt-get install ifupdown
(All Node)$ apt-get remove --purge netplan.io
```

Install ifupdown and remove netplan.

## 5. Ansible Configuration

Configure SSH access from the Deploy Node to other nodes without a password.

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

Generate an SSH key on the Deploy Node. Enter a blank for the passphrase (password) to not set it. If set, you will need to enter the passphrase each time accessing other nodes from the Deploy Node via SSH.

```shell
(Deploy)$ ssh-copy-id root@10.0.0.11
(Deploy)$ ssh-copy-id root@10.0.0.12
(Deploy)$ ssh-copy-id root@10.0.0.13
(Deploy)$ ssh-copy-id root@10.0.0.19
```

Copy the generated SSH public key to the ~/.ssh/authorized_keys file of the remaining nodes using the ssh-copy-id command.

```text {caption="[Text 5] Deploy Node - /etc/hosts", linenos=table}
...
10.0.0.11 node01
10.0.0.12 node02
10.0.0.13 node03
10.0.0.19 node09
...
```

Modify the /etc/hosts file on the Deploy Node as shown in [Text 5].

```text {caption="[Text 6] Deploy Node - /etc/ansible/ansible.cfg", linenos=table}
...
[defaults]
host_key_checking=False
pipelining=True
forks=100
...
```

Modify the /etc/ansible/ansible.cfg file on the Deploy Node as shown in [Text 6].

## 6. Kolla-Ansible Configuration

```shell
(Deploy)$ mkdir -p ~/kolla-ansible
(Deploy)$ cp /usr/local/share/kolla-ansible/ansible/inventory/* ~/kolla-ansible/
(Deploy)$ mkdir -p /etc/kolla
(Deploy)$ cp -r /usr/local/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
```

Copy inventory files. Also copy the **global.yaml** config file and the **passwords.yml** file containing password information.

```text {caption="[Text 7] Deploy Node - ~/kolla-ansible/multinode", linenos=table}
# These initial groups are the only groups required to be modified. The
# additional groups are for more control of the environment.
[control]
# These hostname must be resolvable from your deployment host
node01

# The above can also be specified as follows:
#control[01:03]     ansible_user=kolla

# The network nodes are where your l3-agent and loadbalancers will run
# This can be the same as a host in the control group
[network]
node01

[compute]
node02
node03

[monitoring]
node09 api_interface=eth1

# When compute nodes and control nodes use different interfaces,
# you need to comment out "api_interface" and other interfaces from the globals.yml
# and specify like below:
#compute01 neutron_external_interface=eth0 api_interface=em1 storage_interface=em1 tunnel_interface=em1

[storage]
node01
node02
node03

[deployment]
node09

[baremetal:children]
control
network
compute
storage
monitoring

# You can explicitly specify which hosts run each project by updating the
# groups in the sections below. Common services are grouped together.
[chrony-server:children]
haproxy
...
```

Configure the Ansible inventory. Change the ~/kolla-ansible/multinode file on the Deploy Node to the contents of [Text 7]. Only the [control], [network], [external-compute], [monitoring], [storage], [deployment] sections at the top of the ~/kolla-ansible/multinode file have been modified to match the ODROID-H2 cluster environment, and the rest of the file's lower sections remain with default settings.

```yaml {caption="[Text 8] Deploy Node - /etc/kolla/passwords.yml", linenos=table}
# Database
database_password: admin

# Registry
docker_registry_password: admin

# OpenStack
keystone_admin_password: admin
keystone_database_password: admin

glance_database_password: admin
glance_keystone_password: admin

nova_database_password: admin
nova_api_database_password: admin
nova_keystone_password: admin

placement_keystone_password: admin
placement_database_password: admin

neutron_database_password: admin
neutron_keystone_password: admin
metadata_secret: admin

cinder_database_password: admin
cinder_keystone_password: admin

octavia_database_password: admin
octavia_keystone_password: admin
octavia_ca_password: admin

horizon_secret_key: admin
horizon_database_password: admin

memcache_secret_key: admin

nova_ssh_key:
  private_key: |
    -----BEGIN PRIVATE KEY-----
    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
    IF1ExGI4cbSuAWSAN5kYhY6yiOf4uA==
    -----END PRIVATE KEY-----
  public_key: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDZqI3UF+5q/SalhTdUz3I/G7/Yg58oeL1FLOciC7j8Gpf/3P0q3g+0k7Ftj0KVtD+QTwrDj+agIyu+MTnqNt+9qHS5F8ib3MXkK27QArwT94HDWwPLKX9+CCtUYjyJh96AH0gvwEjBATo0g05xeBmeZ2/5IfVPwSDL/hGOBJtea/2prUf13PN8JjKP4qlzbJJX9fRuv2xT8vUdcAvLXpbqzMaHB71N4LmDkNMjh3k4m4Rs04TQx9q0OcsJczcSgCT6qwO4Y+k+5xBavpb5lGv9KaM7klTaK8DojrXBuJa7YloAOo5EDEq32Xa0mc2eb8HqlPf4Z8E8IQZARUtnVN7WzUraSqBsjQm1PpC5WMd39yzcYs2whNQCIpSNx0v+z+2n3/s8rR5jXe3SpCCPnXi7FnjF6aXHmA5RLYxzP6ihs5rg0lm66vEVRIoHGPknEvwAmnBEB1wms9Hx/V540Vl2fVb5TGWFq/6dUjxYiA/Px0Yk5cqui18UKqZrSV5VhjqAuEUzcVIRyVnRlM4X23MshiSVVfBZuiJnyK2PvOTzlonBkOv4z1WxLNnJvjohnRuKIOL+M8twp0ZGpbRHfGfGz6ZE/iYTjOzqCEi8gXi0EooolzGb3abpQLBnkYSrx9KLhFDwYNgyQX3vTryAGPUTOa0Un5OU7DU584/RoHoPOw==

keystone_ssh_key:
  private_key: |
    -----BEGIN PRIVATE KEY-----
    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
    rSP+fx+AovIkyL3UybeH0FRf+p59NYI=
    -----END PRIVATE KEY-----
  public_key: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC65KILqRN8m7hHTThOhmnRsp7Cj9WmF1TrPXlbtEQodIy6EFcxwKWdgSCCGqF0VSN/yfq382WO1/lviNd98gB2NmGusZ1CcI9BMgAb07TXqyHphvglHvTZ3Ls7pU6pgxRc9tPOsAVsVbNJvGlSfu/WUsxvimMunR8STuSgxRZpPlOT41jHe6tXC1TbRbtlAIECs+rl9gMDp6FvbiMy9eoPnb7ukEDDJRrdq+LVoczd+1If4dNhx46EXUH0IM+VR5+GUtsBC01haNRSSaNR39+cXua7CL8vsl9unpbP0Dvf64uDvqU9OAxbFHZO4+rdUoZeqPZY1i4fJMSt+vIeZtnUYNzLT6cNKNJJbtZDbnjwsvLeaM8segF/WSquAdyZoJJHAnA29l57YWSK8H0Y3QVyCXEvUyRSyE43UL2ziEOYBHsn4PAecIaSm6um0fdXgeMdizhO1SJ1yT3drkxyOghYEaFEBBrVDIT78ZbHqcRS+xBPvIUobNHkfriUSVUVDKnK1cqffTh/gSA+LVYn9IktAlBv5ws+knuH4wzL/81xa8axQYEFJ7TbfvZZubK97yxFPLQbK20ogOMjr30K+Znn00DHSlqQxOsTFPWWBkzIcCAeU4MREKb4BbXJlCHBeJucyZg+EsEVC5IJKsKyY80WciByhRgP3XJ9wXTgYJRZ0w==

kolla_ssh_key:
  private_key: |
    -----BEGIN PRIVATE KEY-----
    MIIJQgIBADANBgkqhkiG9w0BAQEFAASCCSwwggkoAgEAAoICAQCiG/gEHogaHk1T
    aRB2R37gsSMMAsO73D9lMpDdgViYOG/QHFhXwsdpdE/TWxW1rilK6OnqPjMah5AS
    f2cqtPB/jVbTtwccp6WEk1L2mfHBHgo5yVVLLmQQjff/1qZXjjnWRJ134qaUr3Fw
    9NnuX5fJ3k+dYCuMmWV02ZvAyq2wxG1YepRnG71Cgs5En2uHPTSWkkUc1WM5S3ZM
    gC/JXChiALzCFFiOeVFXfYz0Jslmm77HNB9fFgBBL71L7hy+PlJx+3O5rtC5Zxi+
    zcALdcOJtn4eXt2uKii5gaY3DB9q+RMrBjqanASdA808rok4jr9AiYMRW1lWNjO1
    uZxEZMWhaWgUCpoW8JYoEkJfjQQJRpFXImJBOzxZFGv/IDt8MFw/NOyY1Kuob5BN
    fbOTpYgkdAJrErcy0aEyteiSWo4k/bvdEk/tPRGZFm3dDVIYeiEl9iowgyl5QcSL
    1jsNdpfLXpYp9W8oL15q6xb50yOUPGn/Z3CtWqtyYMW6u2TIfpCiO/G3PX1D/82L
    dvxPha/tZcCN0ewTe95bVclazIMyTTBk4YHNda0WWjlHXPsBnYrgj49/dgOltcaR
    blSOPp2wlnDarHMuwUu8khCepP9sf6camPhCuPen9jtGOxIR8LI82FcLOU8KkCPQ
    Oz2N1+zq8of6APcJMNSdobTYFZQISQIDAQABAoICAA+zG7ryZgX5h02bsD90PyJt
    pVJFdkVcWDtpwUPigf0EAjgqdpfRQlTBMfXrLVgSDOe3VOgdq/9Wv6o68nfdXClO
    O+l3IVYyGkKTrgY59ILacO0VxY/pZ0F/LlR1qlhyasGIlaOFrNJbh2YEIJMIaP/g
    6t738F/Gf1/orz/loRqse1aFUJgHxLWLS4Sz18saL1yhv9XCCMEEwOk5xOcAaNzM
    63r0U3tA3pLVkvAWTY0Fal2Ke7tOuymVAQU4g0odaQim7JdACfDavjfEX2P8vLo6
    lU5Fq7xxUs5ccweDwgsvIh8ZlFVi5MN8GcVVte5nTLhoWOw2Z5mE2E8yMaMiC02m
    GfMG14XF4Q0qVzx6sPWu0dMuVDlZYDKroJwLslO1AqIzvauGxxg9/pSl2HT4B8lS
    JGrDWB2oEdd/ktBlz0iAuFzkIOABPxdHfW+EqEOSwKesSOC5H60kCKcI1R0lz167
    PL6t7ExJ+7I8x4+Jgw703wT25fX747WoGbZhjUFc3sHGv/CkSLCHs27rsT2yStJw
    UcgUy6eigAz/X7kt5N2NsbUGVjrxL+ev1ksKlo86MX8/tbLgV499abE5YHYqdc1G
    wsRnTPPXdHOqOqawUv44Or/Igk1dFZzuLJx3qayBhSTEOSh0wF35ax+jBAvbhrKh
    Hgls+n1cxp0+g6ZuhvOtAoIBAQDRAjlIAJbEfLi++S0U9vVoQjvt6vpinwEaZCco
    2mntkTkgXLSncXQjN5z3nFqw3q7kF6RUQA8tmOhcUu0kCPUKsKByOPmCC+gF0fhQ
    1Ld0wdghkMLOuKa7JCRyY8fBLrGlMvMU7VLjDlP4AQfCyy9LBWjqhWj2siaoARRW
    Ei2OitQ+q46dphxSFNPGuz20VUKPoMdRF8b3Xcqspj0JOTBNtjnZ87HooVqxL7u2
    etzLT5L1E4vvnrxNd0X71CRTlod2665K5JbF2n1HohSQ8S0Ex5HtVNpaeCo2zIVj
    39S9jLyfKIlvzMrQMHbehVt3POuKZ3AmuyYDGD6XkrqzRyejAoIBAQDGjmKSvcbH
    6q+aGKRqXDKm80QESnA0ZI0vLfjye9Y69FuIcmV4LujzYHK3Avt3jkKK4stFYzbV
    DvaE5AP5BhUL5SMIpRVx5I5k/8zvexIWLq8y/8FwLfAaN5KwbeFcVQhbJej3DgaT
    LijrWYhYcEDOdvJKoCEvWawMCwNviraaBpXS703DUi5mDKr6bAJ4J52FPttVKH+8
    S/1iUmffMsw1y++8mq46m/j6ePP1fZw4Sa8+Z1t2zsFGtEPxPmfIlYKPr/YMZcUZ
    eriMNC3qhkKTo7fPfeb2Rp6g6xPBnKIl5Ab26nn3S4beCSrkS4Bw9cTuDKwYbrHM
    knahOo8zDb8jAoIBAD04JYcNhRuwXHyzh5zoaSFMpTke5pAUesI8K6wvrW9EZjMw
    dEnHVXkrRPLR/U5pK1jsA9oZmViFvSmtsIApj3y+F4DdZ1fMHP33boBejg3I6YGL
    YUQjmdKe134Z89yFzMrSjZjHmsue2sF9q8RGt2eGAiEPSptXuzLifg5n7KgfyeNB
    ZNiQWyM/rng7R+uWPZTMRxVdnY2/Dypa1u3orllU0sUgODAncuULUjQ08I8sk6Lt
    QsPA/u7BzOHiVXGWWb9fcQHGytLRGHju5I8/1SvdOMUHYZ22LMc4SKnkWe/bVTRZ
    L0hr98vbJjYvYYcfdO5pNdRiZNPrOgozlDQG13kCggEBALt/c4g8m3znmoF6qbAi
    dlZ/PAiNPp3LIiOeVwqsdGXhoJod5MH0EljZCBrYPxzsAtxiRC+2++2AHrzpEPNU
    kgVUkJu2QKT3fpvTjvPKlQ7LcPhI2aMUTjqDpgrjCEAHsEdaaj76SK0tlsiAGKfj
    AN+3JR/hTNUI6dXJhKoNJFgYxdyVzCoY7eXCKqcl3cMXLcHI1Jf7EXx/ibwSMzJr
    JrnaZf4FV2fTJ+9mzoFQ53ej5U+ZjJ6JqawZyFsEYj7hKJSFRmT4qYJhB+qlz4I6
    3J3MqWPP8Y04rM0qj9JyFhCP3x/F1fz3nlkH8S/6OETzYM6mutCrn0yeNlYUFWvR
    nF8CggEAXUnMDJ7FWnuQ1WH7boB7j11VhFypGabulCNYIypdW+L0XPZDYt3EHk8G
    DcqcgN1rrf4hEfD0lSZmdyX6pKEaRmgJFdCLkbcLUexU/zsf4lgao4WkqSD5s2X/
    /0PJFD+Ey4De4vt4Ve9oLN9ajaJahX1OI2bGzYXvgAmrUXiCx3XRjxxyGPkX/X+T
    Wp8kbNV9rDhalWJB6EVS9g6UpWdRoOIoGjWnhZNCzTTKhupNEu6EHYqWq7+6h80H
    ees72z247ZpuwEQ+ytwEciAxOyNpY236MjrhzAnx9RgZVboEoqe3DbCZ1DON0Dq+
    SGFlm9DOlGgUTBJZnAcFBXFVbBn9BA==
    -----END PRIVATE KEY-----
  public_key: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiG/gEHogaHk1TaRB2R37gsSMMAsO73D9lMpDdgViYOG/QHFhXwsdpdE/TWxW1rilK6OnqPjMah5ASf2cqtPB/jVbTtwccp6WEk1L2mfHBHgo5yVVLLmQQjff/1qZXjjnWRJ134qaUr3Fw9NnuX5fJ3k+dYCuMmWV02ZvAyq2wxG1YepRnG71Cgs5En2uHPTSWkkUc1WM5S3ZMgC/JXChiALzCFFiOeVFXfYz0Jslmm77HNB9fFgBBL71L7hy+PlJx+3O5rtC5Zxi+zcALdcOJtn4eXt2uKii5gaY3DB9q+RMrBjqanASdA808rok4jr9AiYMRW1lWNjO1uZxEZMWhaWgUCpoW8JYoEkJfjQQJRpFXImJBOzxZFGv/IDt8MFw/NOyY1Kuob5BNfbOTpYgkdAJrErcy0aEyteiSWo4k/bvdEk/tPRGZFm3dDVIYeiEl9iowgyl5QcSL1jsNdpfLXpYp9W8oL15q6xb50yOUPGn/Z3CtWqtyYMW6u2TIfpCiO/G3PX1D/82LdvxPha/tZcCN0ewTe95bVclazIMyTTBk4YHNda0WWjlHXPsBnYrgj49/dgOltcaRblSOPp2wlnDarHMuwUu8khCepP9sf6camPhCuPen9jtGOxIR8LI82FcLOU8KkCPQOz2N1+zq8of6APcJMNSdobTYFZQISQ==

# RabbitMQ
rabbitmq_password: admin
rabbitmq_monitoring_password: admin
rabbitmq_cluster_cookie: admin

# HAProxy
haproxy_password: admin
keepalived_password: admin

# Redis
redis_master_password: admin

# Ceph
ceph_cluster_fsid: b5168ed4-a98f-4ff0-a39f-51f59a3d64d0
ceph_rgw_keystone_password: 3c4f1800-a518-4efc-b98d-339665bfa810
rbd_secret_uuid: 867a11a1-aa92-40d0-8910-32df2281193e
cinder_rbd_secret_uuid: cf2898a9-2fda-4ad3-94f7-f61fe06eb829

# Prometheus
prometheus_mysql_exporter_database_password: admin
prometheus_alertmanager_password: admin

# Grafana
grafana_database_password: admin
grafana_admin_password: admin
```

Enter password information used by OpenStack. Modify the /etc/kolla/passwords.yml file on the Deploy Node as shown in [Text 8]. Most passwords are set to **admin**.

```yaml {caption="[Text 9] Deploy Node - /etc/kolla/globals.yml", linenos=table}
# Kolla
openstack_release: "stein"

kolla_base_distro: "ubuntu"
kolla_install_type: "source"

kolla_internal_vip_address: "10.0.0.20"
kolla_external_vip_address: "192.168.0.40"

# Docker
docker_registry: "10.0.0.19:5000"
docker_namespace: "kolla"
docker_registry_insecure: "yes"
docker_registry_username: "admin"
docker_registry_password: "admin"

# Neutron
network_interface: "enp3s0"
kolla_external_vip_interface: "enp2s0"
neutron_external_interface : "enx88366cf9f9ed"
neutron_plugin_agent: "openvswitch"
neutron_ipam_driver: "internal"
octavia_network_interface: "enp2s0"

# Nova
nova_console: "novnc"

# OpenStack
enable_glance: "yes"
enable_haproxy: "yes"
enable_keystone: "yes"
enable_mariadb: "yes"
enable_memcached: "yes"

enable_ceph: "yes"
enable_ceph_mds: "no"
enable_ceph_rgw: "no"
enable_ceph_nfs: "no"
enable_ceph_dashboard: "yes"
enable_chrony: "yes"
enable_cinder: "yes"
enable_fluentd: "no"
enable_horizon: "yes"
enable_nova_fake: "no"
enable_nova_ssh: "yes"
enable_octavia: "yes"
enable_heat: "no"
enable_prometheus: "yes"
enable_grafana: "yes"

# Glance
glance_backend_ceph: "yes"

# Ceph
ceph_enable_cache: "no"

# Octavia
#octavia_loadbalancer_topology: "ACTIVE_STANDBY"
#octavia_amp_flavor_id: "100"
#octavia_amp_boot_network_list:
#octavia_amp_secgroup_list:
```

Configure Kolla-Ansible. Modify the /etc/kolla/globals.yml file on the Deploy Node as shown in [Text 9]. Since Octavia can only be configured after running OpenStack at least once, the Octavia settings are left commented out.

```shell
(Deploy)$ kolla-ansible -i ~/kolla-ansible/multinode bootstrap-servers
```

Install the required Ubuntu and Python packages on each node using Kolla Ansible bootstrap-servers.

## 7. Docker Configuration

### 7.1. Registry Node

```shell
(Registry)$ mkdir ~/auth
(Registry)$ docker run --entrypoint htpasswd registry:2 -Bbn admin admin > ~/auth/htpasswd
(Registry)$ docker run -d -p 5000:5000 --restart=always --name registry_private -v ~/auth:/auth -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" registry:2
```

Start the Docker Registry on the Registry Node. Set ID/Password to admin/admin.

### 7.2. All Node

```text {caption="[Text 10] All Node - /etc/systemd/system/docker.service.d/kolla.confs", linenos=table}
[Service]
MountFlags=shared
ExecStart=/usr/bin/dockerd --insecure-registry 10.0.0.19:5000 --log-opt max-file=5 --log-opt max-size=50m
```

```shell
(All)$ service docker restart
```

Register the Docker Registry running on the Registry Node as an insecure registry for all Docker daemons running on nodes. Create the /etc/systemd/system/docker.service.d/kolla.conf file on all nodes with the contents of [Text 10], then restart Docker.

## 8. Octavia Certificate Configuration

```shell
(Network)$ git clone -b 4.0.1 https://github.com/openstack/octavia.git
(Network)$ cd octavia
(Network)$ sed -i 's/foobar/admin/g' bin/create_certificates.sh
(Network)$ ./bin/create_certificates.sh cert $(pwd)/etc/certificates/openssl.cnf
(Network)$ mkdir -p /etc/kolla/config/octavia
(Network)$ cp cert/private/cakey.pem /etc/kolla/config/octavia/
(Network)$ cp cert/ca_01.pem /etc/kolla/config/octavia/
(Network)$ cp cert/client.pem /etc/kolla/config/octavia/
```

Generate certificates used by Octavia on the Network Node.

## 9. Ceph Configuration

```shell
(Ceph)$ parted /dev/nvme0n1 -s -- mklabel gpt mkpart KOLLA_CEPH_OSD_BOOTSTRAP_BS 1 -1
(Ceph)$ printf 'KERNEL=="nvme0n1p1", SYMLINK+="nvme0n11"\nKERNEL=="nvme0n1p2", SYMLINK+="nvme0n12"' > /etc/udev/rules.d/local.rules
```

Label the /dev/nvme0n1 block device on Ceph nodes with KOLLA_CEPH_OSD_BOOTSTRAP_BS. Kolla-Ansible is configured to use block devices labeled with KOLLA_CEPH_OSD_BOOTSTRAP_BS for OSDs. Due to a bug in Kolla-Ansible's role, when using NVME as Ceph storage, there is a bug that references incorrect partition names. To resolve this issue, create partition symbolic links via udev.

## 10. Kolla Container Image Creation and Push

```shell
(Deploy)$ cd ~
(Deploy)$ git clone -b 8.0.0 https://github.com/openstack/kolla.git
(Deploy)$ cd kolla
(Deploy)$ tox -e genconfig
(Deploy)$ docker login 10.0.0.19:5000
(Deploy)$ mkdir -p logs
(Deploy)$ python tools/build.py -b ubuntu --tag stein --skip-parents --skip-existing --type source --registry 10.0.0.19:5000 --push --logs-dir logs
```

Create Kolla container images and push them to the registry. Images are created based on Ubuntu images.

## 11. OpenStack Deployment Using Kolla-Ansible

```shell
(Deploy)$ kolla-ansible -i ~/kolla-ansible/multinode prechecks
(Deploy)$ kolla-ansible -i ~/kolla-ansible/multinode deploy
```

Deploy OpenStack to start OpenStack.

## 12. OpenStack Initialization

```shell
(Deploy)$ kolla-ansible post-deploy
(Deploy)$ . /etc/kolla/admin-openrc.sh
(Deploy)$ . /usr/local/share/kolla-ansible/init-runonce
```

Perform OpenStack initialization. After initialization is complete, services such as Network, Image, and Flavor are initialized.

```shell {caption="[Shell 1] Deploy Node - /etc/kolla/admin-openrc.sh"}
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=admin
export OS_AUTH_URL=http://10.0.0.20:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
```

After initialization is complete, you can check the /etc/kolla/admin-openrc.sh file with the contents of [Shell 1].

## 13. External Network and Octavia Network Creation

```shell
(Deploy)$ . /etc/kolla/admin-openrc.sh
(Deploy)$ openstack port list
(Deploy)$ openstack router remove port demo-router [Port ID]
(Deploy)$ openstack router delete demo-router
(Deploy)$ openstack network delete public1
(Deploy)$ openstack network delete demo-net
```

Delete all networks and routers created by the init-runonce script.

```shell
(Deploy)$ . /etc/kolla/admin-openrc.sh
(Deploy)$ openstack router create external-router
(Deploy)$ openstack network create --share --external --provider-physical-network physnet1 --provider-network-type flat external-net
(Deploy)$ openstack subnet create --network external-net --allocation-pool start=192.168.0.200,end=192.168.0.224 --dns-nameserver 8.8.8.8 --gateway 192.168.0.1 --subnet-range 192.168.0.0/24 external-sub
(Deploy)$ openstack router set --external-gateway external-net --enable-snat --fixed-ip subnet=external-sub,ip-address=192.168.0.225 external-router
```

Create External Router, External Network, and External Subnet, and connect the External Network to the External Router. Configure the External Router to perform SNAT.

```shell
(Deploy)$ openstack network create --share --provider-network-type vxlan octavia-net
(Deploy)$ openstack subnet create --network octavia-net --dns-nameserver 8.8.8.8 --gateway 20.0.0.1 --subnet-range 20.0.0.0/24 octavia-sub
(Deploy)$ openstack router add subnet external-router octavia-sub
```

Create Octavia Network and Octavia Subnet and connect them to the External Network.

```shell
(Controller)$ route add -net 20.0.0.0/24 gw 192.168.0.225
(Controller)$ printf '#!/bin/bash\nroute add -net 20.0.0.0/24 gw 192.168.0.225' > /etc/rc.local
(Controller)$ chmod +x /etc/rc.local
```

Add a routing rule on the Controller Node so that packets with Octavia Network IP as the destination IP are sent to the External Router when sending packets to the NAT network.

## 14. VM Image Registration in Glance

```shell
(Deploy)$ . /etc/kolla/admin-openrc.sh
(Deploy)$ cd ~/kolla-ansible
(Deploy)$ wget http://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img
(Deploy)$ guestmount -a bionic-server-cloudimg-amd64.img -m /dev/sda1 /mnt
(Deploy)$ chroot /mnt
(Deploy / chroot)$ passwd root
(Deploy / chroot)$ sed -i -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
(Deploy / chroot)$ sed -i -e 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
(Deploy / chroot)$ sync
(Deploy / chroot)$ exit
(Deploy)$ umount /mnt
(Deploy)$ openstack image create --disk-format qcow2 --container-format bare --public --file ./bionic-server-cloudimg-amd64.img ubuntu-18.04
```

After downloading the Ubuntu image, configure the root account and SSHD settings. Register the configured Ubuntu image in Glance.

```shell
(Deploy)$ . /etc/kolla/admin-openrc.sh
(Deploy)$ export OS_USERNAME=octavia
(Deploy)$ cd ~
(Deploy)$ git clone -b 4.0.1 https://github.com/openstack/octavia.git
(Deploy)$ cd octavia/diskimage-create
(Deploy)$ ./diskimage-create.sh -r root
(Deploy)$ openstack image create --disk-format qcow2 --container-format bare --public --tag amphora --file ./amphora-x64-haproxy.qcow2 ubuntu-16.04-amphora
```

Create the Octavia Amphora image as the octavia user and register it in Glance. The tag must be set to amphora.

## 15. Octavia Flavor, Keypair, Security Group Configuration and Octavia Deployment

```shell
(Deploy)$ . /etc/kolla/admin-openrc.sh
(Deploy)$ export OS_USERNAME=octavia
(Deploy)$ openstack flavor create --id 100 --vcpus 2 --ram 2048 --disk 10 "m1.amphora" --public
```

Create a flavor for the Octavia Amphora VM as the octavia user. Since the Flavor ID is planned to be set to 100, the Flavor ID must be created as 100.

```shell
(Deploy)$ . /etc/kolla/admin-openrc.sh
(Deploy)$ export OS_USERNAME=octavia
(Deploy)$ openstack keypair create -- octavia_ssh_key 
```

Create the octavia_ssh_key keypair as the octavia user. The keypair name must be created as octavia_ssh_key.

```shell
(Deploy)$ . /etc/kolla/admin-openrc.sh
(Deploy)$ export OS_USERNAME=octavia
(Deploy)$ openstack security group create octavia-sec
(Deploy)$ openstack security group rule create --protocol icmp octavia-sec
(Deploy)$ openstack security group rule create --protocol tcp --dst-port 22 octavia-sec
(Deploy)$ openstack security group rule create --protocol tcp --dst-port 9443 octavia-sec
```

Create the octavia-sec security group as the octavia user.

```yaml {caption="[Text 11] Deploy Node - /etc/kolla/globals.yml", linenos=table}
...
# Octavia
octavia_loadbalancer_topology: "ACTIVE_STANDBY"
octavia_amp_flavor_id: "100"
octavia_amp_boot_network_list: "[octavia-net Network ID]"
octavia_amp_secgroup_list: "[octavia-sec Security Group ID]"
```

Modify the /etc/kolla/globals.yml file as shown in [Text 11] to configure Octavia by removing the Octavia configuration comments. Enter the ID of the octavia-net network created above in octavia_amp_boot_network_list. Enter the ID of the octavia-sec security group created above in octavia_amp_secgroup_list.

```shell
(Deploy)$ kolla-ansible -i ~/kolla-ansible/multinode deploy -t octavia
```

Deploy only Octavia.

## 16. Initialization for Reinstallation

```shell
(Deploy)$ kolla-ansible -i ~/kolla-ansible/multinode destroy --yes-i-really-really-mean-it 
```

Delete all OpenStack containers.

```shell
(Ceph)$ parted /dev/nvme0n1 rm 1
(Ceph)$ parted /dev/nvme0n1 rm 2
(Ceph)$ reboot now
(Ceph)$ parted /dev/nvme0n1 -s -- mklabel gpt mkpart KOLLA_CEPH_OSD_BOOTSTRAP_BS 1 -1
```

Initialize OSD blocks on all Ceph nodes.

## 17. Dashboard Information

Accessible dashboard information is as follows. Listed in order of URL, ID, Password.

* Horizon : http://10.0.0.20:80, admin, admin
* RabbitMQ : http://10.0.0.20:15672, openstack, admin
* Prometheus : http://10.0.0.20:9091
* Grafana : http://10.0.0.20:3000, admin, admin
* Alertmanager : http://10.0.0.20:9093, admin, admin

## 18. Debugging

```shell
(Node01)$ ls /var/log/kolla
ansible.log  ceph  chrony  cinder  glance  horizon  keystone  mariadb  neutron  nova  octavia  openvswitch  prometheus  rabbitmq
```

Logs for OpenStack services are stored in the **/var/log/kolla** directory on each node.

## 19. References

* [https://docs.openstack.org/kolla/stein/](https://docs.openstack.org/kolla/stein/)
* [https://docs.openstack.org/kolla-ansible/stein/](https://docs.openstack.org/kolla-ansible/stein)
* [https://shreddedbacon.com/post/openstack-kolla/](https://shreddedbacon.com/post/openstack-kolla/)
* [https://docs.oracle.com/cd/E90981_01/E90982/html/kolla-openstack-network.html](https://docs.oracle.com/cd/E90981_01/E90982/html/kolla-openstack-network.html)
* [https://github.com/osrg/openvswitch/blob/master/debian/openvswitch-switch.README.Debian](https://github.com/osrg/openvswitch/blob/master/debian/openvswitch-switch.README.Debian)
* [https://blog.zufardhiyaulhaq.com/manual-instalation-octavia-openstack-queens/](https://blog.zufardhiyaulhaq.com/manual-instalation-octavia-openstack-queens/)
* [http://www.panticz.de/openstack-octavia-loadbalancer](http://www.panticz.de/openstack-octavia-loadbalancer)

