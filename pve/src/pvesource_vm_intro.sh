#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_vm_intro.sh
# Description:  Source script for "Introduction" body text at opening of VM Script
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
msg_box "#### PLEASE READ CAREFULLY ####\n\nThis Easy Script will create a Proxmox virtual machine (VM). Installer input is required. The Easy Script may create, edit and/or change system files on your Proxmox host. When an optional default setting is provided you may accept the default by pressing ENTER on your keyboard or change it to your preferred value."
sleep 1

echo
while true; do
  read -p "Proceed to create a new '${SECTION_HEAD}' VM [y/n]? " -n 1 -r YN
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