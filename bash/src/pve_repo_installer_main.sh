#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_repo_installer_main.sh
# Description:  Main installer script
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Installer cleanup
function installer_cleanup() {
rm -R ${REPO_TEMP}/${GIT_REPO} &> /dev/null
if [ -f ${REPO_TEMP}/${GIT_REPO}.tar.gz ]; then
  rm ${REPO_TEMP}/${GIT_REPO}.tar.gz > /dev/null
fi
}

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

#---- Check and Create vm installer list
vm_input_LIST=()
while IFS=':' read name build_type vm_type desc; do
  # Skip # lines
  [[ "$name" =~ ^\#.*$ ]] && continue
  # Set installer filename
  installer_filename="$(echo ${GIT_REPO} | sed 's/-/_/')_${vm_type}_${name}_installer.sh"
  # Check installer filename exists
  if [ -f "${SRC_DIR}/${build_type}/${installer_filename}" ]; then
    vm_input_LIST+=( "${name}:${build_type}:${vm_type}:${desc}" )
  fi
done < <( printf '%s\n' "${vm_LIST[@]}" )

#---- Run Installer
while true; do
  section "Select a Installer"

  msg_box "#### SELECT A INSTALLER ####\n\nSelect a application installer or service from the list or 'None - Exit this installer' to leave.\n\nAny terminal inactivity is caused by background tasks being run, system updating or downloading of Linux files. So be patient because some tasks can be slow."
  echo
  # Create menu list
  unset OPTIONS_VALUES_INPUT
  unset OPTIONS_LABELS_INPUT
  while IFS=':' read name build_type vm_type desc; do
    # Set name var
    if [[ ${build_type,,} =~ ${name,,} ]]; then 
      name_var="${name^}"
    else
      name_var="${build_type^} ${name^}"
    fi
    # Check for existing CT/VM
    if [[ $(pct list | awk 'NR > 1 { OFS = ":"; print $3 }' | grep "^${name,,}(.\|-)\?[0-9]\+\?$") ]] && [ "${vm_type}" = 'ct' ]; then
      OPTIONS_VALUES_INPUT+=( "${name,,}:${build_type,,}:ct" )
      OPTIONS_LABELS_INPUT+=( "${name_var} - ${desc^} ( '${name^} CT' already exists )" )
    elif [[ $(qm list | awk '{ if (NR!=1) { print $2 }}' 2> /dev/null | grep "^${name,,}(.\|-)\?[0-9]\+\?$") ]] && [ "${vm_type}" = 'vm' ]; then
      OPTIONS_VALUES_INPUT+=( "${name,,}:${build_type,,}:vm" )
      OPTIONS_LABELS_INPUT+=( "${name_var} - ${desc^} ( '${name^} VM' already exists )" )
    else
      OPTIONS_VALUES_INPUT+=( "${name,,}:${build_type,,}:${vm_type,,}" )
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
  if [ ${RESULTS} == 'TYPE00' ]; then
    # Exit installation
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    sleep 1
    break
  else
    # Set Hostname
    APP_NAME=$(echo ${RESULTS} | awk -F':' '{ print $1 }')

    # App dir
    APP_DIR=$(echo ${RESULTS} | awk -F':' '{ print $2 }')

    # VM type
    VM_TYPE=$(echo ${RESULTS} | awk -F':' '{ print $3 }')

    # Set Installer App script name
    GIT_APP_SCRIPT="$(echo ${GIT_REPO} | sed 's/-/_/')_${VM_TYPE}_${APP_NAME}_installer.sh"

    # Run Toolbox
    source ${SRC_DIR}/${APP_DIR}/${GIT_APP_SCRIPT}
  fi

  # Reset Section Head
  SECTION_HEAD="$(echo ${GIT_REPO} | sed -E 's/(\-|\.|\_)/ /' | awk '{print toupper($0)}')"
done

#---- Cleanup
installer_cleanup

#-----------------------------------------------------------------------------------