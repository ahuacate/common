#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_ubuntu_addhomelabuser.sh
# Description:  Source script for creating Homelab user "home" in CTs
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
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
pct exec $CTID -- bash -c 'if [ $(id -u home &>/dev/null; echo $?) = 1 ]; then useradd -u 1606 -g homelab -s /bin/bash home >/dev/null; fi'
info "User created: ${YELLOW}'home'${NC} of Group 'homelab'"
echo
#-----------------------------------------------------------------------------------