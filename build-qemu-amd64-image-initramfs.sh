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
mkdir -p bin dev etc lib mnt proc sbin sys tmp var # Create minimal root directory structure
cp "$DOWNLOADS"/$BUSYBOX/_install/* -a .             # Install Busybox in root directory structure
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

# Create initramfs filesystem
printLnYel "Creating initramfs..."
cd "$INSTALL"/root || exitScript
find . | cpio -ov --format=newc | gzip -9 >"$INSTALL"/initramfz
printLnGrn "Creating initramfs done"

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

# Run Qemu with kernel and initramfs specified
printLnYel "Running in QEMU..."
cd "$CPWD" || exitScript
qemu-system-x86_64 -nographic -m 512 -append "console=ttyS0" -kernel "$INSTALL"/$KERNEL -initrd "$INSTALL"/initramfz
printLnGrn "Running in QEMU done"

# Exit this script
exitScript
