#!/bin/bash

set -eu -o pipefail

echo >&2 "===]> Info: Configure environment... "

mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts

export HOME=/root
export LC_ALL=C

echo "ubuntu-fs-live" >/etc/hostname

echo >&2 "===]> Info: Configure and update apt... "

cat <<EOF >/etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
EOF
apt-get update

echo >&2 "===]> Info: Install systemd and Ubuntu MBP Repo... "

apt-get install -y systemd-sysv gnupg curl wget

mkdir -p /etc/apt/sources.list.d
echo "deb https://mbp-ubuntu-kernel.herokuapp.com/ /" >/etc/apt/sources.list.d/mbp-ubuntu-kernel.list
curl -L https://mbp-ubuntu-kernel.herokuapp.com/KEY.gpg | apt-key add -
apt-get update

echo >&2 "===]> Info: Configure machine-id and divert... "

dbus-uuidgen >/etc/machine-id
ln -fs /etc/machine-id /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

echo >&2 "===]> Info: Install packages needed for Live System... "

export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  ubuntu-standard \
  sudo \
  casper \
  lupin-casper \
  discover \
  laptop-detect \
  os-prober \
  network-manager \
  resolvconf \
  net-tools \
  wireless-tools \
  wpagui \
  locales \
  initramfs-tools \
  binutils \
  linux-generic \
  grub-efi-amd64-signed \
  "linux-image-${KERNEL_VERSION}" \
  "linux-headers-${KERNEL_VERSION}" \
  intel-microcode \
  thermald

echo >&2 "===]> Info: Install window manager... "

apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  plymouth-theme-ubuntu-logo \
  ubuntu-desktop-minimal \
  ubuntu-gnome-wallpapers \
  snapd

echo >&2 "===]> Info: Install Graphical installer... "

apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  ubiquity \
  ubiquity-casper \
  ubiquity-frontend-gtk \
  ubiquity-slideshow-ubuntu \
  ubiquity-ubuntu-artwork

echo >&2 "===]> Info: Install useful applications... "

apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  git \
  curl \
  nano \
  make \
  gcc

echo >&2 "===]> Info: Change initramfs format (for grub)... "
sed -i "s/COMPRESS=lz4/COMPRESS=gzip/g" "/etc/initramfs-tools/initramfs.conf"

echo >&2 "===]> Info: Add drivers... "

APPLE_BCE_DRIVER_GIT_URL=https://github.com/aunali1/mbp2018-bridge-drv.git
APPLE_BCE_DRIVER_BRANCH_NAME=aur
APPLE_BCE_DRIVER_COMMIT_HASH=c884d9ca731f2118a58c28bb78202a0007935998
APPLE_IB_DRIVER_GIT_URL=https://github.com/roadrunner2/macbook12-spi-driver.git
APPLE_IB_DRIVER_BRANCH_NAME=mbp15
APPLE_IB_DRIVER_COMMIT_HASH=90cea3e8e32db60147df8d39836bd1d2a5161871

mkdir -p /opt/drivers
mkdir -p "/lib/modules/${KERNEL_VERSION}/kernel/drivers"

printf '\nblacklist thunderbolt' >>/etc/modprobe.d/blacklist.conf

git clone --single-branch --branch ${APPLE_BCE_DRIVER_BRANCH_NAME} ${APPLE_BCE_DRIVER_GIT_URL} \
  /opt/drivers/apple-bce
git -C /opt/drivers/apple-bce/ checkout "${APPLE_BCE_DRIVER_COMMIT_HASH}"
PATH=/usr/share/Modules/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/bin \
  make -C /lib/modules/"${KERNEL_VERSION}"/build/ M=/opt/drivers/apple-bce modules
cp -rf /opt/drivers/apple-bce/*.ko /lib/modules/"${KERNEL_VERSION}"/kernel/drivers/
printf '\n# apple-bce\nhid-apple\nbcm5974\nsnd-seq\napple-bce' >>/etc/modules-load.d/apple-bce.conf
printf '\n# apple-bce\nhid-apple\nsnd-seq\napple-bce' >>/etc/initramfs-tools/modules

git clone --single-branch --branch ${APPLE_IB_DRIVER_BRANCH_NAME} ${APPLE_IB_DRIVER_GIT_URL} \
  /opt/drivers/applespi
git -C /opt/drivers/applespi/ checkout "${APPLE_IB_DRIVER_COMMIT_HASH}"
PATH=/usr/share/Modules/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/bin \
  make -C /lib/modules/"${KERNEL_VERSION}"/build/ M=/opt/drivers/applespi modules
printf '\n# applespi\napple_ibridge\napple_ib_tb\napple_ib_als' >>/etc/modules-load.d/applespi.conf
printf '\n# display f* key in touchbar\noptions apple-ib-tb fnmode=2\n'  >> /etc/modprobe.d/apple-tb.conf
cp -rf /opt/drivers/applespi/*.ko /lib/modules/"${KERNEL_VERSION}"/kernel/drivers/

rm -rf /opt/drivers

echo >&2 "===]> Info: Update initramfs... "

## Add custom drivers to be loaded at boot
/usr/sbin/depmod -a "${KERNEL_VERSION}"
update-initramfs -u -v -k "${KERNEL_VERSION}"

echo >&2 "===]> Info: Remove unused applications ... "

apt-get purge -y -qq \
  transmission-gtk \
  transmission-common \
  gnome-mahjongg \
  gnome-mines \
  gnome-sudoku \
  aisleriot \
  hitori \
  xiterm+thai \
  make \
  gcc \
  vim \
  binutils \
  linux-generic \
  linux-headers-5.4.0-28 \
  linux-headers-5.4.0-28-generic \
  linux-headers-generic \
  linux-image-5.4.0-28-generic \
  linux-image-generic \
  linux-modules-5.4.0-28-generic \
  linux-modules-extra-5.4.0-28-generic

apt-get autoremove -y

echo >&2 "===]> Info: Reconfigure environment ... "

locale-gen --purge en_US.UTF-8 en_US
printf 'LANG="C.UTF-8"\nLANGUAGE="C.UTF-8"\n' >/etc/default/locale

dpkg-reconfigure -f readline resolvconf

cat <<EOF >/etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=dnsmasq
[ifupdown]
managed=false
EOF
dpkg-reconfigure network-manager

echo >&2 "===]> Info: Cleanup the chroot environment... "

truncate -s 0 /etc/machine-id
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
apt-get clean
rm -rf /tmp/* ~/.bash_history
rm -rf /tmp/setup_files

umount -lf /dev/pts
umount -lf /sys
umount -lf /proc

export HISTSIZE=0
