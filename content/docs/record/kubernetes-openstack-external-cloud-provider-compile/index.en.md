---
title: Kubernetes OpenStack External Cloud Provider Compile / Ubuntu 18.04 Environment
---

## 1. Compile Environment

The compile environment is as follows.
* OpenStack External Cloud Provider: v1.15.0
* OS: Ubuntu 18.04 LTS
* Golang: v1.12.2

## 2. OpenStack External Cloud Provider Download

```shell
$ mkdir -p $GOPATH/src/k8s.io/
$ cd $GOPATH/src/k8s.io/
$ git clone https://github.com/kubernetes/cloud-provider-openstack.git
$ git checkout v1.15.0
```

Download the OpenStack External Cloud Provider.

## 3. Binary Compile & Test

```shell
$ cd $GOPATH/src/k8s.io/cloud-provider-openstack
$ make build
$ make test
```

Compile the OpenStack External Cloud Provider to generate binaries and run tests.

## 4. Docker Image Build & Push

```shell
$ export REGISTRY=ssup2
$ export DOCKER-USERNAME=ssup2
$ export DOCKER-PASSWORD=ssup2
$ make images
$ make upload-images 
```

Create Docker images and push the created images to the Docker Registry. Registry-related information for pushing Docker images must be set as environment variables.

## 5. References

* [https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/getting-started-provider-dev.md](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/getting-started-provider-dev.md)

