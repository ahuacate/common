#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_createbindmounts.sh
# Description:  Source script for creating CT bind mounts
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

if [[ -f pvesm_input_list ]] && [ $(cat pvesm_input_list | wc -l) -ge 1 ]; then
  msg "Creating ${CT_HOSTNAME^} CT bind mounts..."
  IFS=' '
  i=0
  while read -r PVE_MNT CT_MNT; do
    pct set $CTID -mp$i /mnt/pve/$PVE_MNT,mp=$CT_MNT
    ((i=i+1))
    info "${CT_HOSTNAME^} CT bind mount created: $PVE_MNT ---> ${YELLOW}$CT_MNT${NC}"
  done < pvesm_input_list
  echo
elif [[ -f pvesm_input_list ]] && [ $(cat pvesm_input_list | wc -l) = 0 ] || [[ ! -f pvesm_input_list ]]; then
  info "No CT bind mount inputs are available or have been configured. Skipping this step."
  echo
fi