#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_identify_storagepath.sh
# Description:  Identify and set Main Storage and Fast Storage paths
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Select or input a main storage path ( set DIR_MAIN_SCHEMA )

section "Select a Main Storage Location"
# Create print display
print_DISPLAY=()
while IFS=',' read -r dir
do
  print_DISPLAY+=( "$dir,$(df -Th ${dir} | tail -n +2 | awk '{ print $2 }'),$(df -h ${dir} | tail -n +2 | awk '{ print $4 }')" )
done <<< $( df -hx tmpfs --output=target | sed '1d' | grep -v '/$\|^/dev.*\|^/var.*\|^/boot.*\|^/rpool.*\|/etc.*' )
print_DISPLAY+=( "Other. Input your own storage path,-,-" )

msg_box "#### PLEASE READ CAREFULLY - SELECT A MAIN STORAGE LOCATION ####\n\nA main storage location is a parent directory, LVM volume, ZPool, MergeFS Pool or another storage filesystem where standard basic folder shares like homes, music, photo and video storage folder and files will be created. This is normally your largest NAS storage location. A scan shows the following available storage locations:\n\n$(printf '%s\n' "${print_DISPLAY[@]}" | column -s "," -t -N "STORAGE DEVICE,FS TYPE,CAPACITY" | indent2)\n\nThe User must now select their maain storage location. Or select 'other' to manually input the full storage path."
echo
msg "Select a main storage location from the menu:"
while true
do
  unset stor_LIST
  stor_LIST+=( $(df -hx tmpfs --output=target | sed '1d' | grep -v '/$\|^/dev.*\|^/var.*\|^/boot.*\|^/rpool.*\|/etc.*') )
  OPTIONS_VALUES_INPUT=( $(printf '%s\n' "${stor_LIST[@]}") )
  OPTIONS_LABELS_INPUT=( $(printf '%s\n' "${stor_LIST[@]}") )
  # Add 'other' option
  OPTIONS_VALUES_INPUT+=( "other" )
  OPTIONS_LABELS_INPUT+=( "Input your own storage path" )
  # Add exit option to menu
  OPTIONS_VALUES_INPUT+=( "TYPE00" )
  OPTIONS_LABELS_INPUT+=( "None - Exit this installer" )
  # Menu options
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"

  if [ "$RESULTS" = 'other' ]; then
    # Input a storage path
    while true
    do
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
      elif [ -d "$stor_path" ]; then
        while true
        do
          read -p "Re-confirm storage path '$stor_path' is correct [y/n]?: " -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              info "Storage path set: ${YELLOW}$stor_path${NC}"
              DIR_SCHEMA="$stor_path"
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
  elif [ "$RESULTS" = 'TYPE00' ]; then
    # Exit installation
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    exit 0
  else
    # Set 'DIR_MAIN_SCHEMA'
    DIR_MAIN_SCHEMA="$RESULTS"
    break
  fi
done

#---- Select or input a fast storage path ( set DIR_FAST_SCHEMA )

section "Select a Fast or Temporary Storage Location"
# Create print display
print_DISPLAY=()
while IFS=',' read -r dir
do
  print_DISPLAY+=( "$dir,$(df -Th ${dir} | tail -n +2 | awk '{ print $2 }'),$(df -h ${dir} | tail -n +2 | awk '{ print $4 }')" )
done <<< $( df -hx tmpfs --output=target | sed '1d' | grep -v '/$\|^/dev.*\|^/var.*\|^/boot.*\|^/rpool.*\|/etc.*' )
print_DISPLAY+=( "Other. Input your own storage path,-,-" )

msg_box "#### PLEASE READ CAREFULLY - SELECT A FAST OR TEMPORARY STORAGE LOCATION ####\n\nA fast or temporary storage location is a parent directory, LVM volume, ZPool, MergeFS Pool or another storage filesystem where downloads, transcodes, public and temporary folders and files will be created. If you have a dedicated fast NVMe or SSD volume available then you should select it here. A scan shows the following available storage locations:\n\n$(printf '%s\n' "${print_DISPLAY[@]}" | column -s "," -t -N "STORAGE DEVICE,FS TYPE,CAPACITY" | indent2)\n\nThe User must now select a storage location. Or select 'other' to manually input the full storage path."
echo
msg "Select a fast or temporary storage location from the menu:"
while true
do
  unset stor_LIST
  stor_LIST+=( $(df -hx tmpfs --output=target | sed '1d' | grep -v "/$\|^/dev.*\|^/var.*\|^/boot.*\|^/rpool.*\|/etc.*\|${DIR_MAIN_SCHEMA}.*") )
  OPTIONS_VALUES_INPUT=( $(printf '%s\n' "${stor_LIST[@]}") )
  OPTIONS_LABELS_INPUT=( $(printf '%s\n' "${stor_LIST[@]}") )
  # Add existing main storage volume
  OPTIONS_VALUES_INPUT+=( "TYPE00" )
  OPTIONS_LABELS_INPUT+=( "Do not have fast storage. Use my main storage volume: ${DIR_MAIN_SCHEMA}" )
  # Add 'other' option
  OPTIONS_VALUES_INPUT+=( "other" )
  OPTIONS_LABELS_INPUT+=( "Input your own storage path" )
  # Menu options
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"

  if [ "$RESULTS" = 'other' ]; then
    # Input a storage path
    while true
    do
      msg "The User must now enter a valid storage location path. For example:\n
        --  /srv/nas-01
        --  /srv/dev-disk-by-uuid-*
        --  /mnt/storage
        --  /volume2"
      echo
      read -p "Enter a valid storage path: " -e stor_path
      if [ ! -d ${stor_path} ]; then
        warn "There are problems with your input:
        
        1. '${stor_path}' location does NOT exist!
        2. 'You can always input your main storage volume: ${DIR_MAIN_SCHEMA}'
        3. 'Input a different storage path'
        
        Try again..."
        echo
      elif [ -d "$stor_path" ]; then
        while true
        do
          read -p "Re-confirm storage path '$stor_path' is correct [y/n]?: " -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              info "Storage path set: ${YELLOW}$stor_path${NC}"
              DIR_FAST_SCHEMA="$stor_path"
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
  elif [ "$RESULTS" = 'TYPE00' ]; then
    # Set to use main storage volume
    msg "You have chosen to use your main storage location."
    DIR_FAST_SCHEMA="${DIR_MAIN_SCHEMA}"
    echo
    break
  else
    # Set 'DIR_FAST_SCHEMA'
    DIR_FAST_SCHEMA="$RESULTS"
    break
  fi
done
#-----------------------------------------------------------------------------------