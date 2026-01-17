---
title: Ubuntu Consolas Font Installation / Ubuntu 16.04 Environment
---

## 1. Installation Environment

The installation environment is as follows.
* Ubuntu 16.04 LTS 64bit, root user

## 2. Ubuntu Package Installation

```shell
$ apt-get install font-manager
$ apt-get install cabextract
```

Install font-manager.

## 3. Consolas Download Script Creation and Installation

```shell
$ vim consolas.sh
```

```shell {caption="[File 1] consolas.sh", linenos=table}
#!/bin/sh
set -e
set -x
mkdir temp
cd temp
wget http://download.microsoft.com/download/E/6/7/E675FFFC-2A6D-4AB0-B3EB-27C9F8C8F696/PowerPointViewer.exe
cabextract -L -F ppviewer.cab PowerPointViewer.exe
cabextract ppviewer.cab
```

Create the `consolas.sh` file by copying the content from [File 1].

```shell
$ chmod +x consolas.sh
$ ./consolas.sh
```

Execute `consolas.sh`.

## 4. Consolas Font Installation

```shell
$ font-manager
```

Run font-manager.

{{< figure caption="[Figure 1] Font File Selection" src="images/ubuntu-font-manager.png" width="700px" >}}

Click Install Fonts and select the font files in the temp folder.

## 5. File Deletion

```shell
$ rm -r temp
$ rm consolas.sh
```

Delete font files and the `consolas.sh` file.

## 6. References

* [http://www.rushis.com/2013/03/consolas-font-on-ubuntu/](http://www.rushis.com/2013/03/consolas-font-on-ubuntu/)
* [http://askubuntu.com/questions/191778/how-to-install-fonts-fast-and-easy](http://askubuntu.com/questions/191778/how-to-install-fonts-fast-and-easy)

