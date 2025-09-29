---
title: Golang Installation / Ubuntu 18.04 Environment
---

## 1. Installation Environment

The installation environment is as follows:
* Ubuntu 18.04 LTS 64bit, root user
* golang 1.12.2

## 2. Ubuntu Package Installation

```shell
$ wget https://dl.google.com/go/go1.12.2.linux-amd64.tar.gz
$ tar -xvf go1.12.2.linux-amd64.tar.gz
$ mv go /usr/local
```

Install golang. Install in /usr/local/go directory.

## 3. Environment Variable Configuration

```text {caption="[File 1] ~/.bashrc", linenos=table}
...
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$GOROOT/bin:$GOBIN:$PATH
...
```

Configure environment variables for golang in ~/.bashrc file and make golang available from any directory.
* GOROOT : Directory containing golang commands, packages, libraries, etc.
* GOPATH : Home directory of the golang program currently being developed.
* GOBIN : Directory where compiled golang binaries are copied when using go install command.

## 4. References

* [https://medium.com/@RidhamTarpara/install-go-1-11-on-ubuntu-18-04-16-04-lts-8c098c503c5f](https://medium.com/@RidhamTarpara/install-go-1-11-on-ubuntu-18-04-16-04-lts-8c098c503c5f)
