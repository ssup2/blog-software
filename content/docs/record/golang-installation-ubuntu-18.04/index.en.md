---
title: Golang Installation / Ubuntu 18.04 Environment
---

## 1. Installation Environment

The installation environment is as follows.
* Ubuntu 18.04 LTS 64bit, root user
* golang 1.12.2

## 2. Ubuntu Package Installation

```shell
$ wget https://dl.google.com/go/go1.12.2.linux-amd64.tar.gz
$ tar -xvf go1.12.2.linux-amd64.tar.gz
$ mv go /usr/local
```

Install golang. Install it in the /usr/local/go Directory.

## 3. Environment Variable Setting

```text {caption="[File 1] ~/.bashrc", linenos=table}
...
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$GOROOT/bin:$GOBIN:$PATH
...
```

Set environment variables used by golang in the ~/.bashrc file so that golang can be used from any Directory.
* GOROOT : Directory where golang commands, Packages, Libraries, etc. are located.
* GOPATH : Home Directory of golang Programs currently being developed.
* GOBIN : Directory where compiled golang Binaries are copied when using the go install command.

## 4. References

* [https://medium.com/@RidhamTarpara/install-go-1-11-on-ubuntu-18-04-16-04-lts-8c098c503c5f](https://medium.com/@RidhamTarpara/install-go-1-11-on-ubuntu-18-04-16-04-lts-8c098c503c5f)
