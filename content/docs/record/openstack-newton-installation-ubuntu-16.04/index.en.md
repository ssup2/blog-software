---
title: OpenStack Newton Installation / Ubuntu 16.04 Environment
---

## 1. Installation Environment

The installation environment is as follows:

* VirtualBox 5.0.14r
  * Controller Node : Ubuntu Server 16.04.2 64bit x1
  * Compute Node : Ubuntu Server 16.04.2 64bit x1
  * Block Storage Node : Ubuntu Server 16.04.2 64bit x1
* OpenStack Newton Version
  * Network : Self-service
* Password
  * All passwords required for OpenStack installation are unified to **root** for simplified installation.
* Installation is performed as root user on all nodes.

## 2. Node Configuration

{{< figure caption="[Figure 1] Node Configuration Diagram for OpenStack Newton Installation" src="images/node-setting.png" width="1000px" >}}

Create virtual Controller, Compute, and Storage Nodes (VMs) using VirtualBox as shown in [Figure 1].
* NAT : Build a 10.0.0/24 network using VirtualBox's "NAT network".
* Router : Build a 192.168.77.0/24 network using a router. (NAT)
* After Horizon installation, access http://192.168.77.170/horizon from a PC web browser to use Horizon.

### 2.1. All Nodes

#### 2.1.1. Network Configuration

```text {caption="[Text 1] All Node - /etc/hosts", linenos=table}
# controller
10.0.0.11       controller

# compute1
10.0.0.31       compute1

# block1
10.0.0.41       block1
```

Create the /etc/hosts file with the contents of [Text 1].

#### 2.1.1. OpenStack Package Installation

```shell
(All)$ apt install software-properties-common
(All)$ add-apt-repository cloud-archive:newton
```

Add the OpenStack package repository.

```shell
(All)$ apt update && apt dist-upgrade
(All)$ apt install python-openstackclient
```

Install OpenStack packages.

### 2.2. Controller Node

#### 2.2.1. Network Configuration

```text {caption="[Text 2] Controller Node - /etc/network/interfaces", linenos=table}
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto enp0s3
iface enp0s3 inet static
address 10.0.0.11
netmask 255.255.255.0
gateway 10.0.0.1
dns-nameservers 8.8.8.8

auto enp0s8
iface enp0s8 inet static
address 192.168.77.170
netmask 255.255.255.0
gateway 192.168.77.1
dns-nameservers 8.8.8.8
```

Modify /etc/network/interfaces as shown in [Text 2].

#### 2.2.2. NTP (Network Time Protocol) Configuration

```shell
(Controller)$ apt install chrony
```

Install the chrony package.

```text {caption="[Text 3] Controller Node - /etc/chrony/chrony.conf", linenos=table}
...
server 0.asia.pool.ntp.org
server 1.asia.pool.ntp.org
server 2.asia.pool.ntp.org
server 3.asia.pool.ntp.org

allow 10.0.0.0/24
```

Add the contents of [Text 3] to /etc/chrony/chrony.conf.

```shell
(Controller)$ service chrony restart
```

Restart chrony.

#### 2.2.3. SQL Database Installation

```shell
(Controller)$ apt install mariadb-server python-pymysql
```

Install the MariaDB package.

```text {caption="[Text 4] Controller Node - /etc/mysql/mariadb.conf.d/99-openstack.cnf", linenos=table}
...
[mysqld]
bind-address = 10.0.0.11

default-storage-engine = innodb
innodb_file_per_table
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
```

Create /etc/mysql/mariadb.conf.d/99-openstack.cnf and modify it as shown in [Text 4].

```shell
(Controller)$ service mysql restart
```

Restart MariaDB.

#### 2.2.4. Message Queue Installation

```shell
(Controller)$ apt install rabbitmq-server
```

Install the RabbitMQ package.

```shell
(Controller)$ rabbitmqctl add_user openstack root
(Controller)$ rabbitmqctl set_permissions openstack ".\*" ".\*" ".\*"
```

Configure RabbitMQ.

#### 2.2.5. Memcached Installation

```shell
(Controller)$ apt install memcached python-memcache
```

Install the Memcached package.

```text {caption="[Text 5] Controller Node - /etc/memcached.conf", linenos=table}
...
-l 10.0.0.11
```

Add the contents of [Text 5] to /etc/memcached.conf.

#### 2.2.6. Environment Variable File Creation

```text {caption="[Text 6] Controller Node - /root/admin-openrc", linenos=table}
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=root
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
```

Create /root/admin-openrc and modify it as shown in [Text 6].

```text {caption="[Text 7] Controller Node - /root/demo-openrc", linenos=table}
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=root
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
```

Create /root/demo-openrc and modify it as shown in [Text 7].

### 2.3. Compute Node

#### 2.3.1. Network Configuration

```text {caption="[Text 8] Compute Node - /etc/network/interfaces", linenos=table}
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto enp0s3
iface enp0s3 inet static
address 10.0.0.31
netmask 255.255.255.0
gateway 10.0.0.1
dns-nameservers 8.8.8.8

auto enp0s8
iface enp0s8 inet static
address 192.168.77.180
netmask 255.255.255.0
gateway 192.168.77.1
dns-nameservers 8.8.8.8
```

Modify /etc/network/interfaces as shown in [Text 8].

#### 2.3.2. NTP (Network Time Protocol) Configuration

```shell
(Compute)$ apt install chrony
```

Install the chrony package.

```text {caption="[Text 9] Compute Node - /etc/chrony/chrony.conf", linenos=table}
...
server controller iburst
```

Add the contents of [Text 9] to /etc/chrony/chrony.conf.

```shell
(Compute)$ service chrony restart
```

Restart chrony.

### 2.4. Storage Node

#### 2.4.1, Network Configuration

```text {caption="[Text 10] Storage Node - /etc/network/interfaces", linenos=table}
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto enp0s3
iface enp0s3 inet static
address 10.0.0.41
netmask 255.255.255.0
gateway 10.0.0.1
dns-nameservers 8.8.8.8
```

Modify /etc/network/interfaces as shown in [Text 10].

#### 2.4.2. NTP (Network Time Protocol) Configuration

```shell
(Storage)$ apt install chrony
```

Install the chrony package.

```text {caption="[Text 11] Storage Node - /etc/chrony/chrony.conf", linenos=table}
...
server controller iburst
```

Add the contents of [Text 11] to /etc/chrony/chrony.conf.

```shell
(Storage)$ service chrony restart
```

Restart chrony.

## 3. Keystone Installation

### 3.1. Controller Node

```shell
(Controller)$ mysql -u root -p
mysql> CREATE DATABASE keystone;
mysql> GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'root';
mysql> GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'root';
mysql> exit;
```

Initialize the Keystone database.

```shell
(Controller)$ apt install keystone
```

Install the Keystone package.

```text {caption="[Text 12] Controller Node - /etc/keystone/keystone.conf", linenos=table}
...
[database]
connection = mysql+pymysql://keystone:root@controller/keystone

[token]
provider = fernet
```

Add the contents of [Text 12] to /etc/keystone/keystone.conf.

```shell
(Controller)$ su -s /bin/sh -c "keystone-manage db_sync" keystone
(Controller)$ keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
(Controller)$ keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
(Controller)$ keystone-manage bootstrap --bootstrap-password root --bootstrap-admin-url http://controller:35357/v3/ --bootstrap-internal-url http://controller:35357/v3/ --bootstrap-public-url http://controller:5000/v3/ --bootstrap-region-id RegionOne
```

Configure Keystone.

```text {caption="[Text 13] Controller Node - /etc/apache2/apache2.conf", linenos=table}
...
ServerName controller
```

Add the contents of [Text 13] to /etc/apache2/apache2.conf.

```shell
(Controller)$ service apache2 restart
(Controller)$ rm -f /var/lib/keystone/keystone.db
```

Restart the Apache HTTP Server and remove the database.

```shell
(Controller)$ export OS_USERNAME=admin
(Controller)$ export OS_PASSWORD=root
(Controller)$ export OS_PROJECT_NAME=admin
(Controller)$ export OS_USER_DOMAIN_NAME=Default
(Controller)$ export OS_PROJECT_DOMAIN_NAME=Default
(Controller)$ export OS_AUTH_URL=http://controller:35357/v3
(Controller)$ export OS_IDENTITY_API_VERSION=3
```

Set environment variables.

```shell
(Controller)$ openstack project create --domain default --description "Service Project" service
(Controller)$ openstack project create --domain default --description "Demo Project" demo
(Controller)$ openstack user create --domain default --password-prompt demo
(Controller)$ openstack role create user
(Controller)$ openstack role add --project demo --user demo user
```

Create and configure Projects, Users, and Roles.

### 3.2. Verification

```shell
# openstack --os-auth-url http://controller:35357/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name admin --os-username admin token issue
+------------+-----------------------------------------------------------------+
| Field      | Value                                                           |
+------------+-----------------------------------------------------------------+
| expires    | 2016-02-12T20:14:07.056119Z                                     |
| id         | gAAAAABWvi7_B8kKQD9wdXac8MoZiQldmjEO643d-e_j-XXq9AmIegIbA7UHGPv |
|            | atnN21qtOMjCFWX7BReJEQnVOAj3nclRQgAYRsfSU_MrsuWb4EDtnjU7HEpoBb4 |
|            | o6ozsA_NmFWEpLeKy0uNn_WeKbAhYygrsmQGA49dclHVnz-OMVLiyM9ws       |
| project_id | 343d245e850143a096806dfaefa9afdc                                |
| user_id    | ac3377633149401296f6c0d92d79dc16                                |
+------------+-----------------------------------------------------------------+
```

```shell
# openstack --os-auth-url http://controller:5000/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name demo --os-username demo token issue
+------------+-----------------------------------------------------------------+
| Field      | Value                                                           |
+------------+-----------------------------------------------------------------+
| expires    | 2016-02-12T20:15:39.014479Z                                     |
| id         | gAAAAABWvi9bsh7vkiby5BpCCnc-JkbGhm9wH3fabS_cY7uabOubesi-Me6IGWW |
|            | yQqNegDDZ5jw7grI26vvgy1J5nCVwZ_zFRqPiz_qhbq29mgbQLglbkq6FQvzBRQ |
|            | JcOzq3uwhzNxszJWmzGC7rJE_H0A_a3UFhqv8M4zMRYSbS2YF0MyFmp_U       |
| project_id | ed0b60bf607743088218b0a533d5943f                                |
| user_id    | 58126687cbcc4888bfa9ab73a2256f27                                |
+------------+-----------------------------------------------------------------+
```

Verify Keystone operation on the Controller Node.

## 4. Glance Installation

### 4.1. Controller Node

```shell
(Controller)$ mysql -u root -p
mysql> CREATE DATABASE glance;
mysql> GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'root';
mysql> GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'root';
mysql> exit;
```

Initialize the Glance database.

```shell
(Controller)$ . /root/admin-openrc
(Controller)$ openstack user create --domain default --password-prompt glance
(Controller)$ openstack role add --project service --user glance admin
(Controller)$ openstack service create --name glance --description "OpenStack Image" image
```

Create and configure the Glance user.

```shell
(Controller)$ openstack endpoint create --region RegionOne image public http://controller:9292
(Controller)$ openstack endpoint create --region RegionOne image internal http://controller:9292
(Controller)$ openstack endpoint create --region RegionOne image admin http://controller:9292
```

Create Glance service API endpoints.

```shell
(Controller)$ apt install glance
```

Install the Glance package.

```text {caption="[Text 14] Controller Node - /etc/glance/glance-api.conf", linenos=table}
...
[database]
connection = mysql+pymysql://glance:root@controller/glance

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = root

[paste_deploy]
flavor = keystone

[glance_store]
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images/
```

Add the contents of [Text 14] to /etc/glance/glance-api.conf.

```text {caption="[Text 15] Controller Node - /etc/glance/glance-api.conf", linenos=table}
...
[database]
connection = mysql+pymysql://glance:root@controller/glance

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = root

[paste_deploy]
flavor = keystone
```

Add the contents of [Text 15] to /etc/glance/glance-registry.conf.

```shell
(Controller)$ su -s /bin/sh -c "glance-manage db_sync" glance
(Controller)$ service glance-registry restart
(Controller)$ service glance-api restart
```

Configure and start Glance.

### 4.2. Verification

```shell
(Controller)$ . /root/admin-openrc
(Controller)$ wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
(Controller)$ openstack image create "cirros" --file cirros-0.3.4-x86_64-disk.img --disk-format qcow2 --container-format bare --public
(Controller)$ openstack image list
+--------------------------------------+--------+--------+
| ID                                   | Name   | Status |
+--------------------------------------+--------+--------+
| 38047887-61a7-41ea-9b49-27987d5e8bb9 | cirros | active |
+--------------------------------------+--------+--------+
```

Verify Glance operation on the Controller Node.

## 5. Nova Installation

### 5.1. Controller Node

```shell
(Controller)$ mysql -u root -p
mysql> CREATE DATABASE nova_api;
mysql> CREATE DATABASE nova;
mysql> GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'root';
mysql> GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'root';
mysql> GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'root';
mysql> GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'root';
mysql> exit;
```

Initialize the Nova database.

```shell
(Controller)$ . /root/admin-openrc
(Controller)$ openstack user create --domain default --password-prompt nova
(Controller)$ openstack role add --project service --user nova admin
(Controller)$ openstack service create --name nova --description "OpenStack Compute" compute
```

Create and configure the Nova user.

```shell
(Controller)$ openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1/%\(tenant_id\)s
(Controller)$ openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1/%\(tenant_id\)s
(Controller)$ openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1/%\(tenant_id\)s
```

Create Nova service API endpoints.

```shell
(Controller)$ apt install nova-api nova-conductor nova-consoleauth nova-novncproxy nova-scheduler
(Controller)$ mkdir /usr/lib/python2.7/dist-packages/keys
```

Install the Nova package.

```text {caption="[Text 16] Controller Node - /etc/nova/nova.conf", linenos=table}
...
[DEFAULT]
transport_url = rabbit://openstack:root@controller
auth_strategy = keystone
my_ip = 10.0.0.11
use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver

[api_database]
connection = mysql+pymysql://nova:root@controller/nova_api

[database]
connection = mysql+pymysql://nova:root@controller/nova

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = root

[vnc]
vncserver_listen = $my_ip
vncserver_proxyclient_address = $my_ip

[glance]
api_servers = http://controller:9292

[oslo_concurrency]
lock_path = /var/lib/nova/tmp
```

Add the contents of [Text 16] to /etc/nova/nova.conf.

```shell
(Controller)$ su -s /bin/sh -c "nova-manage api_db sync" nova
(Controller)$ su -s /bin/sh -c "nova-manage db sync" nova
(Controller)$ service nova-api restart
(Controller)$ service nova-consoleauth restart
(Controller)$ service nova-scheduler restart
(Controller)$ service nova-conductor restart
(Controller)$ service nova-novncproxy restart
```

Configure and start Nova.

### 5.2. Compute Node

```shell
(Compute)$ apt install nova-compute
```

Install the Nova package.

```text {caption="[Text 17] Compute Node - /etc/nova/nova.conf", linenos=table}
...
[DEFAULT]
transport_url = rabbit://openstack:root@controller
instances_path = /var/lib/nova/instances
auth_strategy = keystone
my_ip = 10.0.0.31
use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = root

[vnc]
enabled = True
vncserver_listen = 0.0.0.0
vncserver_proxyclient_address = $my_ip
novncproxy_base_url = http://controller:6080/vnc_auto.html

[glance]
api_servers = http://controller:9292

[oslo_concurrency]
lock_path = /var/lib/nova/tmp
```

Add the contents of [Text 17] to /etc/nova/nova.conf.

```text {caption="[Text 18] Compute Node - /etc/nova/nova-compute.conf", linenos=table}
...
[DEFAULT]
compute_driver=libvirt.LibvirtDriver
[libvirt]
virt_type=qemu
```

Since the current VirtualBox VM cannot use CPU virtualization extensions like Intel VT-X, the Compute Node cannot use KVM+QEMU combination for virtual machines and must use QEMU only. Modify /etc/nova/nova-compute.conf as shown in [Text 18].

```shell
(Compute)$ service nova-compute restart
```

Start Nova.

### 5.3. Verification

```shell
(Contorller)$ . /root/admin-openrc
(Contorller)$ openstack compute service list
+----+--------------------+------------+----------+---------+-------+----------------------------+
| Id | Binary             | Host       | Zone     | Status  | State | Updated At                 |
+----+--------------------+------------+----------+---------+-------+----------------------------+
|  1 | nova-consoleauth   | controller | internal | enabled | up    | 2016-02-09T23:11:15.000000 |
|  2 | nova-scheduler     | controller | internal | enabled | up    | 2016-02-09T23:11:15.000000 |
|  3 | nova-conductor     | controller | internal | enabled | up    | 2016-02-09T23:11:16.000000 |
|  4 | nova-compute       | compute1   | nova     | enabled | up    | 2016-02-09T23:11:20.000000 |
+----+--------------------+------------+----------+---------+-------+----------------------------+
```

Verify Nova operation on the Controller Node.

## 6. Neutron Installation

### 6.1. Controller Node

```shell
(Contorller)$ mysql -u root -p
mysql> CREATE DATABASE neutron;
mysql> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'root';
mysql> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'root';
mysql> exit;
```

Initialize the Neutron database.

```shell
(Contorller)$ . /root/admin-openrc
(Contorller)$ openstack user create --domain default --password-prompt neutron
(Contorller)$ openstack role add --project service --user neutron admin
(Contorller)$ openstack service create --name neutron --description "OpenStack Networking" network
```

Create and configure the Neutron user.

```shell
(Contorller)$ openstack endpoint create --region RegionOne network public http://controller:9696
(Contorller)$ openstack endpoint create --region RegionOne network internal http://controller:9696
(Contorller)$ openstack endpoint create --region RegionOne network admin http://controller:9696
```

Create Neutron service API endpoints.

```shell
(Contorller)$ apt install neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent
```

Install the Neutron package.

```text {caption="[Text 19] Controller Node - /etc/neutron/neutron.conf", linenos=table}
...
[DEFAULT]
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True
transport_url = rabbit://openstack:root@controller
auth_strategy = keystone
notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True

[database]
connection = mysql+pymysql://neutron:root@controller/neutron

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = neutron
password = root

[nova]
auth_url = http://controller:35357
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionOne
project_name = service
username = nova
password = root
```

Add the contents of [Text 19] to /etc/neutron/neutron.conf.

```text {caption="[Text 20] Controller Node - /etc/neutron/plugins/ml2/ml2_conf.ini", linenos=table}
...
[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security

[ml2_type_flat]
flat_networks = provider

[ml2_type_vxlan]
vni_ranges = 1:1000

[securitygroup]
enable_ipset = True
```

Add the contents of [Text 20] to /etc/neutron/plugins/ml2/ml2_conf.ini.

```text {caption="[Text 21] Controller Node - /etc/neutron/plugins/ml2/linuxbridge_agent.ini", linenos=table}
...
[linux_bridge]
physical_interface_mappings = provider:enp0s8

[vxlan]
enable_vxlan = True
local_ip = 10.0.0.11
l2_population = True

[securitygroup]
enable_security_group = True
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
```

Add the contents of [Text 21] to /etc/neutron/plugins/ml2/linuxbridge_agent.ini.

```text {caption="[Text 22] Controller Node - /etc/neutron/l3_agent.ini", linenos=table}
...
[DEFAULT]
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
```

Add the contents of [Text 22] to /etc/neutron/l3_agent.ini.

```text {caption="[Text 23] Controller Node - /etc/neutron/dhcp_agent.ini", linenos=table}
...
[DEFAULT]
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = True
```

Add the contents of [Text 23] to /etc/neutron/dhcp_agent.ini.

```text {caption="[Text 24] Controller Node - /etc/neutron/metadata_agent.ini", linenos=table}
...
[DEFAULT]
nova_metadata_ip = controller
metadata_proxy_shared_secret = root
```

Add the contents of [Text 24] to /etc/neutron/metadata_agent.ini.

```text {caption="[Text 25] Controller Node - /etc/nova/nova.conf", linenos=table}
...
[neutron]
url = http://controller:9696
auth_url = http://controller:35357
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionOne
project_name = service
username = neutron
password = root
service_metadata_proxy = True
metadata_proxy_shared_secret = root
```

Add the contents of [Text 25] to /etc/nova/nova.conf.

```shell
(Contorller)$ su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
(Contorller)$ service nova-api restart
(Contorller)$ service neutron-server restart
(Contorller)$ service neutron-linuxbridge-agent restart
(Contorller)$ service neutron-dhcp-agent restart
(Contorller)$ service neutron-metadata-agent restart
(Contorller)$ service neutron-l3-agent restart
```

Start Neutron.

### 6.2. Compute Node

```shell
(Compute)$ apt install neutron-linuxbridge-agent
```

Install the Neutron package.

```text {caption="[Text 26] Compute Node - /etc/neutron/neutron.conf", linenos=table}
...
[DEFAULT]
transport_url = rabbit://openstack:root@controller
auth_strategy = keystone

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = neutron
password = root
```

Add the contents of [Text 26] to /etc/neutron/neutron.conf.

```text {caption="[Text 27] Compute Node - /etc/neutron/plugins/ml2/linuxbridge_agent.ini", linenos=table}
...
[linux_bridge]
physical_interface_mappings = provider:enp0s8

[vxlan]
enable_vxlan = True
local_ip = 10.0.0.31
l2_population = True

[securitygroup]
enable_security_group = True
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
```

Add the contents of [Text 27] to /etc/neutron/plugins/ml2/linuxbridge_agent.ini.

```text {caption="[Text 28] Compute Node - /etc/nova/nova.conf", linenos=table}
...
[neutron]
url = http://controller:9696
auth_url = http://controller:35357
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionOne
project_name = service
username = neutron
password = root
```

Add the contents of [Text 28] to /etc/nova/nova.conf.

```shell
(Compute)$ service nova-compute restart
(Compute)$ service neutron-linuxbridge-agent restart
```

Start Neutron.

### 6.3. Verification

```shell
(Compute)$ . /root/admin-openrc
(Compute)$ neutron ext-list
+---------------------------+-----------------------------------------------+
| alias                     | name                                          |
+---------------------------+-----------------------------------------------+
| default-subnetpools       | Default Subnetpools                           |
| network-ip-availability   | Network IP Availability                       |
| network_availability_zone | Network Availability Zone                     |
| auto-allocated-topology   | Auto Allocated Topology Services              |
| ext-gw-mode               | Neutron L3 Configurable external gateway mode |
| binding                   | Port Binding                                  |
| agent                     | agent                                         |
| subnet_allocation         | Subnet Allocation                             |
| l3_agent_scheduler        | L3 Agent Scheduler                            |
| tag                       | Tag support                                   |
| external-net              | Neutron external network                      |
| net-mtu                   | Network MTU                                   |
| availability_zone         | Availability Zone                             |
| quotas                    | Quota management support                      |
| l3-ha                     | HA Router extension                           |
| flavors                   | Neutron Service Flavors                       |
| provider                  | Provider Network                              |
| multi-provider            | Multi Provider Network                        |
| address-scope             | Address scope                                 |
| extraroute                | Neutron Extra Route                           |
| timestamp_core            | Time Stamp Fields addition for core resources |
| router                    | Neutron L3 Router                             |
| extra_dhcp_opt            | Neutron Extra DHCP opts                       |
| dns-integration           | DNS Integration                               |
| security-group            | security-group                                |
| dhcp_agent_scheduler      | DHCP Agent Scheduler                          |
| router_availability_zone  | Router Availability Zone                      |
| rbac-policies             | RBAC Policies                                 |
| standard-attr-description | standard-attr-description                     |
| port-security             | Port Security                                 |
| allowed-address-pairs     | Allowed Address Pairs                         |
| dvr                       | Distributed Virtual Router                    |
+---------------------------+-----------------------------------------------+
```

Verify Neutron operation on the Compute Node.

## 7. Horizon Installation

### 7.1. Controller Node

```shell
(Controller)$ apt install openstack-dashboard
```

Install the Horizon package.

```python {caption="[Code 1] Controller Node - /etc/openstack-dashboard/local_settings.py" , linenos=table}
...
OPENSTACK_HOST = "controller"
OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"
...
ALLOWED_HOSTS = ['*', ]
...
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'

CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': 'controller:11211',
    }
}
...
TIME_ZONE = "Asia/Seoul"
...
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True
OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "default"
OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 2,
}
```

Modify /etc/openstack-dashboard/local_settings.py as shown in [Code 1].

```shell
(Controller)$ service apache2 reload
```

Start Horizon.

### 7.2. Verification

Access Horizon through a web browser.
* http://192.168.77.170/horizon
* Login : Domain - default, Username - admin, Password - root

## 8. Cinder Installation

### 8.1. Compute Node

```text {caption="[Text 29] Compute Node - /etc/nova.nova.conf", linenos=table}
...
[cinder]
os_region_name = RegionOne
```

Add the contents of [Text 29] to /etc/nova.nova.conf.

### 8.2. Controller Node

```shell
(Controller)$ mysql -u root -p
mysql> CREATE DATABASE cinder;
mysql> GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'root';
mysql> GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'root';
> exit;
```

Initialize the Cinder database.

```shell
(Controller)$ . admin-openrc
(Controller)$ openstack user create --domain default --password-prompt cinder
(Controller)$ openstack role add --project service --user cinder admin
(Controller)$ openstack service create --name cinder --description "OpenStack Block Storage" volume
(Controller)$ openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
```

Create and configure the Cinder user.

```shell
(Controller)$ openstack endpoint create --region RegionOne volume public http://controller:8776/v1/%\(tenant_id\)s
(Controller)$ openstack endpoint create --region RegionOne volume internal http://controller:8776/v1/%\(tenant_id\)s
(Controller)$ openstack endpoint create --region RegionOne volume admin http://controller:8776/v1/%\(tenant_id\)s
(Controller)$ openstack endpoint create --region RegionOne volumev2 public http://controller:8776/v2/%\(tenant_id\)s
(Controller)$ openstack endpoint create --region RegionOne volumev2 internal http://controller:8776/v2/%\(tenant_id\)s
(Controller)$ openstack endpoint create --region RegionOne volumev2 admin http://controller:8776/v2/%\(tenant_id\)s
```

Create Cinder service API endpoints.

```shell
(Controller)$ su -s /bin/sh -c "cinder-manage db sync" cinder
(Controller)$ apt install cinder-api cinder-scheduler
```

Install the Cinder package.

```text {caption="[Text 30] Controller Node - /etc/cinder/cinder.conf", linenos=table}
...
[DEFAULT]
transport_url = rabbit://openstack:root@controller
auth_strategy = keystone
my_ip = 10.0.0.11

[database]
connection = mysql+pymysql://cinder:root@controller/cinder

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = cinder
password = root

[oslo_concurrency]
lock_path = /var/lib/cinder/tmp
```

Add the contents of [Text 30] to /etc/cinder/cinder.conf.

```shell
(Controller)$ service nova-api restart
(Controller)$ service cinder-scheduler restart
(Controller)$ service cinder-api restart
```

Start Cinder.

### 8.3. Storage Node

```shell
(Storage)$ apt install lvm2
(Storage)$ pvcreate /dev/sdb
(Storage)$ vgcreate cinder-volumes /dev/sdb
```

Install and configure LVM.

```text {caption="[Text 31] Storage Node - /etc/lvm/lvm.conf", linenos=table}
...
devices {
...
filter = [ "a/sdb/", "r/.*/"]
}
```

Add the contents of [Text 31] to /etc/lvm/lvm.conf.

```shell
(Storage)$ apt install cinder-volume
```

Install the Cinder package.

```text {caption="[Text 32] Storage Node - /etc/cinder/cinder.conf", linenos=table}
...
[DEFAULT]
transport_url = rabbit://openstack:root@controller
auth_strategy = keystone
my_ip = 10.0.0.41
enabled_backends = lvm
glance_api_servers = http://controller:9292

[database]
connection = mysql+pymysql://cinder:root@controller/cinder

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = cinder
password = root

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm

[oslo_concurrency]
lock_path = /var/lib/cinder/tmp
```

Add the contents of [Text 32] to /etc/cinder/cinder.conf.

```shell
(Storage)$ service tgt restart
(Storage)$ service cinder-volume restart
```

Start Cinder.

### 8.4. Verification

```shell
(Controller)$ . admin-openrc
(Controller)$ openstack volume service list
+------------------+------------+------+---------+-------+----------------------------+
| Binary           | Host       | Zone | Status  | State | Updated_at                 |
+------------------+------------+------+---------+-------+----------------------------+
| cinder-scheduler | controller | nova | enabled | up    | 2016-09-30T02:27:41.000000 |
| cinder-volume    | block@lvm  | nova | enabled | up    | 2016-09-30T02:27:46.000000 |
+------------------+------------+------+---------+-------+----------------------------+
```

Verify Cinder operation on the Controller Node.

## 9. References

* OpenStack Installation Korean : [https://docs.openstack.org/newton/install-guide-ubuntu/](https://docs.openstack.org/newton/install-guide-ubuntu/)
* OpenStack Installation English : [https://docs.openstack.org/newton/ko_KR/install-guide-ubuntu/](https://docs.openstack.org/newton/ko_KR/install-guide-ubuntu/)

