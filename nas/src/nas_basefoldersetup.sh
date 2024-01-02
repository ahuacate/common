#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_basefoldersetup.sh
# Description:  Source script for creating NAS base and sub folders
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Requires arg: 'DIR_SCHEMA' (use script: nas_identify_storagepath.sh)

# Check for ACL installation
if [[ ! $(dpkg -s acl 2> /dev/null) ]]; then
  apt-get install -y acl 2> /dev/null
fi

# Check for chattr
if [ ! $(chattr --help &> /dev/null; echo $?) = 1 ]; then
  apt-get -y install e2fsprogs > /dev/null
fi

#---- Static Variables -------------------------------------------------------------

# Set extras variable Volume dir (if not set)
if [ ! -n "${VOLUME_DIR}" ]; then
  extra_DIR_SCHEMA=''
else
  extra_DIR_SCHEMA="$VOLUME_DIR/"
fi


#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Create Arrays ( must be after setting 'DIR_SCHEMA' )
# Create 'nas_basefolder_LIST' array
nas_basefolder_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ (^\#.*$|^\s*$) ]] && continue
    if [ ! -n "${VOLUME_DIR}" ]; then
      nas_basefolder_LIST+=( "$line" )
    else
      nas_basefolder_LIST+=( "$VOLUME_DIR/$line" )
    fi
done < $COMMON_DIR/nas/src/nas_basefolderlist

# Create 'nas_subfolder_LIST' array
nas_subfolder_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ (^\#.*$|^\s*$) ]] && continue
    if [ ! -n "${VOLUME_DIR}" ]; then
      nas_subfolder_LIST+=( "$line" )
    else
      nas_subfolder_LIST+=( "$VOLUME_DIR/$line" )
    fi
done < $COMMON_DIR/nas/src/nas_basefoldersubfolderlist


#---- Setting Folder Permissions
section "Create and Set Folder Permissions"

# Create Default Proxmox Share points
msg_box "#### PLEASE READ CAREFULLY - SHARED FOLDERS ####\n\nShared folders are the basic directories where you can store files and folders on your NAS. Below is a list of our default NAS shared folders. You can create additional 'custom' shared folders in the coming steps.\n\n$(while IFS=',' read -r var1 var2; do msg "\t--  ${DIR_SCHEMA}/'${var1}'"; done <<< $( printf '%s\n' "${nas_basefolder_LIST[@]}" ))"
echo
nas_basefolder_extra_LIST=()
while true
do
  if [ ${#nas_basefolder_extra_LIST[@]} = 0 ]; then
    read -p "Do you want to create a additional custom shared folder (default 'n') [y/n]? " -n 1 -r YN
  else
    read -p "Do you want to another custom shared folder [y/n]? " -n 1 -r YN
  fi
  echo
  case $YN in
    [Yy]*)
      while true
      do
        # Function to input dir name
        input_dirname_val
        if [ $(printf '%s\n' "${nas_basefolder_LIST[@]}" | awk -F',' '{ print $1 }' | grep -xqFe ${DIR_NAME} > /dev/null; echo $?) == 0 ]; then
          warn "There are issues with your input:\n  1. The folder '${DIR_NAME}' already exists.\n  Try again..."
          echo
        else
          break
        fi
      done
      msg "Select the group permission rights for '${DIR_NAME}' custom folder..."
      # Make selection
      OPTIONS_VALUES_INPUT=( "LEVEL01" "LEVEL02" "LEVEL03" "LEVEL04" )
      OPTIONS_LABELS_INPUT=( "Standard User - For restricted jailed users (GID: chrootjail)" \
      "Medialab - Photos, series, movies, music and general media content only" \
      "Homelab - Everything to do with your smart home" \
      "Privatelab - User has access to all NAS data" )
      makeselect_input2
      singleselect SELECTED "$OPTIONS_STRING"
      # Set type
      if [ "$RESULTS" = LEVEL01 ]; then
        nas_basefolder_LIST+=( "$extra_DIR_SCHEMA/$DIR_NAME,Custom folder,root,users,0750,65608:rwx,65607:rwx" )
        nas_basefolder_extra_LIST+=( "$extra_DIR_SCHEMA/$DIR_NAME,Custom folder,root,users,0750,65608:rwx,65607:rwx" )
        info "You have selected: ${YELLOW}Standard User${NC} for folder '${DIR_NAME}'."
        echo
      elif [ "$RESULTS" = LEVEL02 ]; then
        nas_basefolder_LIST+=( "$extra_DIR_SCHEMA/$DIR_NAME,Custom folder,root,65605,0750,65605:rwx,65607:rwx" )
        nas_basefolder_extra_LIST+=( "$extra_DIR_SCHEMA/$DIR_NAME,Custom folder,root,65605,0750,65605:rwx,65607:rwx" )
        info "You have selected: ${YELLOW}Medialab${NC} for folder '${DIR_NAME}'."
        echo
      elif [ "$RESULTS" = LEVEL03 ]; then
        nas_basefolder_LIST+=( "$extra_DIR_SCHEMA/$DIR_NAME,Custom folder,root,65606,0750,65606:rwx,65607:rwx" )
        nas_basefolder_extra_LIST+=( "$extra_DIR_SCHEMA/$DIR_NAME,Custom folder,root,65606,0750,65606:rwx,65607:rwx" )
        info "You have selected: ${YELLOW}Homelab${NC} for folder '${DIR_NAME}'."
        echo
      elif [ "$RESULTS" = LEVEL04 ]; then
        nas_basefolder_LIST+=( "$extra_DIR_SCHEMA/$DIR_NAME,Custom folder,root,65607,0750,65607:rwx" )
        nas_basefolder_extra_LIST+=( "$extra_DIR_SCHEMA/$DIR_NAME,Custom folder,root,65607,0750,65607:rwx" )
        info "You have selected: ${YELLOW}Privatelab${NC} for folder '${DIR_NAME}'."
        echo
      fi
      ;;
    [Nn]*)
      echo
      break
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done

# Create storage 'Volume'
if [ -n "${VOLUME_DIR}" ]; then
  find $DIR_SCHEMA/$VOLUME_DIR -name .foo_protect -exec chattr -i {} \;
  mkdir -p "$DIR_SCHEMA/$VOLUME_DIR"
  chmod 0755 "$DIR_SCHEMA/$VOLUME_DIR"
  chown root:users "$DIR_SCHEMA/$VOLUME_DIR"
fi

# Create Proxmox Share points
msg "Creating ${SECTION_HEAD} base folder shares..."
echo
while IFS=',' read -r dir desc user group permission acl_01 acl_02 acl_03 acl_04 acl_05
do
  if [ -d "$DIR_SCHEMA/$dir" ]; then
    info "Pre-existing folder: ${UNDERLINE}"$DIR_SCHEMA/$dir"${NC}\n  Setting $group group permissions for existing folder."
    find $DIR_SCHEMA/$dir -name .foo_protect -exec chattr -i {} \;
    setfacl -bn "$DIR_SCHEMA/$dir"
    chgrp -R "${group}" "$DIR_SCHEMA/$dir" >/dev/null
    chmod -R "${permission}" "$DIR_SCHEMA/$dir" >/dev/null
    if [ ! -z ${acl_01} ]; then
      setfacl -Rm g:${acl_01} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z ${acl_02} ]; then
      setfacl -Rm g:${acl_02} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z ${acl_03} ]; then
      setfacl -Rm g:${acl_03} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z ${acl_04} ]; then
      setfacl -Rm g:${acl_04} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z ${acl_05} ]; then
      setfacl -Rm g:${acl_05} "$DIR_SCHEMA/$dir"
    fi
    echo
  else
    info "New base folder created:\n  ${WHITE}"$DIR_SCHEMA/$dir"${NC}"
    mkdir -p "$DIR_SCHEMA/$dir" >/dev/null
    chgrp -R "${group}" "$DIR_SCHEMA/$dir" >/dev/null
    chmod -R "${permission}" "$DIR_SCHEMA/$dir" >/dev/null
    if [ ! -z ${acl_01} ]; then
      setfacl -Rm g:${acl_01} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z ${acl_02} ]; then
      setfacl -Rm g:${acl_02} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z ${acl_03} ]; then
      setfacl -Rm g:${acl_03} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z ${acl_04} ]; then
      setfacl -Rm g:${acl_04} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z ${acl_05} ]; then
      setfacl -Rm g:${acl_05} "$DIR_SCHEMA/$dir"
    fi
    echo
  fi

  # Add file '.stignore' for Syncthing
  if [ -d "$DIR_SCHEMA/$dir" ]; then
    common_stignore="$COMMON_DIR/nas/src/nas_stignorelist"
    file_stignore="$DIR_SCHEMA/$dir/.stignore"

    # Create missing '.stignore' file
    if [ ! -f "$file_stignore" ]; then
      touch "$DIR_SCHEMA/$dir/.stignore"
    fi

    # Read each line from the common ignore list
    while IFS= read -r pattern; do
        # Check if the pattern exists in the directory's .stignore file
        if ! grep -qF "$pattern" "$file_stignore"; then
            # If not, append the pattern to the .stignore file
            echo "$pattern" >> "$file_stignore"
            echo "Added: $pattern"
        else
            echo "Already exists: $pattern"
        fi
    done < "$common_stignore"
  fi
done <<< $( printf '%s\n' "${nas_basefolder_LIST[@]}" )

# Create Default SubFolders
if [ ! ${#nas_subfolder_LIST[@]} = 0 ]; then
  msg "Creating $SECTION_HEAD subfolder shares..."
  echo
  while IFS=',' read -r dir user group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
    if [ -d "$DIR_SCHEMA/$dir" ]; then
      info "${DIR_SCHEMA}/${dir} exists.\n  Setting $group group permissions for this folder."
      find $DIR_SCHEMA/$dir -name .foo_protect -exec chattr -i {} \;
      setfacl -bn "$DIR_SCHEMA/$dir"
      chgrp -R "$group" "$DIR_SCHEMA/$dir" >/dev/null
      chmod -R "$permission" "$DIR_SCHEMA/$dir" >/dev/null
      if [ ! -z ${acl_01} ]; then
        setfacl -Rm g:${acl_01} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z ${acl_02} ]; then
        setfacl -Rm g:${acl_02} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z ${acl_03} ]; then
        setfacl -Rm g:${acl_03} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z ${acl_04} ]; then
        setfacl -Rm g:${acl_04} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z ${acl_05} ]; then
        setfacl -Rm g:${acl_05} "$DIR_SCHEMA/$dir"
      fi
      echo
    else
      info "New subfolder created:\n  ${WHITE}"$DIR_SCHEMA/$dir"${NC}"
      mkdir -p "$DIR_SCHEMA/$dir" >/dev/null
      chgrp -R "$group" "$DIR_SCHEMA/$dir" >/dev/null
      chmod -R "$permission" "$DIR_SCHEMA/$dir" >/dev/null
      if [ ! -z ${acl_01} ]; then
        setfacl -Rm g:${acl_01} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z ${acl_02} ]; then
        setfacl -Rm g:${acl_02} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z ${acl_03} ]; then
        setfacl -Rm g:${acl_03} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z ${acl_04} ]; then
        setfacl -Rm g:${acl_04} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z ${acl_05} ]; then
        setfacl -Rm g:${acl_05} "$DIR_SCHEMA/$dir"
      fi
      echo
    fi
  done <<< $(printf "%s\n" "${nas_subfolder_LIST[@]}")

  # Chattr set share points attributes to +a
  while IFS=',' read -r dir user group permission acl_01 acl_02 acl_03 acl_04 acl_05
  do
    if [ ! -f "$DIR_SCHEMA/$dir/.foo_protect" ]; then
      touch "$DIR_SCHEMA/$dir/.foo_protect"
    fi
    chattr +i "$DIR_SCHEMA/$dir/.foo_protect"
    # chmod +t ${dir}/.foo_protect
  done <<< $(printf "%s\n" "${nas_subfolder_LIST[@]}")
fi

# Chattr set VOLUME_DIR attributes to +a
if [ -n "${VOLUME_DIR}" ]; then
  touch "$DIR_SCHEMA/$VOLUME_DIR/.foo_protect"
  chattr +i "$DIR_SCHEMA/$VOLUME_DIR/.foo_protect"
fi
#-----------------------------------------------------------------------------------