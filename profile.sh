#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -a

#this is provided while using Utility OS
source /opt/bootstrap/functions



# --- Add Packages
ubuntu_bundles="openssh-server"
ubuntu_packages="wget"

# --- List out any docker images you want pre-installed separated by spaces. ---
pull_sysdockerimagelist=""

# --- List out any docker tar images you want pre-installed separated by spaces.  We be pulled by wget. ---
wget_sysdockerimagelist="" 



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
        wget --header \\\"Authorization: token ${param_token}\\\" ${param_bootstrapurl/profile/files}/linux-image.deb && \
        wget --header \\\"Authorization: token ${param_token}\\\" ${param_bootstrapurl/profile/files}/linux-headers.deb && \
        dpkg -i linux-image.deb && \
        dpkg -i linux-headers.deb && \
        update-grub\"'" \
    ${PROVISION_LOG}

# --- Install qemu files ---
run "Installing qemu on Ubuntu ${param_bootstrapurl} " \
    "wget --header \"Authorization: token ${param_token}\" ${param_bootstrapurl/profile/files}/qemu.tar.xz -P ${ROOTFS}/usr && \
     tar xvf ${ROOTFS}/usr/qemu.tar.xz -C ${ROOTFS}/usr && \
     rm ${ROOTFS}/usr/qemu.tar.xz" \
    ${PROVISION_LOG}

# --- Pull any and load any system images ---
for image in $pull_sysdockerimagelist; do
	run "Installing system-docker image $image" "docker exec -i system-docker docker pull $image" "$TMP/provisioning.log"
done
for image in $wget_sysdockerimagelist; do
	run "Installing system-docker image $image" "wget -O- $image 2>> $TMP/provisioning.log | docker exec -i system-docker docker load" "$TMP/provisioning.log"
done
