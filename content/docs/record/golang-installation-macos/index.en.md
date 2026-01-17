---
title: Golang Installation / macOS Environment
---

## 1. Installation Environment

The installation environment is as follows.
* Ubuntu 10.14.5
* golang 1.12.2

## 2. Homebrew Package Installation

```
# brew install golang
```

Install golang using Homebrew.

## 3. Environment Variable Setting

```text {caption="[File 1] ~/.bash-profile", linenos=table}
...
export GOROOT="$(brew --prefix golang)/libexec"
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$GOROOT/bin:$GOBIN:$PATH
...
```

Set environment variables used by golang in the ~/.bash-profile file so that golang can be used from any Directory.
* GOROOT : Directory where golang commands, Packages, Libraries, etc. are located.
* GOPATH : Home Directory of golang Programs currently being developed.
* GOBIN : Directory where compiled golang Binaries are copied when using the go install command.

## 4. References

* [https://ahmadawais.com/install-go-lang-on-macos-with-homebrew](https://ahmadawais.com/install-go-lang-on-macos-with-homebrew/)

