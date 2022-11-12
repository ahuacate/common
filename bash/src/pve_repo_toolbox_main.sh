#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_repo_installer_main.sh
# Description:  Main installer script
# Note:         Works with PVE CTs only
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

#---- Easy Script Section Header Body Text
SECTION_HEAD="$(echo ${GIT_REPO} | sed -E 's/(\-|\.|\_)/ /' | awk '{print toupper($0)}')"

#---- Script path variables
DIR="${REPO_TEMP}/${GIT_REPO}"
SRC_DIR="${DIR}/src"
COMMON_DIR="${DIR}/common"
COMMON_PVE_SRC_DIR="${DIR}/common/pve/src"
SHARED_DIR="${DIR}/shared"
TEMP_DIR="${DIR}/tmp"

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Run Bash Header
source ${COMMON_PVE_SRC_DIR}/pvesource_bash_defaults.sh

#---- Check and Create vm toolbox list
vm_input_LIST=()
while read -r line; do
  var1=$(awk -F'_' '{print $(NF-1)}' <<< $line)
  var2=$(awk -F'/' '{print $(NF-1)}' <<< $line)
  vm_input_LIST+=( "${var1}:${var2}" )
done < <( find "${SRC_DIR}/" -type f -regex "^.*/$(echo ${GIT_REPO} | sed 's/-/_/').*\_toolbox\.sh$" | sed "/^.*\/$(echo ${GIT_REPO} | sed 's/-/_/')\_installer\.sh$/d" )


#---- Run Installer
while true; do
  section "Select a Toolbox"

  msg_box "#### SELECT A PRODUCT TOOLBOX ####\n\nSelect a product toolbox from the list or 'None - Exit this installer' to leave.\n\nAny terminal inactivity is caused by background tasks be run, system updating or downloading of Linux files. So be patient because some tasks can be slow.\n\nIf no Toolbox options are available its because no Toolbox exists for any of your installed PVE CTs."
  echo
  # Create menu list
  pct_LIST=( $(pct list | awk 'NR > 1 { OFS = ":"; print $NF,$1 }') )
  unset OPTIONS_VALUES_INPUT
  unset OPTIONS_LABELS_INPUT
  while IFS=':' read name build; do
    if [[ $(printf '%s\n' "${pct_LIST[@]}" | grep -Po "^${name,,}[.-]?[0-9]+?:[0-9]+$") ]] && [ -f "${SRC_DIR}/${build,,}/$(echo ${GIT_REPO} | sed 's/-/_/')_ct_${name,,}_toolbox.sh" ]; then
      OPTIONS_VALUES_INPUT+=( "${name,,}:$(printf '%s\n' "${pct_LIST[@]}" | grep -Po "^${name,,}[_-]?[0-9]?:[0-9]+$" | awk -F':' '{ print $2 }')" )
      OPTIONS_LABELS_INPUT+=( "${name^} Toolbox" )
    fi
  done < <( printf '%s\n' "${vm_input_LIST[@]}" )
  echo hello
  OPTIONS_VALUES_INPUT+=( "TYPE00" )
  OPTIONS_LABELS_INPUT+=( "None - Exit this installer" ) 
  # Menu options
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"

  # Set App name
  if [ ${RESULTS} == 'TYPE00' ]; then
    # Exit installation
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    sleep 1
    break
  else
    # Set Hostname
    APP_NAME=$(echo ${RESULTS} | awk -F':' '{ print $1 }')

    # Set CTID
    CTID=$(echo ${RESULTS} | awk -F':' '{ print $2 }')

    # Check CT run status
    pct_start_waitloop

    # Set Toolbox App script name
    GIT_APP_SCRIPT="pve_homelab_ct_${APP_NAME}_toolbox.sh"

    # Run Toolbox
    source ${SRC_DIR}/${APP_NAME}/${GIT_APP_SCRIPT}
  fi

  # Reset Section Head
  SECTION_HEAD="$(echo ${GIT_REPO} | sed -E 's/(\-|\.|\_)/ /' | awk '{print toupper($0)}')"
done

#---- Cleanup
installer_cleanup

#-----------------------------------------------------------------------------------