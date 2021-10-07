#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvetool_ct_updater.sh
# Description:  Simple bash script to APT updating all LXC/CT CTIDS.
#               Stopped CTs will be started, updated and returned to stopped status.
#               Running CTs will be updated.
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/common/master/pve/tool/pvetool_ct_updater.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
PVE_SOURCE="$DIR/../../bash/source"

#---- Dependencies -----------------------------------------------------------------

# Check for Internet connectivity
if nc -zw1 google.com 443; then
  echo
else
  echo "Checking for internet connectivity..."
  echo -e "Internet connectivity status: \033[0;31mDown\033[0m\n\nCannot proceed without a internet connection.\nFix your PVE hosts internet connection and try again..."
  echo
  exit 0
fi
# Run Bash Header
source $PVE_SOURCE/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='PVE CT Updater'
# list of container ids we need to iterate through
CTIDS=$(pct list | tail -n +2 | cut -f1 -d' ')
# Update function
function update_container () {
  msg "Updating PVE $CTID..."
  # to chain commands within one exec we will need to wrap them in bash
  pct exec $CTID -- bash -c "apt update && apt upgrade -y && apt autoremove -y"
  echo
}

function pct_start_waitloop () {
  if [ "$(pct status $CTID)" == "status: stopped" ]; then
    msg "Starting CT $CTID..."
    pct start $CTID
    msg "Waiting to hear from CT $CTID..."
    while ! [[ "$(pct status $CTID)" == "status: running" ]]; do
      echo -n .
    done
    sleep 2
    info "CT $CTID status: ${GREEN}running${NC}"
    echo
  fi
}

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------
section "Performing Updates"

for CTID in $CTIDS
do
  status=`pct status $CTID`
  if [ "$status" == "status: stopped" ]; then
    msg "PVE CT $CTID status: ${RED}stopped${NC}
    pct_start_waitloop
    update_container $CTID
    msg "Returning PVE CT $CTID to former state...
    pct shutdown $CTID
  elif [ "$status" == "status: running" ]; then
    update_container $CTID
  fi
done; wait