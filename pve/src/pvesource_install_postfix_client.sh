#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_install_postfix_client.sh
# Description:  Source script for installing and setup Postfix client
#               Requires PVE host install: 'pve_host_setup_postfix.sh'
#               Host SMTP_STATUS=1 to install
#               Check arg at head of /etc/postfix/main.cf: # ahuacate_smtp=1
#               Script works with PVE CTs (LXC) only
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Run SMTP check
check_smtp_status
if [ ! "${SMTP_STATUS}" == '1' ]; then
  return
fi

# Set SMTP server relay address
SMTP_SERVER_ADDRESS=$(hostname -I)

#---- Install and Configure SMTP email client
section "Configure Postfix"

# Install Postfix 
pct exec $CTID -- apt-get install postfix -y
# Install mailutils
pct exec $CTID -- apt-get install mailutils -y
# Install shareutils
pct exec $CTID -- apt-get install sharutils -y

# Set SMTP relay server address
pct exec $CTID -- bash -c "postconf -e relayhost=${SMTP_SERVER_ADDRESS}"

# Create check line in /etc/postfix/main.cf
pct exec $CTID -- sed -i \
    -e '/^#\?\(\s*ahuacate_smtp\s*=\s*\).*/{s//\11/;:a;n;ba;q}' \
    -e '1i ahuacate_smtp=1' /etc/postfix/main.cf

# Reload Postfix configuration file /etc/postfix/main.cf
pct exec $CTID -- systemctl restart postfix.service

info "Postfix email status: ${YELLOW}active${NC}"
echo
#-----------------------------------------------------------------------------------