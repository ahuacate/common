#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_repo_installer_main.sh
# Description:  Main installer script
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

#---- Easy Script Section Header Body Text
SECTION_HEAD="$(echo "$GIT_REPO" | sed -E 's/(\-|\.|\_)/ /' | awk '{print toupper($0)}')"

#---- Script path variables
DIR="$REPO_TEMP/$GIT_REPO"
SRC_DIR="$DIR/src"
COMMON_DIR="$DIR/common"
COMMON_PVE_SRC_DIR="$DIR/common/pve/src"
SHARED_DIR="$DIR/shared"
TEMP_DIR="$DIR/tmp"

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Run Bash Header
source $COMMON_PVE_SRC_DIR/pvesource_bash_defaults.sh

#---- Check and Create vm installer list
vm_input_LIST=()
while IFS=':' read name build vm_type desc
do
  # Skip # lines
  [[ "$name" =~ ^\#.*$ ]] && continue
  # Set installer filename
  installer_filename="$(echo "$GIT_REPO" | sed 's/-/_/')_${vm_type}_${name}_installer.sh"
  # Check installer filename exists
  if [ -f "$SRC_DIR/$build/$installer_filename" ]
  then
    vm_input_LIST+=( "${name}:${build}:${vm_type}:${desc}" )
  fi
done < <( printf '%s\n' "${vm_LIST[@]}" )

#---- Run Installer
while true
do
  section "Select a Installer"
  msg_box "#### SELECT A INSTALLER ####\n\nPlease choose an application installer or service from the list provided, or select 'None' to exit this installer. If you experience any terminal inactivity, it may be due to background tasks running, system updates in progress, or the downloading of required files. It's important to remain patient, as some tasks may take longer to complete."
  echo
  # Create menu list
  unset OPTIONS_VALUES_INPUT
  unset OPTIONS_LABELS_INPUT
  while IFS=':' read name build vm_type desc
  do
    # Set name var
    if [[ ${build,,} =~ ${name,,} ]]
    then 
      name_var="${name^}"
    else
      name_var="${build^} ${name^}"
    fi
    # Check for existing CT/VM
    if [[ $(pct list | awk 'NR > 1 { OFS = ":"; print $3 }' | egrep "^${name,,}(-|\.)?([0-9]+)?$") ]] && [ "$vm_type" = 'ct' ]
    then
      OPTIONS_VALUES_INPUT+=( "${name,,}:${build,,}:ct" )
      OPTIONS_LABELS_INPUT+=( "${name_var} - ${desc^} ( '${name^} CT' already exists )" )
    elif [[ $(qm list | awk '{ if (NR!=1) { print $2 }}' 2> /dev/null | egrep "^${name,,}(-|\.)?([0-9]+)?$") ]] && [ "$vm_type" = 'vm' ]
    then
      OPTIONS_VALUES_INPUT+=( "${name,,}:${build,,}:vm" )
      OPTIONS_LABELS_INPUT+=( "${name_var} - ${desc^} ( '${name^} VM' already exists )" )
    else
      OPTIONS_VALUES_INPUT+=( "${name,,}:${build,,}:${vm_type,,}" )
      OPTIONS_LABELS_INPUT+=( "${name_var} - ${desc^}" ) 
    fi
  done < <( printf '%s\n' "${vm_input_LIST[@]}" )
  # Add exit option to menu
  OPTIONS_VALUES_INPUT+=( "TYPE00" )
  OPTIONS_LABELS_INPUT+=( "None - Exit this installer" ) 
  # Menu options
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"

  # Run the CT installer
  if [ "$RESULTS" = 'TYPE00' ]
  then
    # Exit installation
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    sleep 1
    break
  else
    # Set Hostname
    app_name=$(echo "$RESULTS" | awk -F':' '{ print $1 }')

    # App dir
    app_dir=$(echo "$RESULTS" | awk -F':' '{ print $2 }')

    # VM type
    vm_type=$(echo "$RESULTS" | awk -F':' '{ print $3 }')

    # Set Installer App script name
    git_app_script="$(echo "$GIT_REPO" | sed 's/-/_/')_${vm_type}_${app_name}_installer.sh"

    # Run Toolbox
    source "$SRC_DIR/$app_dir/$git_app_script"
  fi

  # Reset Section Head
  SECTION_HEAD="$(echo "$GIT_REPO" | sed -E 's/(\-|\.|\_)/ /' | awk '{print toupper($0)}')"
done

#---- Cleanup
installer_cleanup
#-----------------------------------------------------------------------------------