#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -a

#this is provided while using Utility OS
source /opt/bootstrap/functions



# --- Add Packages
ubuntu_bundles="openssh-server"
ubuntu_packages="wget qemu-system-x86 ovmf libegl1-mesa-dev"

# --- List out any docker images you want pre-installed separated by spaces. ---
pull_sysdockerimagelist=""

# --- List out any docker tar images you want pre-installed separated by spaces.  We be pulled by wget. ---
wget_sysdockerimagelist="" 


# Quotes and apostrophes must be double escaped ///" 
WGET_HEADER_V2="--header \\\"Authorization: token ${param_token}\\\""
STAGE_URL="http://${PROVISIONER}/stage"

# --- Install Extra Packages ---
run "Installing Extra Packages on Ubuntu ${param_ubuntuversion}" \
    "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
    'mount --bind dev /target/root/dev && \
    mount -t proc proc /target/root/proc && \
    mount -t sysfs sysfs /target/root/sys && \
    LANG=C.UTF-8 chroot /target/root sh -c \
        \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
        mount ${BOOT_PARTITION} /boot && \
        export DEBIAN_FRONTEND=noninteractive && \
        apt install -y tasksel && \
        tasksel install ${ubuntu_bundles} && \
        apt install -y ${ubuntu_packages} && \
        wget ${WGET_HEADER_V2} ${STAGE_URL}/kernel/linux-image.deb && \
        wget ${WGET_HEADER_V2} ${STAGE_URL}/kernel/linux-headers.deb && \
        dpkg -i linux-image.deb && \
        dpkg -i linux-headers.deb && \
        update-grub\"'" \
    ${PROVISION_LOG}

# --- Install qemu files ---
# Quotes and apostrophes must be escaped /" or /'
WGET_HEADER="--header \"Authorization: token ${param_token}\""

#run "Installing qemu on Ubuntu ${param_bootstrapurl} " \
#    "wget ${WGET_HEADER} ${STAGE_URL}/qemu/qemu.tar.gz -P ${ROOTFS}/usr && \
#     tar xvf ${ROOTFS}/usr/qemu.tar.gz -C ${ROOTFS}/usr && \
#     rm ${ROOTFS}/usr/qemu.tar.gz" \
#    ${PROVISION_LOG}

# --- Pull any and load any system images ---
for image in $pull_sysdockerimagelist; do
	run "Installing system-docker image $image" "docker exec -i system-docker docker pull $image" "$TMP/provisioning.log"
done
for image in $wget_sysdockerimagelist; do
	run "Installing system-docker image $image" "wget -O- $image 2>> $TMP/provisioning.log | docker exec -i system-docker docker load" "$TMP/provisioning.log"
done


# --- Pull KVM files from local apache server ---
# Disk images are large and can cause memory overrun issues with wget,
#   so they must be pulled one at a time

WGET_RECURSIVE="--cut-dirs=2 --reject=\"index.html*\" -nH  -r --no-parent"
run "Cloning github vm files " \
    "wget ${WGET_HEADER} ${WGET_RECURSIVE} -P ${ROOTFS}/ ${STAGE_URL}/target/ && \
     chmod +x ${ROOTFS}/var/vm/scripts/*.sh && \
     mkdir -p ${ROOTFS}/var/vm/disk && \
     echo \"***Done***\"  " \
    ${PROVISION_LOG}

# --- Get QCOW Image Files ---
QCOWFILES=$(wget -O - ${STAGE_URL}/disk/ | grep ".qcow2" | awk -F"href=" '{print $2}' | awk -F\" '{print $2}')

for image in $QCOWFILES; do
	run "Installing VM-Image $image" \
        "wget ${WGET_HEADER} -P ${ROOTFS}/var/vm/disk ${STAGE_URL}/disk/$image" \
        "$TMP/provisioning.log"
done

# --- Adding missing kernel modules --- 
run "Enabling vfio-pci module " \
    "mkdir -p $ROOTFS/etc/modules-load.d/ && \
     echo 'vfio-pci' > $ROOTFS/etc/modules-load.d/vfio-pci.conf" \
    "$TMP/provisioning.log"

# --- Setting up services ---
run "Starting kvm services" \
    "docker run -i --rm --privileged \
       --name ubuntu-installer ${DOCKER_PROXY_ENV} \
       -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root \
       ubuntu:${param_ubuntuversion} \
       sh -c \
         'mount --bind dev /target/root/dev && \
          mount -t proc proc /target/root/proc && \
          mount -t sysfs sysfs /target/root/sys && \
          LANG=C.UTF-8 \
          chroot /target/root \
          sh -c \
              \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") \
                export TERM=xterm-color && \
                mount ${BOOT_PARTITION} /boot && \
                export DEBIAN_FRONTEND=noninteractive && \
                systemctl enable qemu.service && \
                usermod -a -G kvm ${param_username} && \
                usermod -a -G render ${param_username} && \
                usermod -a -G video ${param_username} && \
                usermod -a -G dialout ${param_username} && \
                systemctl enable vgpu.service \"'" \
    ${PROVISION_LOG}

