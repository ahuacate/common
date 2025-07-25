#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_ubuntubasics.sh
# Description:  Source script for setting up Ubuntu CT basic configuration
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

function pct_start_waitloop () {
  if [ "$(pct status $CTID)" = 'status: stopped' ]
  then
    msg "Starting CT $CTID..."
    pct start $CTID
    msg "Waiting to hear from CT $CTID..."
    while ! [[ "$(pct status $CTID)" == "status: running" ]]
    do
      echo -n .
    done
    sleep 2
    info "CT $CTID status: ${GREEN}running${NC}"
    echo
  fi
}

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

section "Configure ${OSTYPE^} CT system defaults"

# Start container
pct_start_waitloop

# Set Container locale
msg "Setting ${OSTYPE^} CT locale to match PVE host locale..."
PVE_HOST_LOCALE=$(locale | grep -w '^LANG=.*' | sed 's/LANG=//')
export PVE_HOST_LOCALE
pct exec $CTID -- locale-gen $PVE_HOST_LOCALE > /dev/null
pct exec $CTID -- update-locale LC_ALL=$PVE_HOST_LOCALE > /dev/null
pct exec $CTID -- locale-gen --purge $PVE_HOST_LOCALE > /dev/null
pct exec $CTID -- dpkg-reconfigure --frontend noninteractive locales 2> /dev/null

# Update container OS
msg "Updating ${OSTYPE^} CT OS (be patient, might take a while)..."
pct exec $CTID -- apt-get update -y 2> /dev/null
pct exec $CTID -- apt-get upgrade -y 2> /dev/null
pct exec $CTID -- apt-get autoremove -y 2> /dev/null

# Configuring Ubuntu for unattended upgrades
msg "Setting ${OSTYPE^} CT for unattended upgrades..."
pct exec $CTID -- apt-get install unattended-upgrades -yqq 2> /dev/null
pct exec $CTID -- systemctl enable unattended-upgrades

# Installing HTTPS transport
msg "Installing HTTPS transport for APT..."
pct exec $CTID -- apt-get install apt-transport-https -yqq 2> /dev/null

# Installing GnuPG
msg "Installing GnuPG and CA Certificates..."
pct exec $CTID -- apt-get install gnupg2 ca-certificates -yqq 2> /dev/null

# GPG creating defaults
msg "Creating GnuPG default directory, keybox and trustdb..."
pct exec $CTID -- gpg -k &> /dev/null

# Installing curl
msg "Installing curl..."
pct exec $CTID -- apt-get install curl -yqq 2> /dev/null

# msg "Installing ACL..."
msg "Installing ACL (Access Control Lists)..."
pct exec $CTID -- apt-get install acl -yqq 2> /dev/null

# msg "Installing BC..."
msg "Installing BC..."
pct exec $CTID -- apt-get install bc -yqq 2> /dev/null
echo

# msg "Rebooting LXC"
wait 2
msg "Rebooting LXC..."
pct_stop_waitloop
pct_start_waitloop
#-----------------------------------------------------------------------------------