# Ubuntu OS Profile

<img align="right" src="https://assets.ubuntu.com/v1/29985a98-ubuntu-logo32.png">

Intended to be used with [Retail Node Installer](https://github.com/intel/retail-node-installer) and Ubuntu base profile, this Ubuntu OS profile contains a few files that ultimately will install Ubuntu OS to disk.

## Software Stack in this profile

* Ubuntu Linux w/ Docker

## Target Device Prerequisites

* x86 Bare Metal or x86 Virtual Machine
* At Least 5 GB of Disk Space
  * Supports the following drive types:
    * SDD
    * NVME
    * MMC
* 4 GB of RAM

## Detailed Instructions

### Set Up ESP Server

Follow steps 1-3 from here: https://github.com/intel/edge-software-provisioner#quick-installation-guide

Open the file conf/config.yml and add the follow profile:
```
  - git_remote_url: https://github.com/sedillo/rni-profile-base-ubuntu/
    profile_branch: gvt
    profile_base_branch: master
    git_username: ""
    git_token: ""
    # This is the name that will be shown on the PXE menu (NOTE: No Spaces)
    name: GVT
    custom_git_arguments: ""
```

Now follow steps 4-5 from the same guide: https://github.com/intel/edge-software-provisioner#quick-installation-guide

### KVM Configuration
Now build a KVM kernel
```
git -C /opt clone https://github.com/philip-park/idv.git
cd /opt/idv
./build-kernel.sh
```
Choose the latest 5.4/yocto intel kernel.

Look in /opt/idv/build/ for a linux-headers and linux-image .debian files

### Merge KVM with ESP
We will combine the KVM files built with the ESP Apache server located here /opt/esp/data/usr/share/nginx/html
Verify this folder exists.
```
cd /opt
mkdir -p /opt/esp/data/usr/share/nginx/html/stage
ln -s /opt/esp/data/usr/share/nginx/html/stage stage
```
Adding any file to /opt/stage should now appear at the ESP URL http://${PROVISIONER}/stage/
```
mkdir -p /opt/stage/kernel
mkdir -p /opt/stage/qemu
mkdir -p /opt/stage/disk
```
Move the kernel files and make sure to match the names below
- /opt/stage/kernel/linux-image.deb
- /opt/stage/kernel/linux-headers.deb


Create a VM file system using the example as a template
```bash
git -C /opt clone https://github.com/sedillo/idv/ target-files
cp -r /opt/target-files/target-example /opt/stage/target
```
Move any disk images to the following directory *Make sure the file ends in .qcow2*
- /opt/stage/disk/\*.qcow2


Optional: A default Qemu is installed, but this can be overriden by adding qemu here 
- /opt/stage/qemu/qemu.tar.gz

## Getting Started

**A necessary prerequisite to using this profile is having an Retail Node Installer deployed**. Please refer to Retail Node Installer project documentation for [installation](https://github.com/intel/retail-node-installer) in order to deploy it.

Out of the box, the Ubuntu profile should _just work_. Therefore, no specific steps are required in order to use this profile that have not already been described in the Retail Node Installer documentation. Simply boot a client device using legacy BIOS PXE boot and the Ubuntu profile should automatically launch after a brief waiting period.

If you do encounter issues PXE booting, please review the steps outlined in the Retail Node Installer documentation and ensure you've followed them correctly. See the [Known Issues](https://github.com/intel/retail-node-installer) section for possible solutions.

After installing Ubuntu, the default login username is `sys-admin` and the default password is `P@ssw0rd!`. This password is defined in the `bootstrap.sh` script and in the `conf/config.yml` as a kernel argument.

## Kernel Paramaters used at build time

The following kernel parameters can be added to `conf/config.yml`

* `bootstrap` - RESERVED, do not change
* `ubuntuversion` - Use the Ubuntu release name. Defaults to 'cosmic' release
* `debug` - [TRUE | FALSE] Enables a more verbose output
* `httppath` - RESERVED, do not change
* `kernparam` - Used to pass additional kernel parameters to the targeted system.  Example format: kernparam=splash:quiet#enable_gvt:1
* `parttype` - RESERVED, do not change
* `password` - Initial user password. Defaults to 'password'
* `proxy` - Add proxy settings if behind proxy during installation.  Example: http://proxy-us.intel.com:912
* `proxysocks` - Add socks proxy settings if behind proxy during installation.  Example: http://proxy-us.intel.com:1080
* `release` - [prod | dev] If set to prod the system will shutdown after it is provisioned.  Altnerativily it will reboot.
* `token` - GitHub token for private repositories, if this profile is in a private respository this token should have access to this repo
* `username` - Initial user name. Defaults to 'sys-admin'

## Sample Profile Section

* To use base profile with custom profile, Please refer below sample profile section of config.yml for Retail Node Installer 

```yaml
# Please make sure to define ALL of the variables below, even if they
# are empty. Otherwise, this application will not be configured properly.
profiles:
  - git_remote_url: https://github.com/intel/rni-profile-base-ubuntu.git
    profile_branch: slim
    profile_base_branch: master
    git_username: ""
    git_token: ""
    name: Ubuntu_with_Docker
    custom_git_arguments: --depth=1
```

## Known Limitations

* Currently does not support full disk encryption
* Currently does not install Secure Boot features

## Customization

If you want to customize your Retail Node Installer profile, follow these steps:

* Duplicate this repository locally and push it to a separate/new git repository
* Make changes after reading the information below
* Update your Retail Node Installer configuration to point to the git repository, base branch (such as master or base) and custom branch(such as rwo).

The flexibility of Retail Node Installer comes to fruition with the following profile-side file structures:

* `conf/config.yml` - This file contains the arguments that are passed to the Linux kernel upon PXE boot. Alter these arguments according to the needs of your scripts. The following kernel arguments are always prepended to the arguments specified in `conf/config.yml`:
  * `console=tty0`
  * `httpserver=@@HOST_IP@@`
  * `bootstrap=http://@@HOST_IP@@/profile/${profileName}/bootstrap.sh`
* `conf/files.yml` - This file contains a few definitions that tell Retail Node Installer to download specific files that you can customize. **Please check if there are any [Known Limitations](#Known-Limitations) before changing this file from the default.** User can specify an `initrd` and `vmlinuz`, as shown in the `conf/files.sample.yml` file. See `conf/files.sample.yml` for a full example.
* `bootstrap.sh` - A profile is required to have a `bootstrap.sh` as an entry point. This is an arbitrary script that you can control. Custom bootstrap.sh should always call pre.sh and post.sh from base branch inorder to install OS(Please refer *rwo* custom branch for reference). User can also write a seprate script(such as profile.sh) to perform specific task and call it from bootstrap.sh.

Currently the following variables are processed:
  * `@@DHCP_MIN@@`
  * `@@DHCP_MAX@@`
  * `@@NETWORK_BROADCAST_IP@@`
  * `@@NETWORK_GATEWAY_IP@@`
  * `@@HOST_IP@@`
  * `@@NETWORK_DNS_SECONDARY@@`
  * `@@PROFILE_NAME@@`

### Customization Requirements

A profile **must** have all of the following:

* a `bootstrap.sh` file at the root of the repository
* a `profile.sh` file at the root of the repository
