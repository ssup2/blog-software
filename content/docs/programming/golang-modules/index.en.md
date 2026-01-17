---
title: Golang Module
---

This document analyzes and understands Module, a technique for managing Package Dependencies in Golang, through practice.

## 1. Golang Module

A Module is a collection of Packages. The functionality to manage such Modules has been included since **Golang 1.11**. Golang manages Package Dependencies using Module management functionality. With Golang Modules, Golang developers no longer need to place Golang Code in the $GOPATH/src Directory. Before Golang 1.11, separate tools like vgo and dep were used to manage Package Dependencies.

### 1.1. Module Creation

```shell {caption="[Shell 1] Module Creation"}
$ export GO111MODULE=off
$ go get github.com/ssup2/example-golang-module-module
$ cd $GOPATH/src/github.com/ssup2/example-golang-module-module
$ export GO111MODULE=on

$ vim test.go
$ vim go.mod
$ git add .
$ git commit -m "version 1.1.0"
$ git tag -a v1.1.0 -m "v1.1.0"
$ vim test.go
$ git add .
$ git commit -m "version 1.1.5"
$ git tag -a v1.1.5 -m "1.1.5"

$ vim test.go
$ vim go.mod
$ git add .
$ git commit -m "version 2.2.0"
$ git tag -a v2.2.0 -m "2.2.0"
$ vim test.go
$ git add .
$ git commit -m "version 2.2.7"
$ git tag -a v2.2.7 -m "2.2.7"

$ vim test.go
$ vim go.mod
$ git add .
$ git commit -m "version 3.3.0"
 
$ git push
$ git push --tags
```

```text {caption="[File 1] Module's go.mod - v0.x.x, v1.x.x", linenos=table}
module github.com/ssup2/example-golang-module-module

go 1.12   
```

```go {caption="[Code 1] test.go - v1.1.0", linenos=table}
package test

import "fmt"

func TestPrint() {
    fmt.Println("test - v1.1.0")
}  
```

```go {caption="[Code 2] test.go - v1.1.5", linenos=table}
package test

import "fmt"

func TestPrint() {
    fmt.Println("test - v1.1.5")
}
```

```text {caption="[File 2] Module's go.mod - v2.x.x", linenos=table}
module github.com/ssup2/example-golang-module-module/v2

go 1.12
```

```go {caption="[Code 3] outer.go - v2.2.0", linenos=table}
package test

import "fmt"

func TestPrint() {
    fmt.Println("test - v2.2.0")
}
```

```go {caption="[Code 4] outer.go - v2.2.7", linenos=table}
package test

import "fmt"

func TestPrint() {
    fmt.Println("test - v2.2.7")
}
```

```text {caption="[File 3] Module's go.mod - v3.x.x", linenos=table}
module github.com/ssup2/example-golang-module-module/v3

go 1.12
```

```go {caption="[Code 5] outer.go - v3.3.0", linenos=table}
package test

import "fmt"

func TestPrint() {
    fmt.Println("test - v3.3.0")
}
```

[Shell 1] shows the process of creating an example-golang-module-module Repository in the ssup2 account on Github and then creating a Module for testing. The `GO111MODULE` environment variable determines whether to use the Module management functionality supported by Golang. When the `GO111MODULE` environment variable has the value off, it means that the Module management functionality supported by Golang will not be used. When off, the go get command receives Golang Code in `$GOPATH/src`. When the `GO111MODULE` environment variable has the value on, it means that the Module management functionality supported by Golang will be used. When on, the go get command receives Golang Code in `$GOPATH/pkg/mod`. In [Shell 1], the `GO111MODULE` environment variable was temporarily set to off only when receiving Golang Code with go get.

Module Version must be in the format `v[Major].[Minor].[Patch]`. [Code 1 ~ 5] show the test.go files for each Module Version. [File 1 ~3] show the Module's go.mod files. **The go.mod file is an important file that stores Module-related information.** When the Module's Major Version is v0 or v1, the go.mod file does not need to specify the Major Version as in [File 1], but when the Major Version is v2 or higher, the go.mod file must specify the **Major Version** as in [File 2, 3].

Since Golang's Module management functionality uses **Git Tag** to manage Module Versions, it is good to create Git Tags with Module Versions if possible. In [Shell 1], only the v3.3.0 Version of the Module was not given a Git Tag for testing purposes, while the other Versions were given Git Tags. The Module created in [Shell 1] can be found at [https://github.com/ssup2/example-golang-module-module](https://github.com/ssup2/example-golang-module-module).

### 1.2. Module Usage

#### 1.2.1. When fetching but not using a Module

```shell {caption="[Shell 2] Module Initialization"}
$ export GO111MODULE=on

$ go mod init module-main
$ go get github.com/ssup2/example-golang-module-module@v1.1.0
$ vim go.mod
```

```text {caption="[File 4] Main's go.mod - v1.1.0", linenos=table}
module module-main

go 1.12

require github.com/ssup2/example-golang-module-module v1.1.0 // indirect      
```

[Shell 2] shows the process of creating a go.mod file using the `go mod init` command in an arbitrary Directory, and then fetching the v1.1.0 Version Module created in [Shell 1]. The go.mod file is created with the contents of [File 4]. You can see that the fetched Module and Version are specified. There is an `indirect` comment at the end because the Module was fetched through the go get command but is not actually being used.

```shell {caption="[Shell 3] Module Cleanup"}
$ export GO111MODULE=on

$ go mod tidy
```

```text {caption="[File 5] Main's go.mod - Empty", linenos=table}
module module-main

go 1.12
```

The `go mod tidy` command removes Module information that is not being used from the go.mod file. Golang's Module management functionality automatically adds new Modules to the go.mod file when they are added, but does not automatically remove unused Modules from the go.mod file. Developers must manage unused Modules using the go mod tidy command. [Shell 3], [File 5] show the process of removing unused Module information from the go.mod file through the go mod tidy command.

#### 1.2.2. When using a Module with Version registered via Git Tag

```shell {caption="[Shell 4] Main Creation and Execution - v1.1.5"}
$ export GO111MODULE=on

$ vim main.go
$ vim go.mod
$ go build
$ ./module-main
test - v1.1.5
```

```go {caption="[Code 6] main.go - v0.x.x, v1.x.x", linenos=table}
package main

import module "github.com/ssup2/example-golang-module-module"

func main() {
    module.TestPrint()
}
```

```text {caption="[File 6] Main's go.mod - v1.1.5", linenos=table}
module module-main

go 1.12

require github.com/ssup2/example-golang-module-module v1.1.5      
```

[Shell 4] shows the process of creating and running a main() function that calls the created Module. You can see that main.go shown in [Code 6] calls the TestPrint() function of the created Module. After creating main.go, a go.mod file with the contents of [File 6] is created. You can see that [File 6] specifies that it uses the created v1.1.5 Version Module. Since [Code 6] does not specify a Module Version, the highest Version Module among Modules with Major Version v0 or v1 is selected, and since v1.1.5 Version is the highest v0, v1 Version, it is automatically set to use v1.1.5.

```shell {caption="[Shell 5] Main Creation and Execution - v2.2.7"}
$ export GO111MODULE=on

$ vim main.go
$ vim go.mod
$ go build
$ ./module-main
test - v1.1.5
```

```go {caption="[Code 7] main.go - v2.x.x", linenos=table}
package main

import module "github.com/ssup2/example-golang-module-module/v2"

func main() {
    module.TestPrint()
}
```

```text {caption="[File 7] Main's go.mod - v2.2.7", linenos=table}
module module-main

go 1.12

require (
    github.com/ssup2/example-golang-module-module v1.1.5
    github.com/ssup2/example-golang-module-module/v2 v2.2.7
)       
```

[Shell 4] shows the process of changing main.go to use Module Version v2 as in [Code 7], and then running the main() function again. Since v2.2.7 Version is the highest Version among v2 Version Modules, it is automatically set to use v2.2.7. You can see that [File 7] has added content indicating that it uses the v2.2.7 Version Module. The v1.1.5 Version Module information remains but is not actually used. If you use the go mod tidy command, the v1.1.5 Version Module information will disappear.

```shell {caption="[Shell 6] Main Creation and Execution - v2.2.0"}
$ export GO111MODULE=on

$ go get github.com/ssup2/example-golang-module-module/v2@v2.2.0
$ vim go.mod
$ go build
$ ./module-main
test - v2.2.0
```

```text {caption="[File 8] Main's go.mod - v2.2.7", linenos=table}
module module-main

go 1.12

require (
    github.com/ssup2/example-golang-module-module v1.1.5
    github.com/ssup2/example-golang-module-module/v2 v2.2.0
)           
```

[Shell 6] shows the process of setting up to use the v2.2.0 Version Module. You can modify go.mod through the go get command. You can see in [File 8] that the v2 Version has been changed to v2.2.0. You can also directly modify the go.mod file.

#### 1.2.3. When using a Module without Version registered via Git Tag

```shell {caption="[Shell 7] Main Creation and Execution - v3"}
$ export GO111MODULE=on

$ go get github.com/ssup2/example-golang-module-module/v3@master
$ vim main.go
$ vim go.mod
$ go build
$ ./module-main
test - v3.3.0
```

```go {caption="[Code 8] main.go - v3.x.x", linenos=table}
package main

import module "github.com/ssup2/example-golang-module-module/v3"

func main() {
    module.TestPrint()
}
```

```text {caption="[File 9] Main's go.mod - v3.3.0", linenos=table}
module module-main

go 1.12

require (
    github.com/ssup2/example-golang-module-module v1.1.5
    github.com/ssup2/example-golang-module-module/v2 v2.2.7
    github.com/ssup2/example-golang-module-module/v3 v3.0.0-20190622090929-c4fe1b48c3ad
)       
```

[Shell 7] shows the process of setting up to use the v3.3.0 Version Module. Since the v3.3.0 Version was not given a Git Tag, it must be set up using the master Branch. In [File 9], you can also see that since the v3.3.0 Version has no Git Tag, v3 has an arbitrary Tag. The arbitrary Tag consists of the date and Commit ID of the last Commit on the master Branch. In [File 10], `20190622090929` means the Commit date and `c4fe1b48c3ad` means the Commit ID.

### 1.3. Module-related Commands

Commands related to Golang Modules are as follows.

* `go mod init` : Creates a go.mod file.
* `go list -m all` : Checks the Versions of Modules used during Build.
* `go list -u -m all` : Checks if Modules can be Patched.
* `go get -u` : Patches (Updates) Modules.
* `go mod tidy` : Removes unnecessary Modules from go.mod and adds necessary Modules.
* `go mod vendor` : Creates a vendor Directory using Modules in go.mod.
* `go clean --modcache` : Deletes the Module Cache ($GOPATH/pkg/mod).

## 2. References

* [https://blog.golang.org/using-go-modules](https://blog.golang.org/using-go-modules)
* [https://jusths.tistory.com/107](https://jusths.tistory.com/107)
* [https://velog.io/@kimmachinegun/Go-Go-Modules-%EC%82%B4%ED%8E%B4%EB%B3%B4%EA%B8%B0-7cjn4soifk](https://velog.io/@kimmachinegun/Go-Go-Modules-%EC%82%B4%ED%8E%B4%EB%B3%B4%EA%B8%B0-7cjn4soifk)
* [https://aidanbae.github.io/code/golang/modules/](https://aidanbae.github.io/code/golang/modules/)
* [https://medium.com/rungo/anatomy-of-modules-in-go-c8274d215c16](https://medium.com/rungo/anatomy-of-modules-in-go-c8274d215c16)
* [https://johngrib.github.io/wiki/golang-mod/](https://johngrib.github.io/wiki/golang-mod/)

