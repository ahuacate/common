#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_install_postfix_client.sh
# Description:  Source script for installing and setup Postfix client
#               Requires PVE host install: 'pve_host_setup_postfix.sh'
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Check IP
ipvalid () {
  # Set up local variables
  local ip=${1:-1.2.3.4}
  local IFS=.; local -a a=($ip)
  # Start with a regex format test
  [[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
  # Test values of quads
  local quad
  for quad in {0..3}; do
    [[ "${a[$quad]}" -gt 255 ]] && return 1
  done
  return 0
}

#---- Static Variables -------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='Postfix Client'

# # Check for PVE Hostname mod
# if [ -z "${HOSTNAME_FIX+x}" ]; then
#   PVE_HOSTNAME=$HOSTNAME
# fi

# Local network
LOCAL_NET=$(hostname -I | awk -F'.' -v OFS="." '{ print $1,$2,"0.0/16" }')

# Postfix vars
POSTFIX_CONFIG=/etc/postfix/main.cf
POSTFIX_SASL_PWD=/etc/postfix/sasl_passwd
POSTFIX_SASL_DB=/etc/postfix/sasl_passwd.db

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Install and Configure SSMTP Email