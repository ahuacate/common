#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_medialab_vaapipassthru.sh
# Description:  Source script for VA-API installation and configuration for CT
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

msg_box "${HOSTNAME^} supports hardware acceleration of video encoding/decoding/transcoding using FFMpeg. FFMpeg can support multiple hardware acceleration implementations for Linux such as Intel Quicksync (QSV), nVidia NVENC/NVDEC, and VA-API through Video Acceleration APIs.

This script ONLY supports Proxmox hosts installed with a AMD/Intel CPU with integrated graphics GPU. If your Proxmox host is installed with a NVIDIA Graphics Card you must manually configure video passthrough at a later stage.

In the next steps we will check if your PVE host hardware supports VA-API video encoding. If the check passes we will configure your CT for VA-API passthrough encoding/decoding/transcoding."

# Checking for PVE host VA-API support
msg "Checking PVE host support for VA-API..."
if [ $(ls -l /dev/dri | grep renderD128 > /dev/null; echo $?) = 0 ]; then
    # Install VA-INFO
    if [[ ! $(dpkg -s vainfo 2> /dev/null) ]]; then
        apt-get install vainfo -y > /dev/null
    else
        apt-get --only-upgrade install vainfo -y > /dev/null
    fi

    # Configure VA-API passthru
    chmod 666 /dev/dri/renderD128 >/dev/null
    # Creating rc.local script to set permissions for /dev/dri/renderD128
    echo -e '#!/bin/sh -e\n/bin/chmod 666 /dev/dri/renderD128\nexit 0' > /etc/rc.local
    chmod +x /etc/rc.local
    bash /etc/rc.local

    # Creating PVE host video device passthrough
    DRM_VAR01=$(ls -l /dev/dri | grep renderD128 | awk '{print $5}' | sed "s/,//")
    DRM_VAR02=$(ls -l /dev/dri | grep renderD128 | awk '{print $6}')
    echo -e "lxc.cgroup2.devices.allow: c $DRM_VAR01:$DRM_VAR02 rwm\nlxc.cgroup2.devices.allow: c $DRM_VAR01:0 rwm\nlxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file\nlxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir" >> /etc/pve/lxc/$CTID.conf
    info "LXC to iGPU render (VA-API) is configured for '${HOSTNAME^}'."
    echo
else
    info "Your PVE host currently does not support LXC to iGPU render (VA-API). To fix this issue run our 'PVE Host Toolbox' easy script and select menu item 'PVE Intel Amd iGPU LXC support' to setup LXC access to your CPUs integrated graphics processor. You will need to reinstall this LXC.
    LXC to iGPU render (VA-API) is NOT configured for '${HOSTNAME^}'. Skipping this step."
    sleep 3
    echo
fi
#-----------------------------------------------------------------------------------