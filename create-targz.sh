#!/bin/bash

set -e

#declare variables
ORIGINDIR=$(pwd)
TMPDIR=$(mktemp -d)
BUILDDIR=$(mktemp -d)

BOOTISO="https://centos.mirror.constant.com/7.6.1810/os/x86_64/images/boot.iso"
KSFILE="https://raw.githubusercontent.com/WhitewaterFoundry/sig-cloud-instance-build/master/docker/centos-7-x86_64.ks"
EPELRPM="https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
PAGEANTEXE="https://the.earth.li/~sgtatham/putty/latest/w64/pageant.exe"
WEASELPAGEANT="https://github.com/vuori/weasel-pageant/releases/download/v1.3/weasel-pageant-1.3.zip"

#go to our temporary directory
cd $TMPDIR

#make sure we are up to date
sudo yum update

#get livemedia-creator dependencies
sudo yum install libvirt lorax virt-install libvirt-daemon-config-network libvirt-daemon-kvm libvirt-daemon-driver-qemu unzip wget -y

#restart libvirtd for good measure
sudo systemctl restart libvirtd

#download enterprise boot ISO
if [[ ! -f "$ORIGINDIR/install.iso" ]] ; then
	sudo curl $BOOTISO -o $ORIGINDIR/install.iso
fi
sudo cp $ORIGINDIR/install.iso /tmp/install.iso

#download enterprise Docker kickstart file
curl $KSFILE -o install.ks

#build intermediary rootfs tar
sudo livemedia-creator --make-tar --iso=/tmp/install.iso --image-name=install.tar.xz --ks=install.ks --releasever "7"

#open up the tar into our build directory
tar -xvf /var/tmp/install.tar.xz -C $BUILDDIR

#install epel repo (needed for pygpgme)
wget -P $BUILDDIR/tmp "${EPELRPM}"
sudo mount -o bind /dev $BUILDDIR/dev
sudo chroot $BUILDDIR yum -y install /tmp/epel-release-latest-7.noarch.rpm
sudo chroot $BUILDDIR yum update

#install dependencies and clean yum cache
sudo chroot $BUILDDIR yum -y install sudo unzip openssh openssh-clients
sudo chroot $BUILDDIR yum clean all

# get weasel-pageant
mkdir -p $BUILDDIR/opt/pageant
wget -O weasel-pageant.zip "${WEASELPAGEANT}"
unzip weasel-pageant.zip
cp weasel-pageant-1.3/helper.exe $BUILDDIR/opt/pageant/
cp weasel-pageant-1.3/weasel-pageant $BUILDDIR/opt/pageant/

# get putty's pageant.exe
wget -O pageant.exe "${PAGEANTEXE}"
cp pageant.exe $BUILDDIR/opt/pageant/

#set some environmental variables
sudo bash -c "echo 'export DISPLAY=:0' >> $BUILDDIR/etc/profile.d/wsl.sh"
sudo bash -c "echo 'export LIBGL_ALWAYS_INDIRECT=1' >> $BUILDDIR/etc/profile.d/wsh.sh"
sudo bash -c "echo 'export NO_AT_BRIDGE=1' >> $BUILDDIR/etc/profile.d/wsl.sh"

# Copy over our own files
sudo cp $ORIGINDIR/linux_files/wsl.conf $BUILDDIR/etc/wsl.conf
sudo cp $ORIGINDIR/linux_files/local.conf $BUILDDIR/etc/local.conf
sudo cp $ORIGINDIR/linux_files/firstrun.sh $BUILDDIR/etc/profile.d/firstrun.sh

mkdir -p $BUILDDIR/opt/pengwin
sudo cp $ORIGINDIR/linux_files/uninstall.sh $BUILDDIR/opt/pengwin/uninstall.sh

mkdir -p $BUILDDIR/opt/vcxsrv
sudo cp $ORIGINDIR/linux_files/vcxsrv.zip $BUILDDIR/opt/vcxsrv

#re-build our tar image
cd $BUILDDIR
tar --ignore-failed-read -czvf $ORIGINDIR/install.tar.gz *

#go home
cd $ORIGINDIR

#clean up
sudo umount $BUILDDIR/dev
sudo rm -r $BUILDDIR
sudo rm -r $TMPDIR
sudo rm /tmp/install.iso
sudo rm /var/tmp/install.tar.xz
