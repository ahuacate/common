#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_identify_storagepath.sh
# Description:  Identify and set Storage path
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Select or input a storage path ( set DIR_SCHEMA )

section "Select a Storage Location"
# Create print display
print_DISPLAY=()
while IFS=',' read -r dir; do
  print_DISPLAY+=( "$dir,$(df -Th ${dir} | tail -n +2 | awk '{ print $2 }'),$(df -h ${dir} | tail -n +2 | awk '{ print $4 }')" )
done <<< $( df -hx tmpfs --output=target | sed '1d' | grep -v '/$\|^/dev.*\|^/var.*\|^/boot.*\|^/rpool.*\|/etc.*' )
print_DISPLAY+=( "Other. Input your own storage path,-,-" )

section "Select a Storage Location"
msg_box "#### PLEASE READ CAREFULLY - SELECT A STORAGE LOCATION ####\n\nA storage location is a parent directory, LVM volume, ZPool or another storage filesystem where your new folder shares will be created. A scan shows the following available storage locations:\n\n$(printf '%s\n' "${print_DISPLAY[@]}" | column -s "," -t -N "STORAGE DEVICE,FS TYPE,CAPACITY" | indent2)\n\nThe User must now select a storage location. Or select 'other' to manually input the full storage path."
echo
msg "Select a storage location from the menu:"
while true; do
  unset stor_LIST
  stor_LIST+=( $(df -hx tmpfs --output=target | sed '1d' | grep -v '/$\|^/dev.*\|^/var.*\|^/boot.*\|^/rpool.*\|/etc.*' | sed -e '$aother') )
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${stor_LIST[@]}")
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${stor_LIST[@]}" | awk '{if ($1 != "other") print $1; else print "Other. Input your own storage path"; }')
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  DIR_SCHEMA=${RESULTS}
  if [ ${DIR_SCHEMA} == "other" ]; then
    # Input a storage path
    while true; do
      msg "The User must now enter a valid storage location path. For example:\n
        --  /srv/nas-01
        --  /srv/dev-disk-by-uuid-*
        --  /mnt/storage
        --  /volume1"
      echo
      read -p "Enter a valid storage path: " -e stor_path
      if [ ! -d ${stor_path} ]; then
        warn "There are problems with your input:
        
        1. '${stor_path}' location does NOT exist!
        
        Try again..."
        echo
      elif [ -d ${stor_path} ]; then
        while true; do
          read -p "Re-confirm storage path '${stor_path}' is correct [y/n]?: " -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              info "Storage path set: ${YELLOW}${stor_path}${NC}"
              DIR_SCHEMA="${stor_path}"
              echo
              break 3
              ;;
            [Nn]*)
              msg "Try again..."
              echo
              break
              ;;
            *)
              warn "Error! Entry must be 'y' or 'n'. Try again..."
              echo
              ;;
          esac
        done
      fi
    done
  else
    break
  fi
done
#-----------------------------------------------------------------------------------