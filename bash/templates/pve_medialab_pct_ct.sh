#!/usr/bin/env bash

#### Default MediaLab PCT Template ####

# Download latest PVE CT OS template
pveam update >/dev/null
if [ ! -f /var/lib/vz/template/cache/$OSTYPE-$OSVERSION.* ]; then
  msg "Downloading Proxmox CT/LXC '${OSTYPE^} $OSVERSION' template..."
fi
mapfile -t TEMPLATES < <(pveam available -section system | sed -n "s/.*\($OSTYPE-$OSVERSION.*\)/\1/p" | sort -t - -k 2 -V)
TEMPLATE="${TEMPLATES[-1]}"
pveam download local $TEMPLATE >/dev/null || die "A problem occurred while downloading the LXC template."

# Setting Variables
ARCH=$(dpkg --print-architecture)
TEMPLATE_STRING="local:vztmpl/${TEMPLATE}"

# Create LXC
msg "Creating ${CT_HOSTNAME_VAR^} CT..."
pct create $CTID $TEMPLATE_STRING --arch $ARCH --cores $CT_CPU_CORES --hostname $CT_HOSTNAME --cpulimit 1 --cpuunits 1024 --memory $CT_RAM \
--net0 name=eth0,bridge=vmbr0,tag=$CT_TAG,firewall=1,gw=$CT_GW,ip=$CT_IP/$CT_IP_SUBNET,type=veth \
--ostype $OSTYPE --rootfs $STORAGE:$CT_DISK_SIZE,acl=1 --swap $CT_SWAP --unprivileged $CT_UNPRIVILEGED --onboot 1 --startup order=2 >/dev/null
