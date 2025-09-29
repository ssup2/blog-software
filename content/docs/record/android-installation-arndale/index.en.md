---
title: Android Installation / Arndale Environment
---

## 1. Installation, Execution Environment

The installation and execution environment is as follows:
* PC : Windows 7 64bit
* VM on PC : Ubuntu 12.04LTS 64bit
* Android JB mr1 provided from Insignal

## 2. USB Driver Installation on Windows

{{< figure caption="[Figure 1] Arndale Board Hardware ID Verification" src="images/arndale-usb-hardware-info.png" width="500px" >}}

Connect the Arndale Board to PC through USB OTG port and verify Hardware ID.

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

Add the content of [File 1] below the android-winusb.inf file and install ADB USB Driver through Windows Device Manager.

## 3. Ubuntu Package Installation

```shell
$ apt-get install git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses5-dev:i386 x11proto-core-dev libx11-dev:i386 libreadline6-dev:i386 libgl1-mesa-dev g++-multilib mingw32 tofrodos python-markdown libxml2-utils xsltproc zlib1g-dev:i386
$ ln -s /usr/lib/i386-linux-gnu/mesa/libGL.so.1 /usr/lib/i386-linux-gnu/libGL.so
```

Install Ubuntu packages required for Android build.

```shell
$ add-apt-repository ppa:webupd8team/java
$ apt-get update
$ apt-get install oracle-java6-installer
```

Install Java 6 required for Android build.

## 4. Repo Installation on Ubuntu

```shell
$ mkdir ~/bin
$ curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
$ chmod a+x ~/bin/repo
```

Install Repo used during Android build.

```shell {caption="[File 2] ~/.bashrc", linenos=table}
...
PATH=~/bin:$PATH
```

Add the content of [File 2] to `~/.bashrc` file to make Repo available from any directory.

## 5. fastboot, adb Installation on Ubuntu

```shell
$ unzip adb-fastboot-for-linux-host.zip
$ mv adb ~/bin
$ mv fastboot ~/bin
```

fastboot and adb are used when flashing built Android to device. Install fastboot and adb.
* fastboot, adb Download : http://forum.insignal.co.kr/download/file.php?id=90

## 6. Cross Compiler Installation on Ubuntu

```shell
$ mv ./arm-2009q3.tar /usr/local
$ cd /usr/local
$ tar xvf arm-2009q3.tar
```

Install Cross Compiler.
* Cross Compiler Download : http://www.arndaleboard.org/wiki/downloads/supports/arm-2009q3.tar

```shell {caption="[File 3] ~/.bashrc", linenos=table}
...
PATH=/usr/local/arm-2009q3/bin:$PATH
```

Add the content of [File 3] to `~/.bashrc` file to make the compiler available from any directory.

## 7. Source Code Download

```shell
$ repo init -u git://git.insignal.co.kr/samsung/exynos/android/manifest.git -b jb-mr1
$ repo sync
```

Download u-boot, Linux Kernel, Android jb-mr1 source.

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

Download and install Proprietary for booting.
* Exynos5250 Download : http://forum.insignal.co.kr/download/file.php?id=247	
* Arndale Download : http://forum.insignal.co.kr/download/file.php?id=246

## 9. ccache Configuration

```shell
$ cd [root of source tree]
$ export USE-CCACHE=1
$ export CCACHE-DIR=/[path of your choice]/.ccache
$ prebuilts/misc/linux-x86/ccache/ccache -M 20G
$ watch -n1 -d prebuilts/misc/linux-x86/ccache/ccache -s
```

Configure ccache for build performance improvement.

## 10. Build

```shell
$ cd [root of source tree]/u-boot/
$ make clobber
$ make ARCH=arm CROSS-COMPILE=arm-none-linux-gnueabi- arndale-config
$ make ARCH=arm CROSS-COMPILE=arm-none-linux-gnueabi-
```

Build u-boot.

```shell
$ cd [root of source tree]/u-boot/
$ kernel-make distclean
$ kernel-make arndale-android-defconfig
$ kernel-make -j16
```

Build Kernel.

```shell
$ cd [root of source tree]/u-boot/
$ choosevariant
$ choosetype
$ make kernel-binaries
$ make -j4
```

Build Android.

## 11. Create Bootable uSD Card

```shell
$ source ./arndale-envsetup.sh
$ mksdboot /dev/sdb
```

Connect uSD Card to Ubuntu, verify Device Name (/dev/sdb), then format uSD Card.

## 12. Create Partition on uSD Card

```shell
Arndale $ fdisk -c 0 520 520 520
Arndale $ fatformat mmc 0:1
Arndale $ fatformat mmc 0:2
Arndale $ fatformat mmc 0:3
Arndale $ fatformat mmc 0:4
```

Insert uSD Card into Arndale, access Arndale's u-boot, then create partitions from u-boot.

## 13. Flash Binaries to uSD

```shell
Arndale $ fastboot
``` 

Connect Arndale Board to PC through USB OTG port, then enter fastboot from u-boot to prepare for flashing.

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

Perform flashing from fastboot.

## 14. References

* [http://www.webupd8.org/2012/11/oracle-sun-java-6-installer-available.html](http://www.webupd8.org/2012/11/oracle-sun-java-6-installer-available.html)
* [https://source.android.com/setup/build/downloading#installing-repo](https://source.android.com/setup/build/downloading#installing-repo)
