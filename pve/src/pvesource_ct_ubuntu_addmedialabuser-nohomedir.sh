#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_ubuntu_addmedialabuser.sh
# Description:  Source script for creating MediaLab user "media" in CTs
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

section "Create MediaLab User and Group"

# Start container
pct_start_waitloop

# Create MediaLab Group
msg "Creating ${OSTYPE^} CT default user groups..."
pct exec $CTID -- bash -c 'if [ $(getent group medialab >/dev/null; echo $?) -ne 0 ]; then groupadd -g 65605 medialab > /dev/null; fi'
info "User Group created: ${YELLOW}medialab${NC}"
echo

# Create MediaLab Users
msg "Creating ${OSTYPE^} CT default users..."
pct exec $CTID -- bash -c 'if [ $(id -u media &>/dev/null; echo $?) = 1 ]; then useradd -u 1605 -g medialab -s /bin/bash media >/dev/null; fi'
info "User created: ${YELLOW}'media'${NC} of Group 'medialab'"
echo
#-----------------------------------------------------------------------------------