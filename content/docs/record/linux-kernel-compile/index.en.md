---
title: Linux Kernel Compile
---

## 1. Compile

### 1.1. Clean

* make clean: Deletes most files generated during build except the .config file. The .config file is the config file used in previous kernel compilation.
* make mrproper: Deletes all files generated during build including the .config file and config-related backup files.
* make distclean: Performs mrproper and additionally deletes editor backup files and patch files.

### 1.2. Configuration

* make config: Sets config in a question-and-answer format.
* make menuconfig: Sets config using an Ncurses (Text)-based GUI. When using a config file from a previous kernel version, if additional settings are needed, they are set to default values.
* make xconfig: Sets config using a QT (X-Window)-based GUI. When using a config file from a previous kernel version, if additional settings are needed, they are set to default values.
* make oldconfig: Uses an existing .config file. When using a config file from a previous kernel version, if additional settings are needed, it asks the user for configuration methods in a question-and-answer format.

### 1.3. Build

* make zImage: Compiles the kernel and creates a compressed zImage file.
* make uImage: Creates a zImage file and then creates a uImage file used by u-boot. The mkimage tool must be installed. On Ubuntu, install the uboot-mkimage package.
* make modules: Compiles modules.

### 1.4. Install

* make install: Creates an initrd image, copies vmlinuz and System.map files to /boot, creates symbolic links, and modifies grub.conf appropriately so that it can boot with the new kernel image.
* make modules-install: Stores compiled modules in the $INSTALL-MOD-PATH/lib/modules/[kernel version] folder. You can change the copy location by setting the $INSTALL-MOD-PATH variable in the shell. If $INSTALL-MOD-PATH is not set, they are copied under the lib folder of /(root).

### 1.5. E.T.C

* make tags: Creates ctags files.
* make cscope: Creates cscope files.
* make help: Shows make targets and descriptions.

## 2. Example

### 2.1. ARM

```shell
$ ARCH=arm CROSS-COMPILE=arm-linux-gnueabi- make menuconfig
$ ARCH=arm CROSS-COMPILE=arm-linux-gnueabi- make zImage
$ ARCH=arm CROSS-COMPILE=arm-linux-gnueabi- make uImage
$ ARCH=arm CROSS-COMPILE=arm-linux-gnueabi- make modules
$ ARCH=arm CROSS-COMPILE=arm-linux-gnueabi- INSTALL-MOD-PATH=tmp make modules-install
```

