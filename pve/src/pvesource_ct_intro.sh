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
msg_box "#### PLEASE READ CAREFULLY ####\n\nThis Easy Script will create a Proxmox container (CT) or VM. Your input is required. The Easy Script will create, edit and/or change system files on your Proxmox host. When an optional default setting is provided you may accept the default by pressing ENTER on your keyboard or change it to your preferred value.$(if [ ${#pvesm_required_LIST[@]} -gt 0 ]; then echo -e "\n\nYour new '${HOSTNAME^}' CT uses bind mounts to access arbitrary directories (PVESM storage mounts) from your Proxmox VE host to the container.\n\n$(printf '%s\n' "${pvesm_required_LIST[@]}" | column -s ":" -t -N "MEDIA CATEGORY,DESCRIPTION" | indent2)\n\nYour PVE host must have all ${#pvesm_required_LIST[@]} of the required storage mounts to complete this installation.";fi)"
sleep 1

echo
while true
do
  read -p "Proceed to create a new '${SECTION_HEAD}' machine [y/n]? " -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      info "Proceeding with the installation."
      echo
      break
      ;;
    [Nn]*)
      info "You have chosen to skip this step. Aborting installation."
      rm -rf "$TEMP_DIR"
      exit 0
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done
#-----------------------------------------------------------------------------------