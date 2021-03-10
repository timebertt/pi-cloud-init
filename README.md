# Minimal Raspberry Pi OS including cloud-init

This repo features a custom [Raspberry Pi OS Lite](https://www.raspberrypi.org/software/operating-systems/) image including [cloud-init](https://cloud-init.io/) built with [pi-gen](https://github.com/RPi-Distro/pi-gen).

## TL;DR: How to use the image

1. Download the image from GitHub:
    ```bash
    curl -sSL -o 2021-03-10-raspios-buster-armhf-lite-cloud-init.zip https://github.com/timebertt/gardener/releases/download/2021-03-10/2021-03-10-raspios-buster-armhf-lite-cloud-init.zip
    unzip -o 2021-03-10-raspios-buster-armhf-lite-cloud-init.zip
    ```

2. Mount the `boot` partition (of the `.img` file) to add `user-data`, `meta-data` and optionally `network-config` files to the root of it. Unmount it again, once added.
3. Flash image to SD card using [balena etcher](https://www.balena.io/etcher/), [Raspberry Pi Imager](https://www.raspberrypi.org/software/) or similar.
4. Insert SD card into Pi and power up! :rocket:

## Rationale

[Raspberry Pi OS](https://www.raspberrypi.org/software/operating-systems/) is fairly easy to setup. Though, if you want to setup a Raspberry Pi cluster like Alex Ellis and the community [have been doing for five years+](https://alexellisuk.medium.com/five-years-of-raspberry-pi-clusters-77e56e547875), you will have to repeat some manual configuration steps like copying SSH keys, networking setup and so on for each Pi.

[cloud-init](https://cloud-init.io/) is the de-facto standard for solving the same problem on cloud instances. It's baked into most cloud images, which makes cloud instances discover initialization and configuration data from the cloud provider's [metadata service](https://cloudinit.readthedocs.io/en/latest/topics/datasources.html).

cloud-init can be used for bootstrapping Raspberry Pis as well, making it easy to configure networking, packages and remote access consistently across a fleet of Pis. Unfortunately, Raspberry Pi OS doesn't ship with cloud-init out of the box and thus requires [manual installation and configuration](https://gist.github.com/RichardBronosky/fa7d4db13bab3fbb8d9e0fff7ea88aa2).

This repo features a custom image based on Raspberry Pi OS Lite built with [pi-gen](https://github.com/RPi-Distro/pi-gen) with cloud-init preinstalled, which allows to pass initialization and configuration data (in form of `meta-data`, `user-data` and `network-config` files) to Pis via the boot image flashed to an SD card. This makes it easy to bootstrap multiple Pis in a plug-and-play fashion without attaching a monitor or manually SSHing into each one of them.

**Why not simply use Ubuntu Server?**

[Ubuntu Server](https://ubuntu.com/download/raspberry-pi) comes with cloud-init preinstalled and also features a Raspberry Pi Image. It can be leveraged in a [similar fashion](https://gitlab.com/Bjorn_Samuelsson/raspberry-pi-cloud-init-wifi) to the image built by this project to bootstrap Pis. Though, in my tests Ubuntu Server already consumed more than `300MB` of precious memory on my Pis without anything installed. Therefore I started building a custom image based on Raspberry Pi OS Lite, which consumes only roughly `60MB` of memory out of the box.

## How to build the image

You can build the image yourself and customize the build along the way by following these steps.

1. Setup a Debian VM using [vagrant](https://www.vagrantup.com/) which will build the image. This provides a clean build environment and additionally works on a Linux as well as macOS.
    ```bash
    vagrant up
    ```

2. Start pi-gen build in the VM. This is going to take some time...
    ```
    vagrant ssh -c /home/vagrant/pi-cloud-init/build.sh
    ```

3. Transfer produced image to the host machine and unzip.
    This requires the `vagrant-scp` plugin, install it first by running:
    ```bash
    vagrant plugin install vagrant-scp
    ```
    ```bash
    zip_file=$(date +%Y-%m-%d)-raspios-buster-armhf-lite-cloud-init.zip
    vagrant scp raspios-builder:/home/vagrant/pi-cloud-init/$zip_file $zip_file
    unzip -o "$zip_file"
    ```

4. Customize `user-data.yaml`, `meta-data.yaml` and `network-config.yaml` for the instance you're setting up.

5. Mount boot partition to inject `user-data`, `meta-data` and `network-config`.
    (It's assuming a macOS machine, but you should be able to accomplish the same using `mount` and `umount` on Linux.)
    ```
    img_file="${zip_file%.zip}.img"
    volume="$(hdiutil mount "$img_file" | egrep -o '/Volumes/.+')"
    cp meta-data.yaml "$volume"/meta-data
    cp user-data.yaml "$volume"/user-data
    cp network-config.yaml "$volume"/network-config
    device="$(mount | grep "$volume" | cut -f1 -d' ' | egrep -o '/dev/disk.')"
    diskutil umountDisk "$device"
    diskutil eject "$device"
    ```

6. Optionally, you can verify the image and cloud-init functionality using [dockerpi](https://github.com/lukechilds/dockerpi). It start a Docker container with QEMU in it emulating a Pi. This way you can already verify, that the image and the provided `user-data` is working without flashing a new SD card everytime.
    ```
    docker run -it -v $PWD/$img_file:/sdcard/filesystem.img lukechilds/dockerpi:vm
    ...
    cloud-init[96]: Cloud-init v. 20.2 running 'init-local' at Mon, 08 Mar 2021 19:54:02 +0000. Up 53.20 seconds.
    ...
    cloud-init[380]: Cloud-init v. 20.2 running 'init' at Mon, 08 Mar 2021 19:54:42 +0000. Up 93.34 seconds.
    ...
    cloud-init[568]: Cloud-init v. 20.2 running 'modules:config' at Mon, 08 Mar 2021 19:55:48 +0000. Up 159.10 seconds.
    ...
    cloud-init[620]: Cloud-init v. 20.2 running 'modules:final' at Mon, 08 Mar 2021 19:56:05 +0000. Up 175.50 seconds.
    cloud-init[620]: Cloud-init v. 20.2 finished at Mon, 08 Mar 2021 19:56:08 +0000. Datasource DataSourceNoCloud [seed=/dev/sda1][dsmode=net].  Up 179.17 seconds
    ```

7. Now, flash the image including cloud-init data to SD card, using [balena etcher](https://www.balena.io/etcher/), [Raspberry Pi Imager](https://www.raspberrypi.org/software/) or similar.

8. Finally, SSH into your Pi and verify cloud-init functionality. By default, the `pi` user is locked and SSH password authentication is disabled, so make sure to use the custom user with `ssh_authorized_keys` from your `user-data`.
    ```
    ssh your-user@your-pi
    cat /var/log/cloud-init-output.log
    ```
