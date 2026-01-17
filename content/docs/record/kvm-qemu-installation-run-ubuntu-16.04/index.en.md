---
title: KVM, QEMU Installation and Execution / Ubuntu 14.04 Environment
---

## 1. Installation and Execution Environment

The installation and execution environment is as follows.
* Hardware: Intel i5-6500, DDR4 8GB
* OS: Ubuntu 14.04.03 LTS 64bit, root user

## 2. Ubuntu Package Installation

```shell
$ apt-get install qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils uml-utilities qemu-system qemu-user-static virt-manager libncurses-dev targetcli
```

Install Ubuntu packages related to running KVM and QEMU.

## 3. VM Kernel Build

```shell
$ mkdir kernel
$ cd kernel
```

Create a kernel directory.

```shell
$ apt-get source linux-image-$(uname -r)
$ apt-get build-dep linux-image-$(uname -r)
```

Download the kernel and install packages related to kernel building.

```shell
$ cd linux-lts-vivid-3.19.0
$ cp /boot/config-3.19.0-25-generic .config
$ make ARCH=x86-64 menuconfig
[Device Driver -> SCSI device support -> SCSI low-level drivers -> <*> virtio-scsi support]
```

Enable virtio-scsi through kernel configuration modification.

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

Build the kernel.

## 4. VM Rootfs Creation

```shell
$ mkdir rootfs
$ cd rootfs
```

Create the VM rootfs directory.

```shell
$ dd if=/dev/zero bs=1M count=8092 of=rootfs.img
$ /sbin/mkfs.ext4 rootfs.img (Proceed anyway? (y,n) y)
```

Create the rootfs.img file.

```shell
$ mount -o loop rootfs.img /mnt
$ cd /mnt
$ qemu-debootstrap --arch=amd64 trusty .
```

Install Ubuntu on rootfs.img.

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

Configure the default tty for the VM. Modify the etc/init/ttyS0.conf file mounted on mnt as shown in [File 1].

```text {caption="[File 2] etc/network/interfaces", linenos=table}
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
```

Configure the VM network. Modify the etc/network/interfaces file mounted on mnt as shown in [File 2].

```shell
$ /mnt
$ chroot .
(chroot) # passwd
(chroot) # exit
```

Set the VM root password.

```shell
$ cd kernel/linux-lts-vivid-3.19.0
$ make ARCH=x86-64 INSTALL-MOD-PATH=/mnt modules-install
```

Install kernel modules on rootfs.img.

```shell
$ umount /mnt
```

Unmount to complete rootfs.img creation.

## 5. Bridge Configuration

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

Create the ~/VM/set-bridge.sh script file for bridge configuration with the content from [File 3].

## 6. LIO Configuration

```shell
$ apt-get install targetcli
$ vim /var/target/fabric/vhost.spec
```

Install the LIO package for vhost-scsi.

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

Configure LIO for vhost-scsi. Set the /var/target/fabric/vhost.spec file as shown in [File 4].

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

Configure LIO using the LIO CLI.

{{< figure caption="[Figure 1] LIO Configuration Result" src="images/lio-targetcli.png" width="900px" >}}

[Figure 1] shows the LIO configuration result.

## 7. VM Execution

```shell
$ cd VM
$ cp ../../kernel/linux-lts-vivid-3.19.0/arch/x86-64/boot/bzImage
$ cp ../../rootfs/rootfs.img
```

Copy the created rootfs.img and bzImage for the VM.

### 7.1. KVM + QEMU

```shell
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -hda rootfs.img -net nic -net user -append "earlyprintk root=/dev/sda console=ttyS0"
```

Create a VM using User Networking (SLIRP).

### 7.2. KVM + QEMU + VirtIO

```shell
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -device virtio-blk-pci,scsi=off,drive=blk0 -device virtio-net-pci,netdev=net0 -drive file=rootfs.img,if=none,id=blk0 -netdev user,id=net0 -append "earlyprintk root=/dev/vda console=ttyS0"
```

Create a VM using User Networking (SLIRP), virtio-net, and virtio-blk.

```shell
$ ./set-bridge.sh
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -device virtio-blk-pci,scsi=off,drive=blk0 -device virtio-net-pci,netdev=net0 -drive file=rootfs.img,if=none,id=blk0 -netdev tap,id=net0,ifname=tap0 -append "earlyprintk root=/dev/vda console=ttyS0"
```

Create a VM using TAP, virtio-net, and virtio-blk.

```shell
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -device virtio-scsi-pci -device scsi-hd,drive=root -device virtio-net-pci,netdev=net0 -drive file=rootfs.img,if=none,format=raw,id=root -netdev user,id=net0 -append "earlyprintk root=/dev/sda console=ttyS0"
```

Create a VM using User Networking (SLIRP), virtio-net, and virtio-scsi.

```shell
$ ./set-bridge.sh
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -device virtio-scsi-pci -device scsi-hd,drive=root -device virtio-net-pci,netdev=net0 -drive file=rootfs.img,if=none,format=raw,id=root -netdev tap,id=net0,ifname=tap0 -append "earlyprintk root=/dev/sda console=ttyS0"
```

Create a VM using TAP, virtio-net, and virtio-scsi.

### 7.3. KVM + QEMU + VirtIO + vhost

```shell
$ ./set-bridge.sh
$ qemu-system-x86-64 -enable-kvm -kernel bzImage -m 1024 -nographic -device vhost-scsi-pci,wwpn=naa.60014052cc816bf4 -device virtio-net-pci,netdev=net0 -netdev tap,id=net0,vhost=on,ifname=tap0 -append "earlyprintk root=/dev/sda console=ttyS0"
```

Create a VM using TAP, virtio-net+vhost, and virtio-scsi+vhost-scsi.

## 8. fstab Configuration

```shell
* Stopping log initial device creation                                  [ OK ]
The disk drive for / is not ready yet or not present.
keys:Continue to wait, or Press S to skip mounting or M for manual recovery (Push M)
```

To resolve the rootfs mount issue after VM booting, access the shell using the following method.

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

Check blkid from the shell and configure fstab with the content from [File 1].

## 9. References

* Kernel Compile: [https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1460768]( https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1460768)
* QEMU Option: [https://wiki.gentoo.org/wiki/QEMU/Options]( https://wiki.gentoo.org/wiki/QEMU/Options)
* fstab Problem: [ http://askubuntu.com/questions/392720/the-disk-drive-for-tmp-is-not-ready-yet-s-to-skip-mount-or-m-for-manual-recove]( http://askubuntu.com/questions/392720/the-disk-drive-for-tmp-is-not-ready-yet-s-to-skip-mount-or-m-for-manual-recove)
* LIO Targetcli: [http://linux-iscsi.org/wiki/Targetcli](http://linux-iscsi.org/wiki/Targetcli)

