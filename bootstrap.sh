#!/bin/bash -ex

ARCH="${ARCH:-armhf}"

if [ "$ARCH" = armhf ] ; then
  # workaround for building on 64-bit host (https://github.com/RPi-Distro/pi-gen/issues/271),
  # also see https://github.com/RPi-Distro/pi-gen/pull/307
  dpkg --add-architecture i386
fi

# Bring system current
apt-get update

# Install required pi-gen dependencies
qemu_package=qemu-user-static:i386
if [ "$ARCH" = aarch64 ] ; then
  qemu_package=qemu-user-static
fi

apt-get install -y coreutils quilt parted $qemu_package debootstrap zerofree zip \
  dosfstools libarchive-tools libcap2-bin grep rsync xz-utils file git curl bc \
  qemu-utils kpartx

mkdir -p /home/vagrant/pi-cloud-init
