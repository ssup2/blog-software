---
title: OpenStack Terraform Practice / Kubernetes Environment Setup
---

## 1. Practice and Setup Environment

{{< figure caption="[Figure 1] OpenStack Terraform Practice and Setup Environment" src="images/environment.png" width="900px" >}}

[Figure 1] shows the Kubernetes environment to be built on OpenStack using Terraform. This was performed in an environment where External Network, external-router, and Ubuntu 18.04 Image were pre-created.

* Terraform: 0.12.5
* Node: Ubuntu 18.04
* OpenStack: Stein
  * User, Tenant, Password: admin
  * Auth URL: 
* Network:
  * Internal Network: Kubernetes Network, 30.0.0.0/24
* Flavor:
  * Standard: 4 vCPU, 4GB RAM, 30GB Disk

## 2. Terraform Installation

```shell
(Deploy)$ apt-get update
(Deploy)$ apt-get install wget unzip
(Deploy)$ wget https://releases.hashicorp.com/terraform/0.12.5/terraform-0.12.5-linux-amd64.zip
(Deploy)$ unzip ./terraform-0.12.5-linux-amd64.zip -d /usr/local/bin/
```

Install Terraform.

## 3. Terraform Configuration

```tf linenos {caption="[File 1] ~/terraform/provider.tf", linenos=table}
provider "openstack" {
  user-name = "admin"
  tenant-name = "admin"
  password  = "admin"
  auth-url  = "http://192.168.0.40:5000/v3"
}
```

```tf linenos {caption="[File 2] ~/terraform/00-params.tf", linenos=table}
variable "router-external" {
  default = "[external-router ID]"
}

variable "secgroup-default" {
  default = "[default Security Group ID]"
}

variable "image-ubuntu" {
  default = "[ubuntu-18.04 Image ID]"
}
```

```tf linenos {caption="[File 3] ~/terraform/010-flavor.tf", linenos=table}
resource "openstack-compute-flavor-v2" "flavor" {
  name  = "m1.standard"
  ram   = "4096"
  vcpus = "4"
  disk  = "30"
}
```

```tf linenos {caption="[File 4] ~/terraform/020-network.tf", linenos=table}
resource "openstack-networking-network-v2" "network" {
  name = "internal-net"
}

resource "openstack-networking-subnet-v2" "subnet" {
  name = "internal-sub"
  network-id = "${openstack-networking-network-v2.network.id}"
  cidr = "30.0.0.0/24"
  dns-nameservers = ["8.8.8.8"]
}

resource "openstack-networking-router-interface-v2" "interface" {
  router-id = "${var.router-external}"
  subnet-id = "${openstack-networking-subnet-v2.subnet.id}"
}
```

```tf linenos {caption="[File 5] ~/terraform/030-secgroup.tf", linenos=table}
resource "openstack-networking-secgroup-rule-v2" "secgroup-tcp" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port-range-min = 1
  port-range-max = 65535
  remote-ip-prefix = "0.0.0.0/0"
  security-group-id = "${var.secgroup-default}"
}

resource "openstack-networking-secgroup-rule-v2" "secgroup-udp" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "upd"
  port-range-min = 1
  port-range-max = 65535
  remote-ip-prefix = "0.0.0.0/0"
  security-group-id = "${var.secgroup-default}"
}
```

```tf linenos {caption="[File 6] ~/terraform/040-floating.tf", linenos=table}
resource "openstack-networking-floatingip-v2" "fip" {
  pool = "external-net"
}
```

```tf linenos {caption="[File 7] ~/terraform/050-instance.tf", linenos=table}
resource "openstack-compute-instance-v2" "vm01" {
  depends-on = ["openstack-networking-subnet-v2.subnet"]
  name = "vm01"
  flavor-id = "${openstack-compute-flavor-v2.flavor.id}"

  network {
    name = "${openstack-networking-network-v2.network.name}"
  }

  block-device {
    uuid                  = "${var.image-ubuntu}"
    source-type           = "image"
    volume-size           = 30
    boot-index            = 0
    destination-type      = "volume"
    delete-on-termination = true
  }
}

resource "openstack-compute-instance-v2" "vm02" {
  depends-on = ["openstack-networking-subnet-v2.subnet"]
  name = "vm02"
  flavor-id = "${openstack-compute-flavor-v2.flavor.id}"

  network {
    name = "${openstack-networking-network-v2.network.name}"
  }

  block-device {
    uuid                  = "${var.image-ubuntu}"
    source-type           = "image"
    volume-size           = 30
    boot-index            = 0
    destination-type      = "volume"
    delete-on-termination = true
  }
}

resource "openstack-compute-instance-v2" "vm03" {
  depends-on = ["openstack-networking-subnet-v2.subnet"]
  name = "vm03"
  flavor-id = "${openstack-compute-flavor-v2.flavor.id}"

  network {
    name = "${openstack-networking-network-v2.network.name}"
  }

  block-device {
    uuid                  = "${var.image-ubuntu}"
    source-type           = "image"
    volume-size           = 30
    boot-index            = 0
    destination-type      = "volume"
    delete-on-termination = true
  }
}

resource "openstack-compute-instance-v2" "vm09" {
  depends-on = ["openstack-networking-subnet-v2.subnet"]
  name = "vm09"
  flavor-id = "${openstack-compute-flavor-v2.flavor.id}"

  network {
    name = "${openstack-networking-network-v2.network.name}"
  }

  block-device {
    uuid                  = "${var.image-ubuntu}"
    source-type           = "image"
    volume-size           = 30
    boot-index            = 0
    destination-type      = "volume"
    delete-on-termination = true
  }
}

resource "openstack-compute-floatingip-associate-v2" "fip" {
  floating-ip = "${openstack-networking-floatingip-v2.fip.address}"
  instance-id = "${openstack-compute-instance-v2.vm09.id}"
}
```

Create [File 1 ~ 7]. [File 1,2] must be changed according to the OpenStack environment.

## 4. Terraform Apply and Initialize

```shell
(Deploy)$ cd ~/terraform
(Deploy)$ terraform init
(Deploy)$ terraform apply
```

Apply Terraform.

```shell
(Deploy)$ cd ~/terraform
(Deploy)$ terraform destroy
```

Initialize Terraform.

## 5. References

* [https://github.com/diodonfrost/terraform-openstack-examples](https://github.com/diodonfrost/terraform-openstack-examples)
* [https://github.com/ssup2/example-openstack-terraform-k8s](https://github.com/ssup2/example-openstack-terraform-k8s)

