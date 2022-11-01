#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_identify_volumedir.sh
# Description:  Identify and set Volume dir
#               Run after 'nas_identify_storagepath.sh' (optional)
#               This script modifies the DIR_SCHEMA to include a volume
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

  # Set VOLUME_VAR
  if [ ! -d ${RESULTS} ]; then
    mkdir -p ${RESULTS}
  fi
  VOLUME_DIR=$(printf '%s\n' "${RESULTS[@]}" | sed "s|${DIR_SCHEMA}/||")
fi
#-----------------------------------------------------------------------------------