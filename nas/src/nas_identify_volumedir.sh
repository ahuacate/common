#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_identify_volumedir.sh
# Description:  Identify and set Volume dir
#               Run after 'nas_identify_storagepath.sh' (optional) before 'nas_basefoldersetup.sh'
#               This script sets var VOLUME_MAIN_DIR
#               This script sets var VOLUME_FAST_DIR
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Main Volume dir name
VOLUME_MAIN_VAR='main_volume'
VOLUME_FAST_VAR='fast_volume'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Check 'DIR_MAIN_SCHEMA' is set
if [ ! -n ${DIR_MAIN_SCHEMA} ]; then
  # Aborting install
  warn "Variable 'DIR_MAIN_SCHEMA' is unset. Aborting. Bye... "
  echo
  exit 0
fi

# Check 'DIR_FAST_SCHEMA' is set
if [ ! -n ${DIR_FAST_SCHEMA} ]; then
  # Aborting install
  warn "Variable 'DIR_FAST_SCHEMA' is unset. Aborting. Bye... "
  echo
  exit 0
fi


#---- Select main storage volume dir
# Create main volume list
if [[ $(ls -d $DIR_MAIN_SCHEMA/${VOLUME_MAIN_VAR}[1-9] 2>/dev/null) ]]; then
  volume_main_dir_LIST=( $(ls -d $DIR_MAIN_SCHEMA/${VOLUME_MAIN_VAR}[1-9]) )
else
  volume_main_dir_LIST=()
fi

# Set 'VOLUME_MAIN_VAR'
if [ "${#volume_main_dir_LIST[@]}" = 0 ]; then
  # Create main_volume1
  VOLUME_MAIN_DIR="${VOLUME_MAIN_VAR}1"
elif [ "${#volume_main_dir_LIST[@]}" -ge '1' ]; then
  # Create or set storage volume dir
  msg_box "#### PLEASE READ CAREFULLY - SELECT OR CREATE A MAIN VOLUME ####\n\nMain volumes provide the basic first level storage space on your machine or NAS. Standard basic folder shares like homes, music, photo and video folders and files will be created in this volume folder. Therefore, before you start you will need to select or create a volume."
  msg "Select or create a volume from the menu:"
  OPTIONS_VALUES_INPUT=( $(printf '%s\n' "${volume_main_dir_LIST[@]}") )
  OPTIONS_LABELS_INPUT=( $(printf '%s\n' "${volume_main_dir_LIST[@]}") )
  # Add new 'volume[1-9]' option
  if [[ -d "$DIR_MAIN_SCHEMA/${VOLUME_MAIN_VAR}1" ]]; then
    i=1
    while [[ -d "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_VAR$i" ]]; do
      let i++
    done
    new_dir="$VOLUME_MAIN_VAR$i"
  fi
  OPTIONS_VALUES_INPUT+=( "$DIR_MAIN_SCHEMA/$new_dir" )
  OPTIONS_LABELS_INPUT+=( "Create new main volume -- $DIR_MAIN_SCHEMA/$new_dir" )
  # Add exit option to menu
  OPTIONS_VALUES_INPUT+=( "TYPE00" )
  OPTIONS_LABELS_INPUT+=( "None - Exit this installer" )
  # Menu options
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"
  if [ "$RESULTS" = TYPE00 ]; then
    # Exit installation
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    exit 0
  fi

  # Set main volume dir
  VOLUME_MAIN_DIR=$(printf '%s\n' "${RESULTS[@]}" | sed "s|${DIR_MAIN_SCHEMA}/||")
fi

#---- Create new volume dir
if [ ! -d "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR" ]; then
  mkdir -p "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR"
  chmod 0755 "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR"
  chown root:users "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR"
fi


#---- Select fast storage volume dir
# Here we create a fast volume directory for a fast NVMe or SSD storage location (only if available).
# If not available we set to the main volume.

if [ "$DIR_MAIN_SCHEMA" == "$DIR_FAST_SCHEMA" ]; then
  # Set VOLUME_FAST_DIR to main volume
  VOLUME_FAST_DIR="$VOLUME_MAIN_DIR"
else
  # Create fast volume dir list
  if [[ $(ls -d $DIR_FAST_SCHEMA/${VOLUME_FAST_VAR}[1-9] 2>/dev/null) ]]; then
    volume_fast_dir_LIST=( $(ls -d $DIR_FAST_SCHEMA/${VOLUME_FAST_VAR}[1-9]) )
  else
    volume_fast_dir_LIST=()
  fi

  # Set 'VOLUME_FAST_VAR'
  if [ "${#volume_fast_dir_LIST[@]}" = 0 ]; then
    # Create main_volume1
    VOLUME_FAST_DIR="${VOLUME_FAST_VAR}1"
  elif [ "${#volume_fast_dir_LIST[@]}" -ge '1' ]; then
    # Create or set storage volume dir
    msg_box "#### PLEASE READ CAREFULLY - SELECT OR CREATE A FAST VOLUME ####\n\nA fast volume provide the first level storage space on your machine or NAS where downloads, transcodes, public and temporary folders and files will be created. If you have a dedicated fast NVMe or SSD supported volume then you should select it here."
    msg "Select or create a fast volume from the menu:"
    OPTIONS_VALUES_INPUT=( $(printf '%s\n' "${volume_fast_dir_LIST[@]}") )
    OPTIONS_LABELS_INPUT=( $(printf '%s\n' "${volume_fast_dir_LIST[@]}") )
    # Add new 'volume[1-9]' option
    if [[ -d "$DIR_FAST_SCHEMA/${VOLUME_FAST_VAR}1" ]]; then
      i=1
      while [[ -d "$DIR_FAST_SCHEMA/$VOLUME_FAST_VAR$i" ]]; do
        let i++
      done
      new_dir="$VOLUME_FAST_VAR$i"
    fi
    OPTIONS_VALUES_INPUT+=( "$DIR_FAST_SCHEMA/$new_dir" )
    OPTIONS_LABELS_INPUT+=( "Create new fast volume -- $DIR_FAST_SCHEMA/$new_dir" )
    # Add exit option to menu
    OPTIONS_VALUES_INPUT+=( "TYPE00" )
    OPTIONS_LABELS_INPUT+=( "None - Exit this installer" )
    # Menu options
    makeselect_input2
    singleselect SELECTED "$OPTIONS_STRING"
    if [ "$RESULTS" = TYPE00 ]; then
      # Exit installation
      msg "You have chosen not to proceed. Aborting. Bye..."
      echo
      exit 0
    fi

    # Set volume dir
    VOLUME_FAST_DIR=$(printf '%s\n' "${RESULTS[@]}" | sed "s|${DIR_FAST_SCHEMA}/||")
  fi

  #---- Create new volume dir
  if [ ! -d "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR" ]; then
    mkdir -p "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR"
    chmod 0755 "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR"
    chown root:users "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR"
  fi
fi
#-----------------------------------------------------------------------------------