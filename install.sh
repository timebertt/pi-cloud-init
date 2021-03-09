#!/bin/bash -ex

# go to home
cd

if [ -d pi-gen ] ; then
    echo "found pi-gen, skipping clone"
else
    echo "cloning pi-gen"

    git clone https://github.com/RPi-Distro/pi-gen.git
    pushd pi-gen
    chmod +x build.sh
    popd
fi
 
# Bring system current
sudo apt-get update

# Install required pi-gen dependencies
sudo apt-get -y install coreutils quilt parted qemu-user-static debootstrap zerofree zip \
    dosfstools libarchive-tools libcap2-bin grep rsync xz-utils file git curl bc \
    qemu-utils kpartx

