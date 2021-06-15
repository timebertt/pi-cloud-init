#!/bin/bash -ex

ARCH="${ARCH:-armhf}"

# go to home and fetch pi-gen
cd /home/vagrant

if [ -d pi-gen ] ; then
  echo "found pi-gen, skipping clone"
else
  echo "cloning pi-gen"

  git clone https://github.com/RPi-Distro/pi-gen.git
fi

pushd pi-gen

chmod +x build.sh

case "$ARCH" in
  armhf)
    git checkout master
    ;;
  aarch64)
    echo "WARNING: 64-bit build is experimental"
    git checkout arm64
    ;;
  *)
    >&2 echo "unsupported architecture '$ARCH'"
    exit 1
    ;;
esac

### write out config
cat > config <<EOL
export IMG_NAME="raspios-buster-$ARCH"
export RELEASE=buster
export DEPLOY_ZIP=1
export LOCALE_DEFAULT=en_US.UTF-8
export TARGET_HOSTNAME=raspberrypi
export KEYBOARD_KEYMAP=us
export KEYBOARD_LAYOUT="English (US)"
export TIMEZONE_DEFAULT=Europe/Berlin
export FIRST_USER_NAME=pi
export FIRST_USER_PASS=raspberry-cloud
export ENABLE_SSH=1
export USE_QCOW2=0
export STAGE_LIST="stage0 stage1 stage2"
export WORK_DIR="$PWD/work"
EOL

### modify stage2
pushd stage2

# don't need NOOBS
rm -f EXPORT_NOOBS || true

cat > EXPORT_IMAGE <<EOF
IMG_SUFFIX="-lite-cloud-init"
if [ "${USE_QEMU}" = "1" ]; then
	export IMG_SUFFIX="${IMG_SUFFIX}-qemu"
fi
EOF

### add cloud-init step to stage2
step="10-cloud-init"
if [ -d "$step" ]; then
  rm -Rf $step
fi
mkdir $step && pushd $step

cat > 00-packages <<EOF
cloud-init
EOF

cat > 01-run-chroot.sh <<EOF
#!/bin/bash

# Disable dhcpcd - it has a conflict with cloud-init network config
systemctl mask dhcpcd

# fix sources list
echo 'deb {{mirror}} {{codename}} main contrib non-free rpi' > /etc/cloud/templates/sources.list.debian.tmpl

cat > /etc/cloud/cloud.cfg <<EOC
# The top level settings are used as module
# and system configuration.

# A set of users which may be applied and/or used by various modules
# when a 'default' entry is found it will reference the 'default_user'
# from the distro configuration specified below
users:
- default

# If this is set, 'root' will not be able to ssh in and they
# will get a message to login instead as the above $user (debian)
disable_root: true

# This will cause the set+update hostname module to not operate (if true)
preserve_hostname: false

# This preverts apt/sources.list to be updated at boot time, which
# may be annoying.
apt_preserve_sources_list: true

# configure NoCloud datasource to load user-data and meta-data from /boot
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    # read from boot partition instead of partition with cidata label as
    # boot is FAT formatted and can easily be edited on all OSes,
    # remove or comment if you want to use a cidata partition
    # (e.g. iso created via genisoimage)
    fs_label: boot

# The modules that run in the 'init' stage
cloud_init_modules:
- migrator
- seed_random
- bootcmd
- write-files
- growpart
- resizefs
- disk_setup
- mounts
- set_hostname
- update_hostname
- update_etc_hosts
- ca-certs
- rsyslog
- users-groups
- ssh

# The modules that run in the 'config' stage
cloud_config_modules:
# Emit the cloud config ready event
# this can be used by upstart jobs for 'start on cloud-config'.
- emit_upstart
- ssh-import-id
- locale
- set-passwords
- grub-dpkg
- apt-pipelining
- apt-configure
- ntp
- timezone
- disable-ec2-metadata
- runcmd
- byobu

# The modules that run in the 'final' stage
cloud_final_modules:
- package-update-upgrade-install
- fan
- puppet
- chef
- salt-minion
- mcollective
- rightscale_userdata
- scripts-vendor
- scripts-per-once
- scripts-per-boot
- scripts-per-instance
- scripts-user
- ssh-authkey-fingerprints
- keys-to-console
- phone-home
- final-message
- power-state-change

# System and/or distro specific settings
# (not accessible to handlers/transforms)
system_info:
  # This will affect which distro class gets used
  distro: debian
  # Default user name + that default users groups (if added/used)
  default_user:
    name: pi
    # lock password login for pi user, making default password unusable
    # change to false, in case applying user-data failed and you're locked out
    lock_passwd: true
  # Other config here will be given to the distro class and/or path classes
  paths:
    cloud_dir: /var/lib/cloud/
    templates_dir: /etc/cloud/templates/
    upstart_dir: /etc/init/
  package_mirrors:
  - arches: [default]
    failsafe:
      primary: http://raspbian.raspberrypi.org/raspbian/
      security: []
  ssh_svcname: ssh
EOC
EOF
chmod +x 01-run-chroot.sh

popd

### add cgroups step to stage2
step="11-cgroups"
if [ -d "$step" ]; then
  rm -Rf $step
fi
mkdir $step && pushd $step

cat > 00-run-chroot.sh <<"EOF"
#!/bin/bash

# Raspberry Pi OS doesn't enable cgroups by default
cmdline_string="cgroup_memory=1 cgroup_enable=memory"

if ! grep -q "$cmdline_string" /boot/cmdline.txt ; then
  sed -i "1 s/\$/ $cmdline_string/" /boot/cmdline.txt
fi
EOF
chmod +x 00-run-chroot.sh

popd

### add rfkill step to stage2
step="12-rfkill"
if [ -d "$step" ]; then
  rm -Rf $step
fi
mkdir $step && pushd $step

# must run after stage2/02-net-tweaks (which installs the wifi-check.sh script)
cat > 00-run-chroot.sh <<"EOF"
#!/bin/bash

# disable warning message on login about WiFi being blocked by rfkill
# WiFi is disabled by default, see https://github.com/RPi-Distro/pi-gen/blob/66cd2d17a0d2d04985b83a2ba830915c9a7d81dc/export-noobs/00-release/files/release_notes.txt#L223-L229
if [ -e /etc/profile.d/wifi-check.sh ] ; then
  mv /etc/profile.d/wifi-check.sh /etc/profile.d/wifi-check.sh.bak
fi
EOF
chmod +x 00-run-chroot.sh

popd

# end modifying stage2
popd

### start pi-gen build
sudo ./build.sh

### copy image back to project dir
zip_file=$(find deploy -name 'image_*.zip' -printf '%T@ %p\n' | sort -n | cut -d' ' -f 2- | tail -n 1)
copied_zip_file="${zip_file##*/image_}"
cp "$zip_file" "/home/vagrant/pi-cloud-init/$copied_zip_file"
