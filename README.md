# qemu_linux_amd64

## Overview
Provides scripts to create and run AMD64 Linux filesystem image using QEMU. There are two scripts for two slightly different approaches. The first approach builds an initramfs filesystem and is started with a seperate kernel (outside of the filesystem). The second approach builds a full image with msdos partition with grub bootloader and ext4 partition with filesystem containing the kernel. Both approaches build and install busybox for core utilities and use and init file to mount devices and run a "Hello world!" shell script after startup. The scripts are tested on Ubuntu 20.04.

#### _makefile_
The makefile, along with the make utility, simplifies repetitive development and user tasks as follows:
* `make install`   - Install shellcheck static analyzer for shell scripts
* `make initramfs` - Build AMD64 Linux initramfs filesystem and run it on Qemu
* `make hda`       - Build AMD64 Linux image with mdos partition with grub bootloader and ext4 partition with filesystem and kernel
* `make test`      - Run shellcheck static analyzer

#### build-qemu-amd64-image-initramfs.sh
 - Builds AMD64 Linux initramfs filesystem
 - Create basic root filesystem directory structure
 - Build Busybox from scratch and install onto root filesystem
 - Install init and hello world scripts onto root filesystem
 - Create initramfs cpio archive
 - Download and extract pre-build kernel
 - Run QEMU with kernel and initramfs filesystem

#### build-qemu-amd64-image-hda.sh
 - Builds AMD64 Linux initramfs filesystem
 - Create basic root filesystem directory structure
 - Build Busybox from scratch and install onto root filesystem
 - Copy init and hello world scripts onto root filesystem
 - Download and extract pre-build kernel onto root filesystem 
 - Create 512 MB raw image
 - Partition the image to have mdos partition and ext4 partition
 - Mount msdos and ext4 partitions
 - Install grub bootloader onto msdos partition
 - Install grub configuration on ext4 partition
 - Copy root filesystem onto mounted ext4 partition
 - Run QEMU with kernel and initramfs filesystem
