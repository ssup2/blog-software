---
title: Xen 4.5.0 Installation / Arndale Environment
---

## 1. Installation Environment

The installation environment is as follows.
* PC: Ubuntu 14.04LTS 64bit, root user
* VM on Xen: Xen 4.5.0, Dom0 & DomU kernel 3.18.3 in linux upstream, Ubuntu 14.04LTS 32bit
* Network
  * Gateway: 192.168.0.1
  * HostOS(xenbr0): 192.168.0.150
  * GeustOS_01: 192.168.0.160, GeustOS_02: 192.168.0.161
* Boot
  * PXE Boot or uSD Card Boot

## 2. Cross Compiler Installation

Install a cross compiler.
* Download: https://releases.linaro.org/15.02/components/toolchain/binaries/arm-linux-gnueabihf/gcc-linaro-4.9-2015.02-3-x86_64_arm-linux-gnueabihf.tar.xz

```shell {caption="[File 1] ~/.bashrc"}
...
PATH=$PATH:/usr/local/gcc-linaro-arm-linux-gnueabihf-4.8/bin
```

Extract to the /usr/local directory and add the content from [File 1] to the ~/.bashrc file so that the compiler can be executed from any directory.

## 3. uSD Card Partition Configuration

* 0 ~ 2M, 2M, No Filesystem: Bootloader (bl1, spl, U-boot)
* 2M ~ 18M, 16M, ext2, boot: xen-uImage, linux-zImage, exynos5250-arndale.dtb, load-xen-uSD.img
* 18M ~ rest, ext3, root: Dom0 Root-Filesystem

## 4. U-boot Fusing

```shell
$ git clone git://git.linaro.org/people/ronynandy/u-boot-arndale.git
$ cd u-boot-arndale
$ git checkout lue_arndale_13.1
$ export CROSS_COMPILE=arm-linux-gnueabihf-
$ export ARCH=arm
$ make arndale5250
```

Download and build spl and u-boot.
* Download bl1: http://releases.linaro.org/12.12/components/kernel/arndale-bl1/arndale-bl1.bin

```shell
$ dd if=arndale-bl1.bin of=/dev/sdb bs=512 seek=1
$ dd if=spl/smdk5250-spl.bin of=/dev/sdb bs=512 seek=17
$ dd if=u-boot.bin of=/dev/sdb bs=512 seek=49
```

Fuse bl1, spl, and u-boot.

## 5. Xen Build

```shell
$ git clone git://xenbits.xen.org/xen.git xen-4.5.0
$ cd xen-4.5.0
$ git checkout RELEASE-4.5.0
```

Download Xen.

```shell
$ make dist-xen XEN_TARGET_ARCH=arm32 CROSS_COMPILE=arm-linux-gnueabihf-
$ mkimage -A arm -T kernel -a 0x80200000 -e 0x80200000 -C none -d "./xen/xen" "./xen/xen-uImage"
```

Compile Xen.

## 6. Dom0 Kernel Build

```shell
$ wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.18.3.tar.xz
$ tar xvf linux-3.18.3.tar.xz
$ mv linux-3.18.3_Dom0
```

Download the kernel for Dom0.

```shell
$ make ARCH=arm exynos_defconfig
$ make ARCH=arm menuconfig

Kernel Features -> Xen guest support on ARM <*>
* Save
Device Drivers -> Block device -> Xen block-device backend driver <*>
Device Drivers -> Network device support -> Xen backend network device <*>
Networking support -> Networking options -> 802.1d Ethernet Bridging <M>
```

Configure the kernel for Dom0.

```shell
$ make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage
$ make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs
```

Compile the kernel for Dom0.

## 7. DomU Kernel Build

```shell
$ wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.18.3.tar.xz
$ tar xvf linux-3.18.3.tar.xz
$ mv linux-3.18.3_DomU
```

Download the kernel for DomU.

```shell
$ make ARCH=arm exynos_defconfig
$ make ARCH=arm menuconfig

Kernel Features -> Xen guest support on ARM <*>
```

Configure the kernel for DomU.

```shell
$ make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage
```

Compile the kernel for DomU.

## 8. Boot

Choose either PXE Boot or uSD Card Boot to perform.

### 8.1. PXE Boot

#### 8.1.1. tftp Server Installation

```shell
$ apt-get install xinetd tftp tftpd
```

Install the tftp Ubuntu package.

``` {caption="[File 2] /etc/xinetd.d/tftp", linenos=table}
service tftp
{
    socket_type     = dgram
    protocol        = udp
    wait            = yes
    user            = root
    server          = /usr/sbin/in.tftpd
    server_args     = -s /tftpboot
    disable         = no
    per_source      = 11
    cps             = 100 2
    flags           = IPv4
}
```

Create the /etc/xinetd.d/tftp file with the content from [File 2].

```shell
$ mkdir /tftpboot
$ chmod 777 /tftpboot
$ /etc/init.d/xinetd restart
```

Create the tftp server directory.

#### 8.1.2. Copy Binaries to tftp Server

```shell
$ cd linux_Dom0
$ cp ./arch/arm/boot/dts/exynos5250-arndale.dtb /tftpboot
$ cp ./arch/arm/boot/zImage /tftpboot/linux-zImage
$ cd xen-4.5.0
$ cp xen-uImage /tftpboot
```

Copy the created binaries to the tftp server.

#### 8.1.3. tftp Image File Creation

```shell
$ cd /tftpboot
$ wget http://xenbits.xen.org/people/julieng/load-xen-tftp.scr.txt
$ mkimage -T script -C none -d load-xen-tftp.scr.txt /tftpboot/load-xen-tftp.img
```

Create a tftp image file for booting.

#### 8.1.4. tftp Image File Copy

Copy the load-xen-tftp.img file to the ext2 partition of the uSD Card.

#### 8.1.5. U-boot Configuration

```shell
-> setenv ipaddr 192.168.0.200
-> setenv serverip 192.168.0.100
-> setenv xen_addr_r 0x50000000
-> setenv kernel_addr_r 0x60000000
-> setenv dtb_addr_r 0x42000000
-> setenv script_addr_r 0x40080000
-> setenv xen_path /xen-uImage
-> setenv kernel_path /linux-zImage
-> setenv dtb_path /exynos5250-arndale.dtb
-> setenv bootcmd 'tftpboot $script_addr_r /load-xen-tftp.img; source $script_addr_r'
-> setenv xen_bootargs 'sync_console console=dtuart dtuart=/serial@12C20000'
-> setenv dom0_bootargs 'console=hvc0 ignore_loglevel psci=enable clk_ignore_unused rw rootwait root=/dev/mmcblk1p2'
-> save
```

Configure U-boot.
* board IP: 192.168.0.200
* tftp Server (Host PC): 192.168.0.100

### 8.2. uSD Card Boot

#### 8.2.1. load-xen-uSD.scr.txt File Creation and img File Generation

```shell
$ wget http://xenbits.xen.org/people/julieng/load-xen-tftp.scr.txt
$ mv load-xen-tftp.scr.txt load-xen-uSD.scr.txt
```

```text {caption="[File 3] /etc/xinetd.d/tftp", linenos=table}
...
# Load Linux in memory
ext2load mmc 0:1 $kernel_addr_r /linux-zImage
# Load Xen in memory
ext2load mmc 0:1 $xen_addr_r /xen-uImage
# Load the device tree in memory
ext2load mmc 0:1 $dtb_addr_r /exynos5250-arndale.dtb
...
```

Create the load-xen-uSD.scr.txt file from the load-xen-tftp.scr.txt file.

```shell
# mkimage -T script -C none -d load-xen-uSD.scr.txt /tftpboot/load-xen-uSD.img
```

Create the image file.

#### 8.2.2. Kernel Images, dtb, and uSD Card Image File Copy

Copy linux-zImage, exynos5250-arndale.dtb, and load-xen-uSD.img files to the ext2 partition of the uSD Card.

#### 8.2.3. U-boot Configuration

```shell
-> setenv xen_addr_r 0x50000000
-> setenv kernel_addr_r 0x60000000
-> setenv dtb_addr_r 0x42000000
-> setenv script_addr_r 0x40080000
-> setenv xen_path /xen-uImage
-> setenv kernel_path /linux-zImage
-> setenv dtb_path /exynos5250-arndale.dtb
-> setenv bootcmd 'ext2load mmc 0:1 $script_addr_r /load-xen-uSD.img; source $script_addr_r'
-> setenv xen_bootargs 'sync_console console=dtuart dtuart=/serial@12C20000'
-> setenv dom0_bootargs 'console=hvc0 ignore_loglevel psci=enable clk_ignore_unused rw rootwait root=/dev/mmcblk1p2'
-> save
```

Configure U-boot.

## 9. Xen Tool Build

```shell
$ apt-get install sbuild
$ sbuild-adduser $USER
```

Install sbuild and schroot.

```shell
$ sbuild-createchroot --components=main,universe trusty /srv/chroots/trusty-armhf-cross http://archive.ubuntu.com/ubuntu/
$ mv /etc/schroot/chroot.d/trusty-amd64-sbuild-*(random suffix) /etc/schroot/chroot.d/trusty-armhf-cross
```

Configure rootfs.

```text {caption="[File 4] /etc/schroot/chroot.d/trusty-armhf-cross", linenos=table}
...
[trusty-armhf-cross]
...
description=Debian trusty/armhf crossbuilder
...
```

Modify the /etc/schroot/chroot.d/trusty-armhf-cross file as shown in [File 4].

```shell
$ schroot -c trusty-armhf-cross
(schroot)$ apt-get install vim-tiny wget sudo less pkgbinarymangler
(schroot)$ echo deb http://ports.ubuntu.com/ trusty main universe >> /etc/apt/
(schroot)$ echo 'APT::Install-Recommends "0"' >> /etc/apt/apt.conf.d/30norecommends
(schroot)$ echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/30norecommends
(schroot)$ dpkg --add-architecture armhf
(schroot)$ apt-get update
(schroot)$ apt-get install wget
(schroot)$ apt-get install crossbuild-essential-armhf
(schroot)$ apt-get install libc6-dev:armhf libncurses-dev:armhf uuid-dev:armhf libglib2.0-dev:armhf libssl-dev:armhf libssl-dev:armhf libaio-dev:armhf libyajl-dev:armhf python gettext gcc git libpython2.7-dev:armhf libfdt-dev:armhf libpixman-1-dev:armhf
```

Install packages in rootfs.

```shell
(schroot)$ git clone -b RELEASE-4.5.0 git://xenbits.xen.org/xen.git xen-4.5.0
(schroot)$ cd xen-4.5.0
(schroot)$ CONFIG_SITE=/etc/dpkg-cross/cross-config.armhf ./configure --build=x86_64-unknown-linux-gnu --host=arm-linux-gnueabihf
(schroot)$ make dist-tools CROSS_COMPILE=arm-linux-gnueabihf- XEN_TARGET_ARCH=arm32
  - Confirm 'dist/install' Directory
(schroot)$ exit
```

Build Xen Tool.

## 10. Basic Root Filesystem Image Creation

```shell
$ dd if=/dev/zero bs=1M count=1024 of=rootfs_ori.img
$ mkfs.ext3 rootfs_ori.img (Proceed anyway? (y,n) y)
$ mount -o loop rootfs_ori.img /mnt
```

Create an image file.

```shell
$ apt-get install debootstrap qemu-user-static binfmt-support
$ debootstrap --foreign --arch armhf trusty /mnt http://ports.ubuntu.com/
$ cp /usr/bin/qemu-arm-static /mnt/usr/bin/
$ sudo chroot /mnt
(chroot)$ ./debootstrap/debootstrap --second-stage
```

Configure the root filesystem.

```shell
(chroot)$ passwd
```

Set the root password.

```text {caption="[File 5] Basic Root Filesystem Image's /etc/network/interfaces", linenos=table}
auto eth0
iface eth0 inet dhcp
```

Configure /etc/network/interfaces with the content from [File 5].

```shell
(chroot)$ echo deb http://ports.ubuntu.com/ trusty main >> /etc/apt/sources.list
```

Configure the repository.

```shell
(chroot)$ cp /etc/init/tty1.conf /etc/init/xvc0.conf
```

```text {caption="[File 6] Basic Root Filesystem Image's /etc/init/xvc0.conf", linenos=table}
...
respawn
exec exec /sbin/getty -8 115200 hvc0
```

Create the /etc/init/xvc0.conf file with the content from [File 6] to configure getty.

```shell
(chroot) $ echo 'xenfs   /proc/xen    xenfs    defaults   0   0' >> /etc/fstab
(chroot) $ exit
$ umount /mnt
```

Configure fstab.

## 11. Dom0 Root Filesystem Configuration

```shell
$ cp rootfs_ori.img rootfs_Dom0.img
$ mount -o loop rootfs_Dom0.img /mnt
```

Copy the root image file.

```shell
$ rsync -avp /srv/chroots/trusty-armhf-cross/root/xen-4.5.0/dist/install/ /mnt/
```

Copy Xen Tool.

```shell
$ make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules
$ make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=/mnt modules_install
```

Compile and copy kernel modules.

```shell
$ sudo chroot /mnt
(chroot)$ cat << EOF > /etc/modules
xen-gntalloc
xen-gntdev
bridge
EOF
```

Configure default kernel modules.

```shell
(chroot) $ echo Dom0 > /etc/hostname
(chroot) $ exit
$ umount /mnt
```

Set the hostname.

## 12. DomU_01 Root Filesystem Configuration

```shell
$ cp rootfs_ori.img rootfs_DomU_01.img
$ mount -o loop rootfs_DomU_01.img /mnt
```

Copy the image file.

```shell
$ cd /mnt/dev
$ mknod xvda b 202 0
$ mknod xvdb b 202 16 
$ mknod xvdc b 202 32
$ mknod xvdd b 202 48
$ mknod xvde b 202 64
$ mknod xvdf b 202 80
$ mknod xvdg b 202 96
$ mknod xvdh b 202 112
```

Create xvdX device nodes.

```shell
$ echo DomU01 > /mnt/etc/hostname
```

Set the hostname.

```shell
$ cat << EOF > /mnt/etc/network/interfaces
auto eth0
iface eth0 inet static
address 192.168.0.160
netmask 255.255.255.0
gateway 192.168.0.1
dns-nameservers 8.8.8.8
EOF
$ umount /mnt
```

Configure the network.

## 13. DomU_02 Root Filesystem Configuration

```shell
$ cp rootfs_DomU_01.img rootfs_DomU_02.img
$ mount -o loop rootfs_DomU_02.img /mnt
```

Copy the image file.

```shell
(chroot)$ vi /mnt/etc/hostname
  -> DomU02
```

Set the hostname.

```shell
$ cat << EOF > /mnt/etc/network/interfaces
auto eth0
iface eth0 inet static
address 192.168.0.161
netmask 255.255.255.0
gateway 192.168.0.1
dns-nameservers 8.8.8.8
EOF
$ umount /mnt
```

Configure the network.

## 14. zImage and Root Filesystem Copy

```shell
$ mount -o loop rootfs_Dom0.img /mnt
$ rsync -avp /mnt/ /media/root/root (ext3 partition in uSD)
$ cp rootfs_DomU_01.img /media/root/root/root (ext3 partition in uSD)
$ cp rootfs_DomU_02.img /media/root/root/root (ext3 partition in uSD)
$ cp DomU_zImage /media/root/root/root (ext3 partition in uSD)
$ umount /mnt
```

Copy zImage and root filesystems to uSD.

## 15. Ubuntu Package Installation on Dom0

```shell
(Dom0)$ apt-get install libyajl-dev
(Dom0)$ apt-get install libfdt-dev
(Dom0)$ apt-get install libaio-dev 
(Dom0)$ apt-get install libglib2.0-dev
(Dom0)$ apt-get install libpixman-1-dev
(Dom0)$ ldconfig
(Dom0)$ apt-get install bridge-utils
```

Insert the uSD Card into the Arndale Board, boot, enter Dom0, and execute the following commands.

## 16. DomU Config File Creation

```text {caption="[File 7] Basic Root Filesystem Image's DomU_01.cfg", linenos=table}
kernel = "/root/Xen_Guest/DomU_zImage"
name = "DomU_01"
memory = 128
vcpus = 1
disk = [ 'phy:/dev/loop0,xvda,w' ]
vif = ['bridge=xenbr0']
extra = "earlyprintk=xenboot console=hvc0 rw rootwait root=/dev/xvda"
```

Create the DomU_01.cfg file with the content from [File 7].

```text {caption="[File 8] Basic Root Filesystem Image's DomU_02.cfg", linenos=table}
kernel = "/root/Xen_Guest/DomU_zImage"
name = "DomU_02"
memory = 128
vcpus = 1
disk = [ 'phy:/dev/loop1,xvda,w' ]
vif = ['bridge=xenbr0']
extra = "earlyprintk=xenboot console=hvc0 rw rootwait root=/dev/xvda"
```

Create the DomU_02.cfg file with the content from [File 8].

## 17. DomU Execution

```shell
(Dom0)$ /etc/init.d/xencommons start
(Dom0)$ brctl addbr xenbr0
(Dom0)$ brctl addif xenbr0 eth0
(Dom0)$ ifconfig xenbr0 192.168.0.150 up
(Dom0)$ ifconfig eth0 0.0.0.0 up
(Dom0)$ route add default gw 192.168.0.1 xenbr0
```

Start xencommons and create a bridge.

```shell
(Dom0)$ losetup /dev/loop0 rootfs_DomU_01.img                                           
(Dom0)$ xl create DomU_01.cfg
(Dom0)$ losetup /dev/loop1 rootfs_DomU_02.img                                           
(Dom0)$ xl create DomU_02.cfg
```

Execute DomU.

## 18. References

* [http://wiki.xenproject.org/wiki/Xen_ARMv7_with_Virtualization_Extensions/Arndale](http://wiki.xenproject.org/wiki/Xen_ARMv7_with_Virtualization_Extensions/Arndale)
* [http://wiki.xenproject.org/wiki/Xen_ARMv7_with_Virtualization_Extensions#Building_Xen_on_ARM](http://wiki.xenproject.org/wiki/Xen_ARMv7_with_Virtualization_Extensions#Building_Xen_on_ARM)
* [http://wiki.xenproject.org/wiki/Xen_ARM_with_Virtualization_Extensions/CrossCompiling](http://wiki.xenproject.org/wiki/Xen_ARM_with_Virtualization_Extensions/CrossCompiling)
* [http://wiki.xenproject.org/wiki/Xen_ARM_with_Virtualization_Extensions/RootFilesystem](http://wiki.xenproject.org/wiki/Xen_ARM_with_Virtualization_Extensions/RootFilesystem)
* [https://wiki.linaro.org/Boards/Arndale/Setup/PXEBoot](https://wiki.linaro.org/Boards/Arndale/Setup/PXEBoot)
* [http://forum.falinux.com/zbxe/index.php?document_srl=518293&mid=lecture_tip](http://forum.falinux.com/zbxe/index.php?document_srl=518293&mid=lecture_tip)
* [http://badawave.tistory.com/entry/Xen-ARM-with-Virtualization-ExtensionsArndale](http://badawave.tistory.com/entry/Xen-ARM-with-Virtualization-ExtensionsArndale)
* [http://lists.xen.org/archives/html/xen-users/2012-03/msg00325.html](http://lists.xen.org/archives/html/xen-users/2012-03/msg00325.html)

