---
title: Android 설치 / Arndale 환경
---

## 1. 설치, 실행 환경

설치, 실행 환경은 다음과 같다.
* PC : Windows 7 64bit
* VM on PC : Ubuntu 12.04LTS 64bit
* Android JB mr1 provided from Insignal

## 2. Windows에 USB Driver 설치

{{< figure caption="[Figure 1] Arndale Board의 Hardware ID 확인" src="images/arndale-usb-hardware-info.png" width="500px" >}}

Arndale Board의 USB OTG 단자를 통해 PC와 연결한 다음 Hardware ID 확인한다.

* Computer -> Properties -> Device Manager -> Full -> Properties > Details >Hardware ID

```text {caption="[File 1] adt-bundle-windows-x86-64-20xxxxxx\sdk\extras\google\usb-driver\android-winusb.inf", linenos=table}
...
[Google.NTx86]
;Insignal ARNDALE
%CompositeAdbInterface%     = USB-Install, USB\VID-18D1&PID-0002&REV-0100
%CompositeAdbInterface%     = USB-Install, USB\VID-18D1&PID-0002

...
[Google.NTamd64]
;Insignal ARNDALE
%CompositeAdbInterface%     = USB-Install, USB\VID-18D1&PID-0002&REV-0100
%CompositeAdbInterface%     = USB-Install, USB\VID-18D1&PID-0002
```

android-winusb.inf 파일 아래에 [File 1]의 내용을 추가한 다음 Windows의 Device Manager를 통해 ADB USB Driver 설치한다.

## 3. Ubuntu Package 설치

```shell
$ apt-get install git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses5-dev:i386 x11proto-core-dev libx11-dev:i386 libreadline6-dev:i386 libgl1-mesa-dev g++-multilib mingw32 tofrodos python-markdown libxml2-utils xsltproc zlib1g-dev:i386
$ ln -s /usr/lib/i386-linux-gnu/mesa/libGL.so.1 /usr/lib/i386-linux-gnu/libGL.so
```

Android Build에 필요한 Ubuntu Package 설치한다.

```shell
$ add-apt-repository ppa:webupd8team/java
$ apt-get update
$ apt-get install oracle-java6-installer
```

Android Build에 필요한 Java 6를 설치한다.

## 4. Ubuntu에 Repo 설치

```shell
$ mkdir ~/bin
$ curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
$ chmod a+x ~/bin/repo
```

Android Build시 이용하는 Repo를 설치한다.

```shell {caption="[File 2] ~/.bashrc", linenos=table}
...
PATH=~/bin:$PATH
```

`~/.bashrc` 파일에 [File 2]의 내용을 추가하여 어느 Directory에서든 Repo를 이용할 수 있도록 만든다.

## 5. Ubuntu에 fastboot, adb 설치

```shell
$ unzip adb-fastboot-for-linux-host.zip
$ mv adb ~/bin
$ mv fastboot ~/bin
```

fastboot와 adb는 Build한 Android를 Device에 Flash할때 이용된다. fastboot와 adb를 설치한다.
* fastboot, adb Download : http://forum.insignal.co.kr/download/file.php?id=90

## 6. Ubuntu에 Cross Compiler 설치

```shell
$ mv ./arm-2009q3.tar /usr/local
$ cd /usr/local
$ tar xvf arm-2009q3.tar
```

Cross Compiler를 설치한다.
* Cross Compiler Download : http://www.arndaleboard.org/wiki/downloads/supports/arm-2009q3.tar

```shell {caption="[File 3] ~/.bashrc", linenos=table}
...
PATH=/usr/local/arm-2009q3/bin:$PATH
```

`~/.bashrc` 파일에 [File 3]의 내용을 추가하여 어느 Directory에서든 Compiler를 이용할 수 있도록 만든다.

## 7. Source Code Download

```shell
$ repo init -u git://git.insignal.co.kr/samsung/exynos/android/manifest.git -b jb-mr1
$ repo sync
```

u-boot, Linux Kernel, Android jb-mr1 Source를 받는다.

## 8. Download Proprietary

```shell
$ mv vendor-samsung-slsi-exynos5250-jb-mr1-20140526-14b314b.run [root of source tree]
$ mv vendor-insignal-arndale-jb-mr1-20140526-0a0bc3f.run [root of source tree]
$ cd [root of source tree]
$ chmod chmod +x vendor-samsung-slsi-exynos5250-jb-mr1-20140526-14b314b.run
$ chmod chmod +x vendor-insignal-arndale-jb-mr1-20140526-0a0bc3f.run
$ ./vendor-samsung-slsi-exynos5250-jb-mr1-20140526-14b314b.run
$ ./vendor-insignal-arndale-jb-mr1-20140526-0a0bc3f.run
```

Booting을 위한 Proprietary를 받고 설치한다.
* Exynos5250 Download : http://forum.insignal.co.kr/download/file.php?id=247	
* Arndale Download : http://forum.insignal.co.kr/download/file.php?id=246

## 9. ccache 설정

```shell
$ cd [root of source tree]
$ export USE-CCACHE=1
$ export CCACHE-DIR=/[path of your choice]/.ccache
$ prebuilts/misc/linux-x86/ccache/ccache -M 20G
$ watch -n1 -d prebuilts/misc/linux-x86/ccache/ccache -s
```

Build 성능 향상을 위해서 ccache를 설정한다.

## 10. Build

```shell
$ cd [root of source tree]/u-boot/
$ make clobber
$ make ARCH=arm CROSS-COMPILE=arm-none-linux-gnueabi- arndale-config
$ make ARCH=arm CROSS-COMPILE=arm-none-linux-gnueabi-
```

u-boot를 Build한다.

```shell
$ cd [root of source tree]/u-boot/
$ kernel-make distclean
$ kernel-make arndale-android-defconfig
$ kernel-make -j16
```

Kernel을 Build한다.

```shell
$ cd [root of source tree]/u-boot/
$ choosevariant
$ choosetype
$ make kernel-binaries
$ make -j4
```

Android를 Build한다.

## 11. Bootable uSD Card 만들기

```shell
$ source ./arndale-envsetup.sh
$ mksdboot /dev/sdb
```

uSD Card를 Ubuntu에 연결 및 Device Name (/dev/sdb) 확인한 다음 uSD Card Format한다.

## 12. uSD Card에 Partition 생성

```shell
Arndale $ fdisk -c 0 520 520 520
Arndale $ fatformat mmc 0:1
Arndale $ fatformat mmc 0:2
Arndale $ fatformat mmc 0:3
Arndale $ fatformat mmc 0:4
```

uSD Card를 Arndale에 넣은 뒤 Arndale의 u-boot에 접근한 다음 u-boot에서 Partition 생성한다.

## 13. Binary들을 uSD에 Flash

```shell
Arndale $ fastboot
``` 

Arndale Board의 USB OTG 단자를 통해 PC와 연결한 다음 u-boot에서 fastboot에 진입하여 Flash를 준비한다.

```shell
$ fastboot flash fwbl1 ./vendor/insignal/arndale/exynos5250/exynos5250.bl1.bin
$ fastboot flash bl2 ./u-boot/bl2.bin
$ fastboot flash bootloader ./u-boot/u-boot.bin
$ fastboot flash tzsw ./vendor/insignal/arndale/exynos5250/exynos5250.tzsw.bin
$ fastboot flash kernel ./kernel/arch/arm/boot/zImage
$ fastboot flash ramdisk ./out/debug/target/product/arndale/ramdisk.img.ub
$ fastboot flash system ./out/debug/target/product/arndale/system.img
$ fastboot reboot
```

fastboot에서 Flash를 수행한다.

## 14. 참조

* [http://www.webupd8.org/2012/11/oracle-sun-java-6-installer-available.html](http://www.webupd8.org/2012/11/oracle-sun-java-6-installer-available.html)
* [https://source.android.com/setup/build/downloading#installing-repo](https://source.android.com/setup/build/downloading#installing-repo)
