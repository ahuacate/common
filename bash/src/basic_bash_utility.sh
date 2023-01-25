#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     bash_basic_defaults.sh
# Description:  Basic bash defaults for VMs and CTs
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Regex for functions
ip4_regex='^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
ip6_regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'
hostname_regex='^(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$'
domain_regex='^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$'
R_NUM='^[0-9]+$' # Check numerals only

#---- Terminal settings
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'
UNDERLINE=$'\033[4m'
printf '\033[8;40;120t'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Stop System.d Services
function pct_stop_systemctl() {
  # Usage: pct_stop_systemctl "name.service"
  local service_name="$1"
  if [ "$(systemctl is-active $service_name)" = 'inactive' ]
  then
    # Stop service
    sudo systemctl stop $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'inactive' ]]
    do
      echo -n .
    done
  fi
}

# Start System.d Services
function pct_start_systemctl() {
  # Usage: pct_start_systemctl "jellyfin.service"
  local service_name="$1"
  # Reload systemd manager configuration
  sudo systemctl daemon-reload
  if [ "$(systemctl is-active $service_name)" = 'inactive' ]
  then
    # Stop service
    sudo systemctl start $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'active' ]]
    do
      echo -n .
    done
  fi
}

#-----------------------------------------------------------------------------------