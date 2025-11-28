---
title: Container Network Interface (CNI)
---

Analyze Container Network Interface (CNI) used when setting up Container Network.

## 1. Container Network Interface (CNI)

{{< figure caption="[Figure 1] Consul Architecture" src="images/cni.png" width="800px" >}}

Container Network Interface (CNI) is an Interface used when setting up **Network Interface of Linux Container**. Many Container Platforms or Container Runtimes such as Kubernetes, rkt, and Openshift set up Container's Network Interface by executing **Conf (Configuration) files** and **Plugins** that comply with CNI. Here, Conf File means a configuration file containing Network information to be connected to Network Interface to be set up in Container, and Plugin means a Binary (Command) executable in Shell.

### 1.1 Conf (Configuration) 파일

```json {caption="[File 1] mynet.conf", linenos=table}
{
	"cniVersion": "0.2.0",
	"name": "mynet",
	"type": "bridge",
	"bridge": "cni0",
	"isGateway": true,
	"ipMasq": true,
	"ipam": {
		"type": "host-local",
		"subnet": "10.22.0.0/16",
		"routes": [
			{ "dst": "0.0.0.0/0" }
		]
	}
}
```

Conf file is a configuration file where Network information to be connected to Network Interface to be set up in Container is stored. [File 1] shows mynet.conf, an example of Conf file. It includes Network IP, Routing Rules, and Bridge name needed for network configuration. Conf file uses "/etc/cni/net.d" as the default path. The format of Conf file can vary depending on the Plugin to be used.

### 1.2. Plugin

Plugin performs the role of setting up Network Interface connected to Network configured in Conf file to Container and returning Network Interface information of the set up Container. Plugin exists in the form of Binary (Command) executable in Shell. Plugin receives Conf file content through **stdin** and uses environment variables such as CNI_COMMAND, CNI_CONTAINERID, CNI_NETNS, CNI_IFNAME as Parameters. Below is a description of important environment variables.

* CNI_COMMAND : Network Interface ADD (add), DEL (delete), GET (query) commands
* CNI_CONTAINERID : ID of Target Container to manipulate Network Interface
* CNI_NETNS : Location of Network Namespace File of Target Container
* CNI_IFNAME : Network Interface name

```shell {caption="[Shell 1] mynet.conf 적용"}
$ export CNI_COMMAND=ADD; export CNI_CONTAINERID=...
$ /opt/cni/bin/bridge < ~/test_cni/mynet.conf
{
    "ip4": {
        "ip": "10.22.0.3/16",
        "gateway": "10.22.0.1",
        "routes": [
            {
                "dst": "0.0.0.0/0",
                "gw": "10.22.0.1"
            }
        ]
    },
    "dns": {}
}
```

If Plugin is executed well and Container's Network Interface manipulation succeeds, Plugin outputs related Network Interface's MAC, IP, DNS information, etc. in **JSON format to stdout**. [Shell 1] shows the content output by Plugin when Network Interface is added to Container using mynet.conf file from [File 1]. You can see IP, Gateway information, etc. of the added Interface. Plugin uses "/opt/cni/bin" as the default path.

Container Platform or Container Runtime performs operations of setting up Container's Network Interface through Conf file creation, environment variable setting for Plugin, and Plugin execution, and obtaining and managing information of set up Container Interface output to Plugin's stdout.

## 2. References

* [https://github.com/containernetworking/cni/blob/master/SPEC.md](https://github.com/containernetworking/cni/blob/master/SPEC.md)
* [https://kubernetes-csi.github.io/docs/](https://kubernetes-csi.github.io/docs/)
* [https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)

