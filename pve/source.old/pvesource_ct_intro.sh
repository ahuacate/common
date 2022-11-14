#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_intro.sh
# Description:  Source script for "Introduction" body text at opening of CT Script
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Introduction
clear
section "Introduction"
msg_box "#### PLEASE READ CAREFULLY ####\n
This Easy Script will create a $SECTION_HEAD Proxmox container (CT). Installer input is required. The Easy Script will create, edit and/or change system files on your Proxmox host. When an optional default setting is provided you may accept the default by pressing ENTER on your keyboard or change it to your preferred value.$(if [ -f pvesm_required_list ] && [ $(cat pvesm_required_list | grep -v 'none' | wc -l) -gt 0 ]; then echo -e "\n\nYour new ${CT_HOSTNAME_VAR^} uses bind mounts to access arbitrary directories (PVESM storage mounts) from your Proxmox VE host to the container. Your PVE host must have all $(cat pvesm_required_list | awk -F'|' '{print $1}' | grep -v 'none' | wc -l) of the required storage mounts $(cat pvesm_required_list | grep -vi 'none' | awk -F'|' '{print $1}' | tr '\n' ',' | sed 's/,$//' | sed -e 's/^/(/g' -e 's/$/)/g') for this Easy Script installation to be successful.";fi)"
sleep 1

echo
while true; do
  read -p "Proceed to create a new '${SECTION_HEAD}' CT [y/n]? " -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      info "Proceeding with the installation."
      echo
      break
      ;;
    [Nn]*)
      info "You have chosen to skip this step. Aborting installation."
      rm -rf ${TEMP_DIR}
      exit 0
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done