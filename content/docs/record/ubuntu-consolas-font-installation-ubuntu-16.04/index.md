---
title: Ubuntu Consolas Font 설치 / Ubuntu 16.04 환경
---

## 1. 설치 환경

설치 환경은 다음과 같다.
* Ubuntu 16.04 LTS 64bit, root user

## 2. Ubuntu Package 설치

```shell
$ apt-get install font-manager
$ apt-get install cabextract
```

font-manager를 설치한다.

## 3. Consolas Download Script 생성 및 설치

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

[File 1]의 내용을 복사하여 `consolas.sh` 파일을 생성한다.

```shell
$ chmod +x consolas.sh
$ ./consolas.sh
```

`consolas.sh`을 실행한다.

## 4. Consolas Font 설치

```shell
$ font-manager
```

font-manager 실행한다.

{{< figure caption="[Figure 1] Font 파일 선택" src="images/ubuntu-font-manager.png" width="700px" >}}

Install Fonts를 눌러 temp 폴더 안에 있는 Font 파일들을 선택한다.

## 5. 파일 삭제

```shell
$ rm -r temp
$ rm consolas.sh
```

Font 파일들과 `consolas.sh` 파일을 지운다.

## 6. 참조

* [http://www.rushis.com/2013/03/consolas-font-on-ubuntu/](http://www.rushis.com/2013/03/consolas-font-on-ubuntu/)
* [http://askubuntu.com/questions/191778/how-to-install-fonts-fast-and-easy](http://askubuntu.com/questions/191778/how-to-install-fonts-fast-and-easy)
