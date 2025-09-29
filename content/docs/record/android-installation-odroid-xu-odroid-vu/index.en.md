---
title: Android Installation / ODROID-XU, ODROID-VU Environment
---

## 1. Installation, Execution Environment

The installation and execution environment is as follows:
* PC : Windows 7 64bit
* VM on PC : Ubuntu 12.04LTS 64bit
* ODROID-XU, 16GB emmc
* Android 4.2.2 Alpha 2.5 Release

## 2. ADB Driver Installation on Windows

Install ADB USB Driver through Windows Device Manager.
* http://com.odroid.com/sigong/nf-file-board/nfile-board-view.php?bid=22

## 3. Ubuntu Package Installation

```shell
$ apt-get install git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses5-dev:i386 x11proto-core-dev libx11-dev:i386 libreadline6-dev:i386 libgl1-mesa-dev g++-multilib mingw32 tofrodos python-markdown libxml2-utils xsltproc zlib1g-dev:i386
$ ln -s /usr/lib/i386-linux-gnu/mesa/libGL.so.1 /usr/lib/i386-linux-gnu/libGL.so
```

Install Ubuntu packages for Android build.

```shell
$ add-apt-repository ppa:webupd8team/java
$ apt-get update
$ apt-get install oracle-java6-installer
```

Install Java 6.

## 5. Repo Installation on Ubuntu

```shell
$ mkdir ~/bin
$ curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
$ chmod a+x ~/bin/repo
```

Repo is used during Android build. Install Repo used during Android build.

```shell {caption="[File 1] ~/.bashrc", linenos=table}
...
PATH=~/bin:$PATH
```

Add the content of [File 1] to `~/.bashrc` file to make Repo available from any directory.

## 6. Cross Compiler Installation on Ubuntu

```shell
$ mv ./arm-eabi-4.6.tar.gz /usr/local
$ cd /usr/local
$ tar zxvf arm-eabi-4.6.tar.gz
```

Install Cross Compiler.

* Download : http://dn.odroid.com/ODROID-XU/compiler/arm-eabi-4.6.tar.gz

```shell {caption="[File 2] ~/.bashrc", linenos=table}
...
PATH=/usr/local/arm-eabi-4.6/bin:$PATH
```

Add the content of [File 2] to `~/.bashrc` file to make the compiler available from any directory.

## 7. Download Prebuilt Images and Sources

Download Prebuilt Images through the URLs below.
* Prebuilt Image
  * http://dn.odroid.com/ODROID-XU/Firmware/01-10-2014/emmc-self-installer.img.zip
* Android, Kernel
  * http://dn.odroid.com/ODROID-XU/Android-bsp/01-25-2014/android.tgz
* Kernel Patch
  * http://dn.odroid.com/ODROID-XU/Android-bsp/04-07-2014/kernel-Apr-07-2014.patch
* Android Patch
  * http://dn.odroid.com/ODROID-XU/Android-bsp/04-07-2014/android-patch.zip
  * http://dn.odroid.com/ODROID-XU/Android-bsp/04-07-2014/android-patch.sh

## 8. Flash Prebuilt Image to emmc and Android Update

```shell
$ unzip emmc-self-installer.img.zip
$ pv -tpreb emmc-self-installer.img | dd of=/dev/sdb bs=1M
```

Flash PreBuild Image to emmc. After Android boot, run ODROID-XU Updater and enter the URL below.

* http://dn.odroid.com/ODROID-XU/Firmware/04-07-2014/update.zip

## 10. Apply Patches

### 10.1. kernel

```shell
$ chmod +x kernel-Apr-07-2014.patch
$ patch -p1 < kernel-Apr-07-2014.patch
```

Copy `kernel-Apr-07-2014.patch` file to Kernel root folder and execute the above command.

### 10.2. Android

```shell
$ chmod +x android-patch.sh
$ ./android-patch.sh
```

Copy `android-patch.sh`, `android-patch.zip` files to Android root folder and execute the above command.

## 11. Build

```shell
$ cd [Kernel root]
$ ARCH=arm CROSS-COMPILE=arm-eabi- make odroidxu-android-defconfig
$ ARCH=arm CROSS-COMPILE=arm-eabi- make zImage -j4
$ ARCH=arm CROSS-COMPILE=arm-eabi- make modules
$ mkdir modules
$ ARCH=arm CROSS-COMPILE=arm-eabi- INSTALL-MOD-PATH=modules make modules-install
```

Build Kernel.

```shell
$ cd [Android Root]
$ cp ../kernel/modules/lib/modules/3.4.5/kernel/drivers/net/usb/ax88179-178a.ko device/hardkernel/proprietary/bin
$ cp ../kernel/modules/lib/modules/3.4.5/kernel/drivers/net/usb/smsc95xx.ko device/hardkernel/proprietary/bin
$ cp ../kernel/modules/lib/modules/3.4.5/kernel/drivers/net/wireless/rtl8191su/rtl8191su.ko device/hardkernel/proprietary/bin
$ cp ../kernel/modules/lib/modules/3.4.5/kernel/drivers/net/wireless/rtl8192cu-v40/rtl8192cu.ko device/hardkernel/proprietary/bin
$ cp ../kernel/modules/lib/modules/3.4.5/kernel/drivers/scsi/scsi-wait-scan.ko device/hardkernel/proprietary/bin
$ cp ../kernel/modules/lib/modules/3.4.5/kernel/drivers/w1/wire.ko device/hardkernel/proprietary/bin
$ cp ../kernel/arch/arm/boot/zImage device/hardkernel/odroidxu
$ ./build.sh odroidxu platform
```

Build Android.

## 12. Flash Image

```shell
Exynos5410 $ fastboot
```

Connect ODROID-XU's OTG USB to PC, then execute the above command from u-boot.

```shell
$ fastboot flash kernel kernel/arch/arm/boot/zImage
$ fastboot flash system android/out/target/product/odroidxu/system.img
$ fastboot reboot
```

Execute the above command from Ubuntu.

## 13. References

* [http://odroid.com/dokuwiki/doku.php?id=en:odroid-xu](http://odroid.com/dokuwiki/doku.php?id=en:odroid-xu)
* [http://com.odroid.com/sigong/nf-file-board/nfile-board-view.php?keyword=&tag=ODROID-XU&bid=212](http://com.odroid.com/sigong/nf-file-board/nfile-board-view.php?keyword=&tag=ODROID-XU&bid=212)
* [http://www.webupd8.org/2012/11/oracle-sun-java-6-installer-available.html](http://www.webupd8.org/2012/11/oracle-sun-java-6-installer-available.html)
