#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvetool_ct_ubuntuversionupdater.sh
# Description:  This script is for PVE Ubuntu CT Release Upgrade
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/common/pve/tool/pvetool_ct_ubuntuversionupdater.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_DIR="${DIR}/../../common"
COMMON_PVE_SRC="${DIR}/../src"

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
source ${COMMON_PVE_SRC}/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='PVE OS Upgrade'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Update & Upgrade
section "Upgrade OS, software packages and apply patches."

msg_box "#### PLEASE READ CAREFULLY ####\n
This program will update and upgrade your PVE container. User input is required. The program will create, edit and/or change system files on '${HOSTNAME^^}'. When an optional default setting is provided you may accept the default by pressing ENTER on your keyboard or change it to your preferred value."
echo
while true; do
  read -p "Proceed with a upgrade of '${HOSTNAME^^}' [y/n]? " -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      OS_UPDATE=0
      echo
      break
      ;;
    [Nn]*)
      OS_UPDATE=1
      info "You have chosen to skip this step. Aborting the NAS upgrade."
      sleep 1
      exit 0
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done

# Perform upgrades
if [ ${OS_UPDATE} == 0 ]; then
  msg "Performing ${HOSTNAME^^} package repository update..."
  apt-get update -y
  msg "Installing ${HOSTNAME^^} package upgrades..."
  apt-get upgrade -y
  msg "Performing cleanup of ${HOSTNAME^^} cache & old repository package files..."
  apt-get clean -y > /dev/null 2>&1
  msg "Performing autoremove on unused dependencies ..."
  apt-get autoremove -y > /dev/null 2>&1
  msg "${HOSTNAME^^} update and upgrade status:\n"
  indent lsb_release -idc
  echo
fi


#---- Full System Release Upgrade
if [ $(do-release-upgrade -c > /dev/null; echo $?) = 0 ]; then
  section "Ubuntu OS release upgrade."
  msg "Checking for a new Ubuntu OS release..."
  info "$(do-release-upgrade -c | sed '$d' | sed '1d') (Current Vers: $(lsb_release -d | awk -F'\t' '{print $2}'))"
  echo
  msg_box "#### PLEASE READ CAREFULLY - WARNING ####\n\nA Ubuntu OS release upgrade is available. This is a major upgrade. Software applications might NOT work properly after upgrading. It is recommended you perform a PVE CT backup before performing this upgrade. User input is required. The update will create, edit and/or change system files on '${HOSTNAME^^}'. When an optional default setting is provided you may accept the default by pressing ENTER on your keyboard or change it to your preferred value."
  echo
  while true; do
    read -p "Proceed with a OS RELEASE upgrade on '${HOSTNAME^^}' [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        RELEASE_UPGRADE=0
        echo
        break
        ;;
      [Nn]*)
        RELEASE_UPGRADE=1
        info "You have chosen to skip this step. '${HOSTNAME^^}' will not be upgraded."
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
else
  RELEASE_UPGRADE=1
fi

# Release upgrade
if [ ${RELEASE_UPGRADE} == 0 ]; then
  msg "Performing release upgrade (be patient, this will take a while)..."
  apt-get update -y > /dev/null 2>&1
  do-release-upgrade -f DistUpgradeViewNonInteractive
  info "'$(echo ${HOSTNAME^^})' CT has been upgraded to: ${YELLOW}$(lsb_release -d | awk -F'\t' '{print $2}')${NC}"
  msg "Performing ${HOSTNAME^^} package repository update..."
  apt-get update -y
  msg "Installing ${HOSTNAME^^} package upgrades..."
  apt-get upgrade -y
  echo
fi


#---- Finish ####
section "Completion Status."

if [ ${OS_UPDATE} == 0 ] && [ ${RELEASE_UPGRADE} == 0 ]; then
    msg "The following upgrade tasks have been successfully performed on '${HOSTNAME^^}':\n  --  updated package lists\n  --  installed latest versions of packages\n  --  upgraded '${HOSTNAME^^}' to the latest Ubuntu OS release ( New Version:  $(lsb_release -d | awk -F'\t' '{print $2}') )"
    echo
elif [ ${OS_UPDATE} == 0 ] && [ ${RELEASE_UPGRADE} == 1 ]; then
    msg "The following upgrade tasks have been successfully performed on '${HOSTNAME^^}':\n  --  updated package lists\n  --  installed latest versions of packages"
    echo
fi

# Cleanup
if [ -z "${PARENT_EXEC+x}" ]; then
  trap cleanup EXIT
fi