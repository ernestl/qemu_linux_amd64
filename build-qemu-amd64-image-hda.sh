#!/bin/bash

### DEFINES ###

# Current user
USER=$(whoami)

# Full directory path where this file resides
CPWD="$( cd "$(dirname "$0")" || exit; pwd -P )"

# Downloads directory relative to current
DOWNLOADS="$CPWD/downloads"

# Configuration directory where pre-configuration are stored
CONFIGS="$CPWD/configs"

# Install directory relative to current
INSTALL="$CPWD/install"

# Print constants
P_RESET="\e[0m"
P_RED="\e[31m"
P_GREEN="\e[32m"
P_YELLOW="\e[33m"

### MACROS ###

# Exit sourced and non-sourced scripts
function exitScript() {
	if [ "x$SOURCED" == "x1" ]; then
		return 1
	else
		exit 1
	fi
}

# Print without newline
function print() {
	echo -ne "$P_RESET$*"
}

# Print with newline
function printLn() {
	echo -e "$P_RESET$*"
}

# Print new line only (blank line)
function printLnOnly() {
	echo -e "$P_RESET"
}

function printRed() {
	echo -ne "$P_RED$*$P_RESET"
}

function printYel() {
	echo -ne "$P_YELLOW$*$P_RESET"
}

function printGrn() {
	echo -ne "$P_GREEN$*$P_RESET"
}

function printLnRed() {
	echo -e "$P_RED$*$P_RESET"
}

function printLnYel() {
	echo -e "$P_YELLOW$*$P_RESET"
}

function printLnGrn() {
	echo -e "$P_GREEN$*$P_RESET"
}

run() {
	if $VERBOSE; then
		v=$(exec 2>&1 && set -x && set -- "$@")
		echo "#${v#*--}"
		"$@"
	else
		"$@" >/dev/null 2>&1
	fi
}

### SCRIPT ###

# Clear for fresh start
clear

# Display user
print "User: " 
printLnGrn "$USER"

# Enforce sudo
print "Sudo: " 

ID=$(id -u)
if [ "x$ID" == "x0" ]; then
	printLnGrn "YES"
else
	printLnRed "NO"
    printLnOnly
    printLnYel "NOTE: This script requires super user privilege - please run with sudo"
    printLnOnly
	exit 1
fi

printLnYel "Disabling automount..."
gsettings set org.gnome.desktop.media-handling automount false
printLnGrn "Disabling automount done"

# Update apt
printLnYel "Updating apt..."
apt-get update
printLnGrn "Update apt done"

# Install dependencies
printLnYel "Installing dependencies..."
apt-get install -y qemu-system-x86
printLnGrn "Installing dependencies done"

# Clean directory structure
printLnYel "Cleaning build directories..."
rm -rf "$DOWNLOADS"
rm -rf "$INSTALL"
printLnGrn "Cleaning done"

# Create directory structure
printLnYel "Creating build directories..."
mkdir -p "$DOWNLOADS"
mkdir -p "$INSTALL"
mkdir -p "$INSTALL"/root
printLnGrn "Creating done"

# Build Busybox based initramfs filesystem
printLnYel "Building and installing Busybox..."

# Download busybox
printLnYel "- Downloading Busybox..."
BUSYBOX="busybox-1.35.0"
BUSYBOX_URL="https://busybox.net/downloads/$BUSYBOX.tar.bz2"
cd "$DOWNLOADS" || exitScript
wget $BUSYBOX_URL -O $BUSYBOX.tar.bz2
tar -xjvf $BUSYBOX.tar.bz2
printLnGrn "- Downloading Busybox done"

# Build Busybox
printLnYel "- Building Busybox..."
cp "$CONFIGS"/busybox_defconfig "$DOWNLOADS"/$BUSYBOX/configs
cd "$DOWNLOADS"/$BUSYBOX || exitScript
make busybox_defconfig	# Make according to pre-configured config (statically linked option)
make -j"$(nproc)"		# Make with all cores
make install			# Create installation package in ./_install
printLnGrn "- Building Busybox done"

# Install Busybox
printLnYel "- Installing Busybox..."
cd "$INSTALL"/root || exitScript
mkdir -p bin dev etc lib mnt proc sbin sys tmp var	# Create minimal root directory structure
cp "$DOWNLOADS"/$BUSYBOX/_install/* -a .			# Install Busybox in root directory structure
printLnGrn "- Installing Busybox done"

printLnGrn "Building and installing Busybox done"

# Install initialization files
printLnYel "Installing initialization files..."
cd "$CPWD" || exitScript
cp "$CONFIGS"/init "$INSTALL"/root
chmod +x "$INSTALL"/root/init
cp "$CONFIGS"/hello-world.sh "$INSTALL"/root/bin
chmod +x "$INSTALL"/root/hello-world.sh
printLnGrn "Installing initialization files done"

# Download pre-built kernel (to save time)
printLnYel "Downloading pre-built AMD64 kernel..."
cd "$CPWD" || exitScript
KERNEL="vmlinuz-5.15.0-051500-generic"
KERNEL_URL="https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.15/amd64/linux-image-unsigned-5.15.0-051500-generic_5.15.0-051500.202110312130_amd64.deb"
wget $KERNEL_URL -O "$DOWNLOADS"/$KERNEL.deb
dpkg-deb -xv "$DOWNLOADS"/$KERNEL.deb "$DOWNLOADS"/$KERNEL/
printLnGrn "Downloading pre-built AMD64 kernel done"

# Install pre-built kernel
printLnYel "Installing prebuilt AMD64 kernel..."
cd "$CPWD" || exitScript
cp "$DOWNLOADS"/$KERNEL/boot/$KERNEL "$INSTALL"
printLnGrn "Installing prebuilt AMD64 kernel done"

printLnYel "Creating raw image..."

# Create and partition raw image
printLnYel "- Partitioning raw image..."
cd "$CPWD" || exitScript
IMAGE="amd64.img"
TMP_IMAGE="$DOWNLOADS"/."$IMAGE"
truncate -s512M "$TMP_IMAGE"
# Format image to have MBR partition (msdos) table on the first sector 
# image, as expected by bios
parted -s "$TMP_IMAGE" mktable msdos
# Use the rest of the image (starting at the first MiB) as
# the primary bootable partition
parted -s "$TMP_IMAGE" mkpart primary ext4 1 "100%"
parted -s "$TMP_IMAGE" set 1 boot on
printLnGrn "- Partitioning raw image done"

# Create two loopback devices
# First for msdos partition (actually whole image, but we only use the first part)
# Secondly for ext4 partition
printLnYel "- Creating loopbacks for msdos and ext4 partitions..."
IMAGE_LOOP_DEV=$(sudo losetup -Pf --show "$TMP_IMAGE")
partprobe "${IMAGE_LOOP_DEV}"
IMAGE_P1_LOOP_DEV="${IMAGE_LOOP_DEV}p1"
printLnGrn "- Creating loopbacks for msdos and ext4 partitions done"

printLnYel "- Formatting ext4 partition as ext4 filesystem..."
mkfs -t ext4 -v "${IMAGE_P1_LOOP_DEV}" # Create ext4 filesystem
sync
e2fsck -f -p "${IMAGE_P1_LOOP_DEV}"
RETURN=$?
if [ $RETURN -ne 0 ]; then
	printLnRed "FAIL"
	exitScript
fi
printLnGrn "- Formatting ext4 partition as ext4 filesystem done"

printLnYel "- Mounting ext4 partition and installing content..."

MOUNT_PATH="/tmp/mount"
mkdir -p $MOUNT_PATH
mount "${IMAGE_P1_LOOP_DEV}" $MOUNT_PATH	# Mount ext4 partition
cp "$INSTALL"/root/* -a $MOUNT_PATH			# Install root file structure containing Busybox
chown -R "$USER" $MOUNT_PATH
sync

printLnYel "-- Installing prebuilt AMD64 kernel..."
cd "$CPWD" || exitScript
mkdir -p "$MOUNT_PATH"/boot/grub
cp "$INSTALL"/$KERNEL "$MOUNT_PATH"/boot/
sync
printLnGrn "-- Installing prebuilt AMD64 kernel done"

printLnYel "-- Creating grub device map on ext4 partition..."
echo "(hd0) ${IMAGE_LOOP_DEV}" >"$MOUNT_PATH"/boot/grub/device.map
sync
printLnGrn "-- Creating grub device map on ext4 partition done"

printLnYel "-- Installing grub configuration on ext4 partition"
cp "$CONFIGS"/grub.cfg "$MOUNT_PATH"/boot/grub/
sync
printLnGrn "-- Installing grub configuration on ext4 partition"

printLnGrn "- Mounting ext4 partition and installing content done"

printLnYel "- Installing grub on msdos partition..."
grub-install \
  -v \
  --directory="$CONFIGS"/i386-pc \
  --boot-directory="$MOUNT_PATH"/boot \
  "${IMAGE_LOOP_DEV}" \
  2>&1
sync
printLnGrn "- Installing grub on msdos partition done"

printLnYel "Unmount ext4 partition and detach loopbacks..."
umount "$MOUNT_PATH"	         	# Unmount ext4 partition
run losetup -d "${IMAGE_LOOP_DEV}"	# Detach loop device
sync
printLnGrn "Unmount ext4 partition and detach loopbacks done"

printLnYel "Installing raw image..."
cp "$TMP_IMAGE" "$INSTALL"/$IMAGE
printLnGrn "Installing raw image done"

# Run Qemu with kernel and initramfs specified
printLnYel "Running in QEMU..."
cd "$CPWD" || exitScript
qemu-system-x86_64 -nographic -m 512 -hda "$INSTALL"/$IMAGE
printLnGrn "Running in QEMU done"

# Exit this script
exitScript
