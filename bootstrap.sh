#!/bin/bash -ex

# workaround for building on 64-bit host (https://github.com/RPi-Distro/pi-gen/issues/271),
# also see https://github.com/RPi-Distro/pi-gen/pull/307
dpkg --add-architecture i386

# Bring system current
apt-get update

# Install required pi-gen dependencies
apt-get install -y coreutils quilt parted qemu-user-static:i386 debootstrap zerofree zip \
  dosfstools libarchive-tools libcap2-bin grep rsync xz-utils file git curl bc \
  qemu-utils kpartx

mkdir -p /home/vagrant/pi-cloud-init
