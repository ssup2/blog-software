---
title: 3.5. Limitations of Namespace
---

## Limitations of Namespace

So far, we have looked at PID, Network, and Mount Namespaces. Through these Namespaces, each container can operate in a highly isolated environment. However, Namespace does not provide a completely isolated environment. For example, some settings related to Linux Kernel's Network Stack are shared and used across all Network Namespaces.

conntrack is a module that manages network connections in Linux. The maximum number of connections that conntrack can manage can be checked in the "/proc/sys/net/netfilter/nf-conntrack-max" file, and in the Host Network Namespace, you can set the maximum number of connections for conntrack by writing a number to the "/proc/sys/net/netfilter/nf-conntrack-max" file. In other Network Namespaces, the maximum number of connections for conntrack set in the Host Network Namespace is exposed as is.

```console {caption="[Shell 1] Change Maximum Number of conntrack Connections", linenos=table}
# Create netshoot Container
(host)# docker run -d --rm --name netshoot nicolaka/netshoot sleep infinity

# Check maximum number of conntrack connections in Host
(host)# cat /proc/sys/net/netfilter/nf-conntrack-max
131072

# Check maximum number of conntrack connections in netshoot Container
(netshoot)# docker exec -it netshoot cat /proc/sys/net/netfilter/nf-conntrack-max
131072

# Change and check maximum number of conntrack connections in Host
(host)# echo 200000 > /proc/sys/net/netfilter/nf-conntrack-max
(host)# cat /proc/sys/net/netfilter/nf-conntrack-max
200000

# Check changed maximum number of conntrack connections in netshoot Container
(netshoot)# docker exec -it netshoot cat /proc/sys/net/netfilter/nf-conntrack-max
200000
```

[Shell 1] shows the process of checking and changing the maximum number of conntrack connections in the Host, and then checking the maximum number of conntrack connections in the netshoot Container. You can see that the maximum number of conntrack connections changed in the Host is also visible in the netshoot Container.

The important point is that the sum of all connections in the Host and Container cannot exceed the maximum number of conntrack connections setting. In other words, when the maximum number of conntrack connections is set to 100, if the Host has 100 connections, it means that no additional connections can be created not only in the Host but also in other containers. Like this, Network Namespace is expected to isolate and manage network connections separately for each Network Namespace, but in reality, it does not isolate and manage them separately.

Not only the maximum number of conntrack connections used as an example, but also many Linux kernel-related settings are not isolated and managed by Namespace. Linux kernel-related settings that are not isolated by Namespace like this may not be a big problem in development environments where app behavior is checked, but they can become problematic in container-based production environments that provide services to actual users due to multiple containers. Therefore, if a problem that does not occur in development environments occurs in container-based production environments, it is necessary to review whether the cause of the problem is due to not being isolated by Namespace.
