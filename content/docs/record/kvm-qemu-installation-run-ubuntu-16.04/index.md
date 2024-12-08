---
title: KVM, QEMU 설치, 실행 / Ubuntu 14.04 환경
---

## 1. 설치, 실행 환경

설치, 실행 환경은 다음과 같다.
* Hardware : Intel i5-6500, DDR4 8GB
* OS : Ubuntu 14.04.03 LTS 64bit, root user

## 2. Ubuntu Package 설치

```shell
$ apt-get install qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils uml-utilities qemu-system qemu-user-static virt-manager libncurses-dev targetcli
```

KVM, QEMU 구동 관련 Ubuntu Package를 설치한다.

## 3. VM Kernel Build

```shell
$ mkdir kernel
$ cd kernel
```

Kernel Directory 생성한다.

```shell
$ apt-get source linux-image-$(uname -r)
$ apt-get build-dep linux-image-$(uname -r)
```

Kernel Download 및 Kernel Build 관련 Package를 설치한다.

```shell
$ cd linux-lts-vivid-3.19.0
$ cp /boot/config-3.19.0-25-generic .config
$ make ARCH=x86-64 menuconfig
[Device Driver -> SCSI device support -> SCSI low-level drivers -> <*> virtio-scsi support]
```

Kernel Configuration 수정을 통해서 virtio-scsi를 활성화 한다.

```shell
$ cd linux-lts-vivid-3.19.0/ubuntu/vbox/vboxguest
$ ln -s ../include/
$ ln -s ../r0drv/
$ cd linux-lts-vivid-3.19.0/ubuntu/vbox/vboxsf
$ ln -s ../include/
$ cd linux-lts-vivid-3.19.0/ubuntu/vbox/vboxvideo
$ ln -s ../include/
$ cd kernel/linux-lts-vivid-3.19.0
$ make ARCH=x86-64
```

Kernel을 Build한다.

## 4. VM Rootfs 생성

```shell
$ mkdir rootfs
$ cd rootfs
```

VM의 Rootfs Directory를 생성한다.

```shell
$ dd if=/dev/zero bs=1M count=8092 of=rootfs.img
$ /sbin/mkfs.ext4 rootfs.img (Proceed anyway? (y,n) y)
```

rootfs.img 파일을 생성한다.

```shell
$ mount -o loop rootfs.img /mnt
$ cd /mnt
$ qemu-debootstrap --arch=amd64 trusty .
```

rootfs.img에 Ubuntu를 설치한다.

```text {caption="[File 1] etc/init/ttyS0.conf", linenos=table}
# ttyS0 - getty
#
# This service maintains a getty on ttyS0 from the point the system is
# started until it is shut down again.

start on stopped rc RUNLEVEL=[2345] and (
            not-container or
            container CONTAINER=lxc or
            container CONTAINER=lxc-libvirt)

stop on runlevel [!2345]

respawn
exec /sbin/getty -8 115200 ttyS0
```

VM이 이용할 기본 tty를 설정한다. mnt에 Mount된 etc/init/ttyS0.conf 파일을 [File 1]과 같이 수정한다.

```text {caption="[File 2] etc/network/interfaces", linenos=table}
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
```

VM의 Network를 설정한다. mnt에 Mount된 etc/network/interfaces 파일을 [File 2]와 같이 수정한다.

```shell
$ /mnt
$ chroot .
(chroot) # passwd
(chroot) # exit
```

VM의 root Password를 설정한다. 

```shell
$ cd kernel/linux-lts-vivid-3.19.0
$ make ARCH=x86-64 INSTALL-MOD-PATH=/mnt modules-install
```

rootfs.img에 Kernel module을 설치한다.

```shell
$ umount /mnt
```

Unmount를 수행하여 rootfs.img 생성을 마무리한다.

## 5. Bridge 설정

```shell
$ mkdir VM
$ cd VM
$ vim set-bridge.sh
```

```shell {caption="[File 3] ~/VM/set-bridge.sh", linenos=table}
brctl addbr br0
brctl addif br0 eth0
ifconfig br0 192.168.77.100 up
ifconfig eth0 0.0.0.0 up
route add default gw 192.168.77.1
PATH=$PATH:/usr/local/gcc-linaro-arm-linux-gnueabihf-4.8/bin
```

```shell
$ chmod +x set-bridge.sh
```

Bridge 설정을 위한 ~/VM/set-bridge.sh Script 파일을 [File 3]의 내용으로 생성한다.

## 6. LIO 설정

```shell
$ apt-get install targetcli
$ vim /var/target/fabric/vhost.spec
```

vhost-scsi를 위한 LIO Package를 설치한다.

```text {caption="[File 4] /var/target/fabric/vhost.spec", linenos=table}
# The fabric module feature set
features = nexus, tpgts

# Use naa WWNs.
wwn-type = naa

# Non-standard module naming scheme
#kernel-module = tcm-vhost
kernel-module = vhost-scsi

# The configfs group
configfs-group = vhost
```

vhost-scsi를 위한 LIO를 설정한다. /var/target/fabric/vhost.spec 파일을 [File 4]와 같이 설정한다.

```shell
$ reboot now
$ targetcli
(targetcli) /> cd backstores/fileio
(targetcli) /> create name=file-backend file-or-dev=[Absolute Path of rootfs.img] size=8G
(targetcli) /> cd /vhost
(targetcli) /> create wwn=naa.60014052cc816bf4
(targetcli) /> cd naa.60014052cc816bf4/tpgt1/luns
(targetcli) /> create /backstores/fileio/file-backend
(targetcli) /> cd /
(targetcli) /> saveconfig
(targetcli) /> exit
```

LIO CLI를 이용하여 LIO를 설정한다.

{{< figure caption="[Figure 1] LIO 설정 결과" src="images/lio-targetcli.png" width="900px" >}}

[Figure 1]은 LIO 설정 결과를 나타내고 있다.

## 7. VM 실행

```shell
$ cd VM
$ cp ../../kernel/linux-lts-vivid-3.19.0/arch/x86-64/boot/bzImage
$ cp ../../rootfs/rootfs.img
```

VM을 위해서 생성한 rootfs.img, bzImage를 복사한다.

### 7.1. KVM + QEMU

```shell
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -hda rootfs.img -net nic -net user -append "earlyprintk root=/dev/sda console=ttyS0"
```

User Networking (SLIRP)을 이용하여 VM을 생성한다.

### 7.2. KVM + QEMU + VirtIO

```shell
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -device virtio-blk-pci,scsi=off,drive=blk0 -device virtio-net-pci,netdev=net0 -drive file=rootfs.img,if=none,id=blk0 -netdev user,id=net0 -append "earlyprintk root=/dev/vda console=ttyS0"
```

User Networking (SLIRP), virtio-net, virtio-blk을 이용하여 VM을 생성한다.

```shell
$ ./set-bridge.sh
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -device virtio-blk-pci,scsi=off,drive=blk0 -device virtio-net-pci,netdev=net0 -drive file=rootfs.img,if=none,id=blk0 -netdev tap,id=net0,ifname=tap0 -append "earlyprintk root=/dev/vda console=ttyS0"
```

TAP, virtio-net, virtio-blk을 이용하여 VM을 생성한다.

```shell
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -device virtio-scsi-pci -device scsi-hd,drive=root -device virtio-net-pci,netdev=net0 -drive file=rootfs.img,if=none,format=raw,id=root -netdev user,id=net0 -append "earlyprintk root=/dev/sda console=ttyS0"
```

User Networking (SLIRP), virtio-net, virtio-scsi을 이용하여 VM을 생성한다.

```shell
$ ./set-bridge.sh
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -device virtio-scsi-pci -device scsi-hd,drive=root -device virtio-net-pci,netdev=net0 -drive file=rootfs.img,if=none,format=raw,id=root -netdev tap,id=net0,ifname=tap0 -append "earlyprintk root=/dev/sda console=ttyS0"
```

TAP, virtio-net, virtio-scsi을 이용하여 VM을 생성한다.

### 7.3. KVM + QEMU + VirtIO + vhost

```shell
$ ./set-bridge.sh
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -device vhost-scsi-pci,wwpn=naa.60014052cc816bf4 -device virtio-net-pci,netdev=net0 -netdev tap,id=net0,vhost=on,ifname=tap0 -append "earlyprintk root=/dev/sda console=ttyS0"
```

TAP, virtio-net+vhost, virtio-scsi+vhost-scsi을 이용하여 VM을 생성한다.

## 8. fstab 설정

```shell
* Stopping log initial device creation                                  [ OK ]
The disk drive for / is not ready yet or not present.
keys:Continue to wait, or Press S to skip mounting or M for manual recovery (Push M)
```

VM Booting 후 Rootfs Mount Issue를 해결하기 위해서 다음과 같은 방법으로 Shell에 접근한다. 

```shell
(VM) # mount -o remount,rw /
(VM) # blkid
(VM) /dev/sda: UUID="(UUID of blk)" TYPE="ext4"
(VM) # vi /etc/fstab
```

```text {caption="[File 1] VM /etc/fstab", linenos=table}
...
UUID=(UUID of blk) / ext4 errors=remount-ro 0 1
```

Shell에서 blkid 확인 및 [File 1]의 내용으로 fstab 설정을 진행한다.

## 9. 참조

* Kernel Compile : [https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1460768]( https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1460768)
* QEMU Option : [https://wiki.gentoo.org/wiki/QEMU/Options]( https://wiki.gentoo.org/wiki/QEMU/Options)
* fstab Problem : [ http://askubuntu.com/questions/392720/the-disk-drive-for-tmp-is-not-ready-yet-s-to-skip-mount-or-m-for-manual-recove]( http://askubuntu.com/questions/392720/the-disk-drive-for-tmp-is-not-ready-yet-s-to-skip-mount-or-m-for-manual-recove)
* LIO Targetcli : [http://linux-iscsi.org/wiki/Targetcli](http://linux-iscsi.org/wiki/Targetcli)
