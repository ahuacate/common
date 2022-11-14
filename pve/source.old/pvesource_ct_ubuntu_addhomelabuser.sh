#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_ubuntu_addhomelabuser.sh
# Description:  Source script for creating HomeLab user "home" in CTs
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

function pct_start_waitloop () {
  if [ "$(pct status $CTID)" == "status: stopped" ]; then
    msg "Starting CT $CTID..."
    pct start $CTID
    msg "Waiting to hear from CT $CTID..."
    while ! ping -s 1 -c 2 "$CT_IP" > /dev/null; do
        echo -n .
    done
    sleep 1
    info "CT $CTID status: ${GREEN}running${NC}"
    echo
  fi
}

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

section "Create Homelab User and Group"

# Start container
pct_start_waitloop

# Create Homelab Group
msg "Creating ${OSTYPE^} CT default user groups..."
pct exec $CTID -- bash -c 'if [ $(getent group homelab >/dev/null; echo $?) -ne 0 ]; then groupadd -g 65606 homelab > /dev/null; fi'
info "User Group created: ${YELLOW}homelab${NC}"
echo

# Create Homelab Users
msg "Creating ${OSTYPE^} CT default users..."
pct exec $CTID -- bash -c 'if [ $(id -u home &>/dev/null; echo $?) = 1 ]; then useradd -u 1606 -g homelab -s /bin/bash -m home >/dev/null; fi'
info "User created: ${YELLOW}'home'${NC} of Group 'homelab'"
echo