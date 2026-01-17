---
title: KVM, QEMU Installation and Execution / Arndale Environment
---

## 1. Installation and Execution Environment

The installation and execution environment is as follows.
* Arndale Board, 8GB uSD
* PC: Ubuntu 14.04LTS 32bit, root User
* VM on KVM: Ubuntu 14.04LTS 32bit, root User
* Cross compiler: arm-linux-gnueabihf-4.9.3
* Network 192.168.0.xxx (NAT)
  * HostOS: 192.168.0.150
  * br0: 192.168.0.200
  * GeustOS-01: 192.168.0.160, GeustOS-02: 192.168.0.161
  * tap0: 192.168.0.201, tap1: 192.168.0.202

## 2. Cross Compiler Installation

Install a cross compiler for kernel building.
* Download: https://releases.linaro.org/15.02/components/toolchain/binaries/arm-linux-gnueabihf/gcc-linaro-4.9-2015.02-3-x86-64-arm-linux-gnueabihf.tar.xz


```text {caption="[File 1] ~/.bashrc", linenos=table}
...
PATH=$PATH:/usr/local/gcc-linaro-arm-linux-gnueabihf-4.8/bin
```

Extract to the /usr/local directory and add the content from [File 1] to the ~/.bashrc file so that the cross compiler can be used from any directory.

## 3. Ubuntu Package Installation

```shell
$ apt-get install gcc-arm-linux-gnueabi
$ apt-get install build-essential git u-boot-tools qemu-user-static libncurses5-dev
```

Install Ubuntu packages required for kernel building.

## 4. Kernel Config Download

Download the kernel config.
* Login: http://www.virtualopensystems.com/
* Guest Kernel Config: http://www.virtualopensystems.com/downloads/guides/kvm-virtualization-on-arndale/guest-config

## 5. Host Kernel and Host dtb Build

```shell
$ wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.18.3.tar.xz
$ tar xvf linux-3.18.3.tar.xz
$ mv Kernel-Host
```

Download the Host Kernel.

```shell
$ cd Kernel-Host
$ make ARCH=arm exynos-defconfig
$ make ARCH=arm menuconfig

 -> Kernel hacking -> [*] Kernel low-level debugging functions (read help!) -> Use Samsung S3C UART 2 for low-level debug
                   -> [*] Early printk
 -> Device Driver -> Generic Driver Options 
                  -> [*] Maintain a devtmpfs filesystem to mount at /dev
                  -> [*]  Automount devtmpfs at /dev, after the kernel mounted to the rootfs
 -> System Type -> [*] Support for the Large Physical Address Extension [*] 
 -> [*] Virtualization -> [*] Kernel-based Virtual Machine (KVM) support
 -> Device Drivers -> Virtio Drivers -> <*> Platform bus driver for memory mapped virtio devices
                                     -> <*> Virtio ballon driver
                                     -> [*] Memory mapped virtio devices parameter parsing
                   -> Block Drivers -> <*> Virtio block driver
                   -> Network device support -> <*> Universal TUN/TAP device driver support
                                             -> <*> Virtio network driver
 -> Networking support -> Networking options-> [M] 802.1d Ethernet Bridging

$ make ARCH=arm CROSS-COMPILE=arm-linux-gnueabihf- LOADADDR=0x40008000  uImage
$ make ARCH=arm CROSS-COMPILE=arm-linux-gnueabihf- dtbs
$ make ARCH=arm CROSS-COMPILE=arm-linux-gnueabihf- modules
$ make ARCH=arm CROSS-COMPILE=arm-linux-gnueabihf- INSTALL-MOD-PATH=. modules-install
```

Build the Host Kernel.

## 6. Guest Kernel and Guest dtb Build

```shell
$ wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.18.3.tar.xz
$ tar xvf linux-3.18.3.tar.xz
$ mv Kernel-Guest
```

Download the Guest Kernel.

```shell
$ cd Kernel-Guest
$ cp ../guest-config .config
$ make ARCH=arm menuconfig
 -> Device Driver -> Generic Driver Options -> [*] Maintain a devtmpfs filesystem to mount at /dev
                                            -> [*]  Automount devtmpfs at /dev, after the kernel mounted to the rootfs
$ make ARCH=arm CROSS-COMPILE=arm-linux-gnueabihf-
$ cp arch/arm/boot/dts/armvexpress-v2p-ca15-tc1.dtb arch/arm/boot/dts/guest-vexpress.dtb
```

Build the Guest Kernel.

## 7. u-boot Build

```shell
$ git clone git://github.com/virtualopensystems/u-boot-arndale.git Arndale-u-boot
$ cd Arndale-u-boot
$ make ARCH=arm CROSS-COMPILE=arm-linux-gnueabihf- arndale5250
```

Build u-boot.

## 8. Basic Root Filesystem Image Creation

```shell
$ mkdir rootfs
$ cd rootfs
$ dd if=/dev/zero bs=1M count=700 of=rootfs.img
$ /sbin/mkfs.ext3 rootfs.img (Proceed anyway? (y,n) y)
$ mount -o loop rootfs.img /mnt
```

Create a Rootfs image file.

```shell
$ cd /mnt
$ qemu-debootstrap --arch=armhf trusty .
```

Configure the basic rootfs using debootstrap.

```shell
$ vim etc/apt/sources.list
  -> deb http://ports.ubuntu.com/ trusty main restricted universe
  -> deb-src http://ports.ubuntu.com/ trusty main restricted universe
$ cp etc/init/tty1.conf etc/init/ttySAC2.conf
$ vim etc/init/ttySAC2.conf
  -> change all 'tty1' to 'ttySAC2'
  -> change '38400' to '115200'
$ cp etc/init/tty1.conf etc/init/ttyAMA0.conf
$ vim etc/init/ttyAMA0.conf
  -> change all 'tty1' to 'ttyAMA0'
$ vim etc/securetty
  -> add 'ttySAC2'
$ vim etc/network/interfaces
  -> 'auto eth0
      iface eth0 inet dhcp'
```

Configure the rootfs.

```shell
$ chroot .
(chroot)$ passwd
(chroot)$ exit
$ umount /mnt
```

Set the root password.

## 9. Host Root Filesystem Configuration

```shell
$ cp rootfs.img rootfs-host.img
$ mount -o loop rootfs-host.img /mnt
$ vi /mnt/etc/hostname
  -> host
$ cp -R ../Kernel-Host/lib/modules /mnt/lib
$ umount /mnt
```

Create the Host root filesystem using the created basic rootfs.

## 10. Guest-01 Root Filesystem Configuration

```shell
$ cp rootfs.img rootfs-guest-01.img
$ mount -o loop rootfs-guest-01.img /mnt
$ echo guest01 > /mnt/etc/hostname
$ cat << EOF > /mnt/etc/network/interfaces
auto eth0
iface eth0 inet static
address 192.168.0.160
netmask 255.255.255.0
gateway 192.168.0.1
dns-nameservers 8.8.8.8
$ umount /mnt
```

Create Guest 01's root filesystem using the created basic rootfs.

## 11. Guest-02 Root Filesystem Configuration

```shell
$ cp rootfs.img rootfs-guest-02.img
$ mount -o loop rootfs-guest-02.img /mnt
$ echo guest02 > /mnt/etc/hostname
$ cat << EOF > /mnt/etc/network/interfaces
auto eth0
iface eth0 inet static
address 192.168.0.161
netmask 255.255.255.0
gateway 192.168.0.1
dns-nameservers 8.8.8.8'
EOF
$ umount /mnt
```

Create Guest 02's root filesystem using the created basic rootfs.

## 12. QEMU Build

```shell
$ apt-get install xapt
$ cat << EOF >> /etc/apt/sources.list.d/armel-precise.list
deb [arch=armel] http://ports.ubuntu.com/ubuntu-ports precise main restricted universe multiverse
deb-src [arch=armel] http://ports.ubuntu.com/ubuntu-ports precise main restricted universe multiverse
EOF
$ xapt -a armel -m -b zlib1g-dev libglib2.0-dev libfdt-dev libpixman-1-dev
$ dpkg -i /var/lib/xapt/output/*.deb
$ apt-get install pkg-config-arm-linux-gnueabi
$ git clone git://github.com/virtualopensystems/qemu.git
$ cd qemu
$ git checkout origin/kvm-arm-virtio-fb-hack -b virtio
$ ./configure --cross-prefix=arm-linux-gnueabi- --target-list=arm-softmmu --audio-drv-list="" --enable-fdt --enable-kvm --static
$ make
```

Build QEMU.

## 13. uSD Card Partition Configuration

Configure the uSD Card partitions as follows.
* 0 ~ 2M, 2M, No Filesystem: Bootloader (bl1, spl, U-boot)
* 2M ~ 18M, 16M, ext2, boot: uImage, exynos5250-arndale.dtb
* 18M ~ rest, ext3, root: Root-Filesystem

## 14. u-boot Fusing to uSD Card

```shell
$ cd Arndale-u-boot
$ wget http://www.virtualopensystems.com/downloads/guides/kvm-virtualization-on-arndale/arndale-bl1.bin
$ dd if=arndale-bl1.bin of=/dev/sdb bs=512 seek=1
$ dd if=spl/smdk5250-spl.bin of=/dev/sdb bs=512 seek=17
$ dd if=u-boot.bin of=/dev/sdb bs=512 seek=49
```

Fuse u-boot to the uSD Card.

## 15. Host Root Filesystem Copy

```shell
$ mount -o loop rootfs-host.img /mnt
$ cd /mnt
$ cp -a * (MicroSD root Partition)
$ sync
```

Copy the Host root filesystem to the uSD Card.

## 16. Binary, Image, dtb Copy

Copy Host Kernel uImage and exynos5250-arndale.dtb files to the uSD Card boot partition. Copy Host Guest zImage, qemu-system-arm, rootfs-host.img, rootfs-guest-01.img, rootfs-guest-02.img, guest-vexpress.dtb files to the root partition.

## 17. u-boot Configuration

```shell
(u-boot)$ setenv kernel-addr-r 0x40007000
(u-boot)$ setenv dtb-addr-r 0x42000000
(u-boot)$ setenv bootcmd 'ext2load mmc 0:1 $kernel-addr-r /uImage; ext2load mmc 0:1 $dtb-addr-r /exynos5250-arndale.dtb; bootm $kernel-addr-r - $dtb-addr-r'
(u-boot)$ setenv bootargs 'root=/dev/mmcblk1p2 rw rootwait earlyprintk console=ttySAC2,115200n8 --no-log'
(u-boot)$ save
```

Configure u-boot.

## 18. Host Package Configuration

```shell
(Host)$ apt-get update (Host)$ apt-get install gcc make ssh xorg fluxbox tightvncserver (Host)$ apt-get install libsdl-dev libfdt-dev bridge-utils uml-utilities
```

After inserting the uSD Card into the Arndale Board and booting the Host, install packages for running Guests on the Host.

## 19. Bridge Configuration on Host

```shell
(Host)$ brctl addbr br0
(Host)$ brctl addif br0 eth0
(Host)$ ifconfig br0 192.168.0.150 up
(Host)$ ifconfig eth0 0.0.0.0 up
(Host)$ route add default gw 192.168.0.1
```

Configure a bridge for Guests on the Host.

## 20. Access Host via VNC

```shell
(Host)$ tightvncserver -nolisten tcp :1
```

Run the VNC Server on the Host. Access 192.168.0.150:1 via a VNC Client.

## 21. Guest Execution

```shell
(Host)$ tunctl -u root
(Host)$ ifconfig tap0 192.168.0.200 up
(Host)$ brctl addif br0 tap0
(Host)$ ./qemu-system-arm \
	-enable-kvm -kernel guest-zImage \
	-nographic -dtb ./guest-vexpress.dtb \
	-m 512 -M vexpress-a15 -cpu cortex-a15 \
	-netdev type=tap,id=net0,script=no,downscript=no,ifname="tap0" \
	-device virtio-net,transport=virtio-mmio.1,netdev=net0 \
	-device virtio-blk,drive=virtio-blk,transport=virtio-mmio.0 \
	-drive file=./rootfs-guest-01.img,id=virtio-blk,if=none \
	-append "earlyprintk console=ttyAMA0 mem=512M root=/dev/vda rw --no-log virtio-mmio.device=1M@0x4e000000:74:0 virtio-mmio.device=1M@0x4e100000:75:1"
```

```shell
 (Host)$ tunctl -u root
 (Host)$ ifconfig tap1 192.168.0.201 up
 (Host)$ brctl addif br0 tap1
 (Host)$ ./qemu-system-arm \
	-enable-kvm -kernel guest-zImage \
	-nographic -dtb ./guest-vexpress.dtb \
	-m 512 -M vexpress-a15 -cpu cortex-a15 \
	-netdev type=tap,id=net0,script=no,downscript=no,ifname="tap1" \
	-device virtio-net,transport=virtio-mmio.1,netdev=net0 \
	-device virtio-blk,drive=virtio-blk,transport=virtio-mmio.0 \
	-drive file=./rootfs-guest-02.img,id=virtio-blk,if=none \
	-append "earlyprintk console=ttyAMA0 mem=512M root=/dev/vda rw --no-log virtio-mmio.device=1M@0x4e000000:74:0 virtio-mmio.device=1M@0x4e100000:75:1"
```

Execute each Guest from the VNC Shell.

## 22. References

* [http://www.virtualopensystems.com/en/solutions/guides/kvm-virtualization-on-arndale](http://www.virtualopensystems.com/en/solutions/guides/kvm-virtualization-on-arndale)

