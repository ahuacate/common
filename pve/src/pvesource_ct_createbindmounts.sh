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

if [ ${#pvesm_input_LIST[@]} -ge '1' ]
then
  msg "Creating ${HOSTNAME^} CT storage bind mounts..."
  i=0
  while IFS=',' read -r PVE_MNT CT_MNT
  do
    pct set $CTID -mp$i /mnt/pve/$PVE_MNT,mp=$CT_MNT
    ((i=i+1))
    info "\t${i}. Storage bind mount created: $PVE_MNT ---> ${YELLOW}$CT_MNT${NC}"
  done <<< $(printf '%s\n' "${pvesm_input_LIST[@]}")
  echo
else
  info "No storage bind mount inputs are available or have been configured.\nSkipping this step."
  echo
fi
#-----------------------------------------------------------------------------------