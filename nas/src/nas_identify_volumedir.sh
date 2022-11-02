#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_identify_volumedir.sh
# Description:  Identify and set Volume dir
#               Run after 'nas_identify_storagepath.sh' (optional) before 'nas_basefoldersetup.sh'
#               This script sets var VOLUME_DIR
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Volume dir name
VOLUME_VAR='volume'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Check 'DIR_SCHEMA' is set
if [ ! -n ${DIR_SCHEMA} ]; then
  # Aborting install
  warn "Variable 'DIR_SCHEMA' is unset. Aborting. Bye... "
  echo
  exit 0
fi

#---- Select storage volume dir
# Create volume list
if [[ $(ls -d ${DIR_SCHEMA}/${VOLUME_VAR}[1-9] 2>/dev/null) ]]; then
  volume_dir_LIST=( $(ls -d ${DIR_SCHEMA}/${VOLUME_VAR}[1-9]) )
else
  volume_dir_LIST=()
fi

# Set 'VOLUME_VAR'
if [ "${#volume_dir_LIST[@]}" == '0' ]; then
  # Create volume1
  VOLUME_DIR="${VOLUME_VAR}1"
  mkdir -p ${DIR_SCHEMA}/${VOLUME_VAR}
# elif [ "${#volume_dir_LIST[@]}" == '1' ]; then
#   # Set VOLUME_VAR
#   VOLUME_DIR="$(printf '%s\n' "${volume_dir_LIST[@]}" | sed "s|${DIR_SCHEMA}/||")"
elif [ "${#volume_dir_LIST[@]}" -ge '1' ]; then
  #Create or set storage volume dir
  msg_box "#### PLEASE READ CAREFULLY - SELECT OR CREATE A VOLUME ####\n\nVolumes provide the basic first level storage space on your NAS. All of your shared folders are created in a volume folder. Therefore, before you start you will need to create at least one volume."
  msg "Select or create a volume from the menu:"
  OPTIONS_VALUES_INPUT=( $(printf '%s\n' "${volume_dir_LIST[@]}") )
  OPTIONS_LABELS_INPUT=( $(printf '%s\n' "${volume_dir_LIST[@]}") )
  # Add new 'volume[1-9]' option
  if [[ -d ${DIR_SCHEMA}/${VOLUME_VAR}1 ]]; then
    i=1
    while [[ -d ${DIR_SCHEMA}/${VOLUME_VAR}$i ]]; do
      let i++
    done
    new_dir=${VOLUME_VAR}$i
  fi
  OPTIONS_VALUES_INPUT+=( "${DIR_SCHEMA}/${new_dir}" )
  OPTIONS_LABELS_INPUT+=( "Create new volume -- ${DIR_SCHEMA}/${new_dir}" )
  # Add exit option to menu
  OPTIONS_VALUES_INPUT+=( "TYPE00" )
  OPTIONS_LABELS_INPUT+=( "None - Exit this installer" )
  # Menu options
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"
  if [ ${RESULTS} == 'TYPE00' ]; then
    # Exit installation
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    exit 0
  fi

  # Set volume dir
  VOLUME_DIR=$(printf '%s\n' "${RESULTS[@]}" | sed "s|${DIR_SCHEMA}/||")

  # Create new volume dir
  if [ ! -d ${DIR_SCHEMA}/${VOLUME_DIR} ]; then
    mkdir -p ${DIR_SCHEMA}/${VOLUME_DIR}
    chmod 0750 ${DIR_SCHEMA}/${VOLUME_DIR}
    chown root:users ${DIR_SCHEMA}/${VOLUME_DIR}
  fi
fi
#-----------------------------------------------------------------------------------