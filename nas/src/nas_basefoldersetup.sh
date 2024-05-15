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
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Create Arrays ( must be after setting 'DIR_SCHEMA' )

# Create 'nas_basefolder_LIST' array
nas_basefolder_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ (^\#.*$|^\s*$) ]] && continue

  # Check if fast storage location is enabled in source file
  fast_var=$(echo "$line" | cut -d ',' -f 2)
  if [ "$fast_var" -eq 0 ]; then
    # Set for main volume (fast set to '0')
    if [ ! -n "${VOLUME_MAIN_DIR}" ]; then
      nas_basefolder_LIST+=( "$line" )
    else
      nas_basefolder_LIST+=( "$VOLUME_MAIN_DIR/$line" )
    fi
  elif [ "$fast_var" -eq 1 ]; then
    # Set for fast volume (fast set to '1')
    if [ ! -n "${VOLUME_FAST_DIR}" ]; then
      nas_basefolder_LIST+=( "$line" )
    else
      nas_basefolder_LIST+=( "$VOLUME_FAST_DIR/$line" )
    fi
  fi
done < $COMMON_DIR/nas/src/nas_basefolderlist

# Create 'nas_subfolder_LIST' array
nas_subfolder_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ (^\#.*$|^\s*$) ]] && continue

  # Check if fast storage location is enabled in source file
  fast_var=$(echo "$line" | cut -d ',' -f 2)
  if [ "$fast_var" -eq 0 ]; then
    # Set for main volume (fast set to '0')
    if [ ! -n "${VOLUME_MAIN_DIR}" ]; then
      nas_subfolder_LIST+=( "$line" )
    else
      nas_subfolder_LIST+=( "$VOLUME_MAIN_DIR/$line" )
    fi
  elif [ "$fast_var" -eq 1 ]; then
    # Set for fast volume (fast set to '1')
    if [ ! -n "${VOLUME_FAST_DIR}" ]; then
      nas_subfolder_LIST+=( "$line" )
    else
      nas_subfolder_LIST+=( "$VOLUME_FAST_DIR/$line" )
    fi
  fi
done < $COMMON_DIR/nas/src/nas_basefoldersubfolderlist


#---- Create and set Folder Share Permissions
section "Create and Set Folder Permissions"

# # Set extras variable Volume dir (if not set)
# if [ ! -n "${VOLUME_MAIN_DIR}" ]; then
#   extra_VOLUME_DIR=''
# else
#   extra_VOLUME_DIR="$VOLUME_DIR/"
# fi

# Create Default Proxmox Share points
msg_box "#### PLEASE READ CAREFULLY - SHARED FOLDERS ####\n\nShared folders are the basic directories where you can store files and folders on your NAS. Below is a list of our default NAS shared folders. You can create additional 'custom' shared folders in the coming steps.

$( while IFS=',' read -r var1 var2 var3; do
if [ "$var2" -eq 0 ]; then
  print_schema=".../main-storage"
elif [ "$var2" -eq 1 ]; then
  if [ "$DIR_MAIN_SCHEMA" == "$DIR_FAST_SCHEMA" ]; then
    print_schema=".../main-storage"
  else
    print_schema=".../fast-storage"
  fi
fi
msg "\t--  $print_schema/$var1"
done <<< $(printf '%s\n' "${nas_basefolder_LIST[@]}") )"

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
        # Function to input custom dir name
        input_dirname_val
        if [ $(printf '%s\n' "${nas_basefolder_LIST[@]}" | awk -F',' '{ print $1 }' | grep -xqFe ${DIR_NAME} > /dev/null; echo $?) == 0 ]; then
          warn "There are issues with your input:\n  1. The folder '${DIR_NAME}' already exists.\n  Try again..."
          echo
        else
          break
        fi
      done

      # Check if fast volume option is available (fast set to '1')
      if [ ! -n "${VOLUME_MAIN_DIR}" ]; then
        # Set extras variable Volume dir to none (if not set)
        extra_VOLUME_DIR=''
      else
        if [ "$VOLUME_MAIN_DIR" == "$VOLUME_FAST_DIR" ]; then
          extra_VOLUME_DIR="$VOLUME_MAIN_DIR/"
          extra_fast_arg=0
        else
          msg "Which volume do you want create '${DIR_NAME}' in (main or fast)..."
          # Make selection
          OPTIONS_VALUES_INPUT=( "LEVEL01" "LEVEL02" )
          OPTIONS_LABELS_INPUT=( "Main - standard main NAS volume" \
          "Fast - dedicated fast and temporary NVMe or SSD supported volume" )
          makeselect_input2
          singleselect SELECTED "$OPTIONS_STRING"
          # Set storage volume type
          if [ "$RESULTS" = "LEVEL01" ]; then
            # Set storage volume to 'main'
            extra_VOLUME_DIR="$VOLUME_MAIN_DIR/"
            extra_fast_arg=0
          elif [ "$RESULTS" = "LEVEL02" ]; then
            # Set storage volume to 'fast'
            extra_VOLUME_DIR="$VOLUME_FAST_DIR/"
            extra_fast_arg=1
          fi
        fi
      fi

      # Set custom folder permissions and rights
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
      if [ "$RESULTS" = "LEVEL01" ]; then
        nas_basefolder_LIST+=( "$extra_VOLUME_DIR$DIR_NAME,$extra_fast_arg,Custom folder,root,users,1,0750,65608:rwx,65607:rwx" )
        nas_basefolder_extra_LIST+=( "$extra_VOLUME_DIR$DIR_NAME,$extra_fast_arg,Custom folder,root,users,0750,1,65608:rwx,65607:rwx" )
        info "You have selected: ${YELLOW}Standard User${NC} for folder '${DIR_NAME}'."
        echo
      elif [ "$RESULTS" = "LEVEL02" ]; then
        nas_basefolder_LIST+=( "$extra_VOLUME_DIR$DIR_NAME,$extra_fast_arg,Custom folder,root,65605,0750,1m65605:rwx,65607:rwx" )
        nas_basefolder_extra_LIST+=( "$extra_VOLUME_DIR$DIR_NAME,$extra_fast_arg,Custom folder,root,65605,0750,1,65605:rwx,65607:rwx" )
        info "You have selected: ${YELLOW}Medialab${NC} for folder '${DIR_NAME}'."
        echo
      elif [ "$RESULTS" = "LEVEL03" ]; then
        nas_basefolder_LIST+=( "$extra_VOLUME_DIR$DIR_NAME,$extra_fast_arg,Custom folder,root,65606,0750,1,65606:rwx,65607:rwx" )
        nas_basefolder_extra_LIST+=( "$extra_VOLUME_DIR$DIR_NAME,$extra_fast_arg,Custom folder,root,65606,1,0750,65606:rwx,65607:rwx" )
        info "You have selected: ${YELLOW}Homelab${NC} for folder '${DIR_NAME}'."
        echo
      elif [ "$RESULTS" = "LEVEL04" ]; then
        nas_basefolder_LIST+=( "$extra_VOLUME_DIR$DIR_NAME,$extra_fast_arg,Custom folder,root,65607,0750,1,65607:rwx" )
        nas_basefolder_extra_LIST+=( "$extra_VOLUME_DIR$DIR_NAME,$extra_fast_arg,Custom folder,root,65607,0750,1,65607:rwx" )
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

# Create storage 'Volume' folders
if [ -n "$DIR_MAIN_SCHEMA" ] && [ -n "$VOLUME_MAIN_DIR" ]; then
  find "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR" -name .foo_protect -exec chattr -i {} \;
  mkdir -p "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR"
  chmod 0755 "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR"
  chown root:users "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR"
fi
if [ "$DIR_FAST_SCHEMA" != "$DIR_MAIN_SCHEMA" ]; then
  if [ -n "$DIR_FAST_SCHEMA" ] && [ -n "$VOLUME_FAST_DIR" ]; then
    find "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR" -name .foo_protect -exec chattr -i {} \;
    mkdir -p "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR"
    chmod 0755 "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR"
    chown root:users "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR"
  fi
fi

# Create Proxmox Main and Fast Share points
msg "Creating ${SECTION_HEAD} base folder shares..."
echo
while IFS=',' read -r dir fast desc user group permission inherit acl_01 acl_02 acl_03 acl_04 acl_05
do
  # Check if storage volume option, main or fast, and set 'DIR_SCHEMA' accordingly
  if [ "$DIR_MAIN_SCHEMA" == "$DIR_FAST_SCHEMA" ]; then
    DIR_SCHEMA="$DIR_MAIN_SCHEMA" # Override 'fast' arg (fast not available)
  else
    if [ "$fast" -eq 0 ]; then
      DIR_SCHEMA="$DIR_MAIN_SCHEMA" # Set to use main storage
    elif [ "$fast" -eq 1 ]; then
      DIR_SCHEMA="$DIR_FAST_SCHEMA" # Set to use fast storage
    fi
  fi

  if [ -d "$DIR_SCHEMA/$dir" ]; then
    # Check if folder share exists and update permissions
    info "Pre-existing folder: ${UNDERLINE}"$DIR_SCHEMA/$dir"${NC}\nSetting $group group permissions for existing folder."
    find "$DIR_SCHEMA/$dir" -name .foo_protect -exec chattr -i {} \;
    setfacl -bn "$DIR_SCHEMA/$dir"
    chgrp -R "$group" "$DIR_SCHEMA/$dir" >/dev/null
    chmod -R "$permission" "$DIR_SCHEMA/$dir" >/dev/null

    # Check if 'DIR_SCHEMA/dir' already has ACLs (sets option to modify or create new ACLS)
    if getfacl "$DIR_SCHEMA/$dir" >/dev/null 2>&1; then
      # Modify ACL
      if [ "$inherit" -eq 1 ]; then
        acl_arg='-R -d -m' # inherit permissions applied ('0' off, '1' on)
      else
        acl_arg='-R -m' # inherit permissions NOT applied ('0' off, '1' on)
      fi
    else
      # New ACL
      if [ "$inherit" -eq 1 ]; then
        acl_arg='-R -d' # inherit permissions applied ('0' off, '1' on)
      else
        acl_arg='-R' # inherit permissions NOT applied ('0' off, '1' on)
      fi
    fi

    # Modify existing folder ACLs
    if [ ! -z "$acl_01" ]; then
      setfacl ${acl_arg} g:${acl_01} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z "$acl_02" ]; then
      setfacl ${acl_arg} g:${acl_02} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z "$acl_03" ]; then
      setfacl ${acl_arg} g:${acl_03} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z "$acl_04" ]; then
      setfacl ${acl_arg} g:${acl_04} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z "$acl_05" ]; then
      setfacl ${acl_arg} g:${acl_05} "$DIR_SCHEMA/$dir"
    fi
    echo
  else
    # Create new folder and apply permissions
    info "New base folder created:\n  ${WHITE}"$DIR_SCHEMA/$dir"${NC}"
    mkdir -p "$DIR_SCHEMA/$dir" >/dev/null
    chgrp -R "$group" "$DIR_SCHEMA/$dir" >/dev/null
    chmod -R "$permission" "$DIR_SCHEMA/$dir" >/dev/null

    # Check if 'DIR_SCHEMA/dir' already has ACLs (sets option to modify or create new ACLS)
    if getfacl "$DIR_SCHEMA/$dir" >/dev/null 2>&1; then
      # Modify ACL
      if [ "$inherit" -eq 1 ]; then
        acl_arg='-R -d -m' # inherit permissions applied ('0' off, '1' on)
      else
        acl_arg='-R -m' # inherit permissions NOT applied ('0' off, '1' on)
      fi
    else
      # New ACL
      if [ "$inherit" -eq 1 ]; then
        acl_arg='-R -d' # inherit permissions applied ('0' off, '1' on)
      else
        acl_arg='-R' # inherit permissions NOT applied ('0' off, '1' on)
      fi
    fi

    # Set new folder ACLs
    if [ ! -z "$acl_01" ]; then
      setfacl ${acl_arg} g:${acl_01} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z "$acl_02" ]; then
      setfacl ${acl_arg} "g:${acl_02}" "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z "$acl_03" ]; then
      setfacl ${acl_arg} g:${acl_03} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z "$acl_04" ]; then
      setfacl ${acl_arg} g:${acl_04} "$DIR_SCHEMA/$dir"
    fi
    if [ ! -z "$acl_05" ]; then
      setfacl ${acl_arg} g:${acl_05} "$DIR_SCHEMA/$dir"
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


# Create Proxmox sub-folder Share points
if [ ! ${#nas_subfolder_LIST[@]} = 0 ]; then
  msg "Creating $SECTION_HEAD subfolder shares..."
  echo
  while IFS=',' read -r dir fast user group permission inherit acl_01 acl_02 acl_03 acl_04 acl_05; do
    # Check if storage volume option, main or fast, and set 'DIR_SCHEMA' accordingly
    if [ "$DIR_MAIN_SCHEMA" == "$DIR_FAST_SCHEMA" ]; then
      DIR_SCHEMA="$DIR_MAIN_SCHEMA" # Override 'fast' arg (fast not available)
    else
      if [ "$fast" -eq 0 ]; then
        DIR_SCHEMA="$DIR_MAIN_SCHEMA" # Set to use main storage
      elif [ "$fast" -eq 1 ]; then
        DIR_SCHEMA="$DIR_FAST_SCHEMA" # Set to use fast storage
      fi
    fi

    if [ -d "$DIR_SCHEMA/$dir" ]; then
      info "${DIR_SCHEMA}/${dir} exists.\n  Setting $group group permissions for this folder"
      find "$DIR_SCHEMA/$dir" -name .foo_protect -exec chattr -i {} \;
      setfacl -bn "$DIR_SCHEMA/$dir"
      chgrp -R "$group" "$DIR_SCHEMA/$dir" >/dev/null
      chmod -R "$permission" "$DIR_SCHEMA/$dir" >/dev/null

      # Check if 'DIR_SCHEMA/dir' already has ACLs (sets option to modify or create new ACLS)
      if getfacl "$DIR_SCHEMA/$dir" >/dev/null 2>&1; then
        # Modify ACL
        if [ "$inherit" -eq 1 ]; then
          acl_arg='-R -d -m' # inherit permissions applied ('0' off, '1' on)
        else
          acl_arg='-R -m' # inherit permissions NOT applied ('0' off, '1' on)
        fi
      else
        # New ACL
        if [ "$inherit" -eq 1 ]; then
          acl_arg='-R -d' # inherit permissions applied ('0' off, '1' on)
        else
          acl_arg='-R' # inherit permissions NOT applied ('0' off, '1' on)
        fi
      fi

      # Modify existing folder ACLs
      if [ ! -z "$acl_01" ]; then
        setfacl ${acl_arg} g:${acl_01} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z "$acl_02" ]; then
        setfacl ${acl_arg} g:${acl_02} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z "$acl_03" ]; then
        setfacl ${acl_arg} g:${acl_03} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z "$acl_04" ]; then
        setfacl ${acl_arg} g:${acl_04} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z "$acl_05" ]; then
        setfacl ${acl_arg} g:${acl_05} "$DIR_SCHEMA/$dir"
      fi
      echo
    else
      info "New subfolder created:\n  ${WHITE}"$DIR_SCHEMA/$dir"${NC}"
      mkdir -p "$DIR_SCHEMA/$dir" >/dev/null
      chgrp -R "$group" "$DIR_SCHEMA/$dir" >/dev/null
      chmod -R "$permission" "$DIR_SCHEMA/$dir" >/dev/null

      # Check if 'DIR_SCHEMA/dir' already has ACLs (sets option to modify or create new ACLS)
      if getfacl "$DIR_SCHEMA/$dir" >/dev/null 2>&1; then
        # Modify ACL
        if [ "$inherit" -eq 1 ]; then
          acl_arg='-R -d -m' # inherit permissions applied ('0' off, '1' on)
        else
          acl_arg='-R -m' # inherit permissions NOT applied ('0' off, '1' on)
        fi
      else
        # New ACL
        if [ "$inherit" -eq 1 ]; then
          acl_arg='-R -d' # inherit permissions applied ('0' off, '1' on)
        else
          acl_arg='-R' # inherit permissions NOT applied ('0' off, '1' on)
        fi
      fi

      # Set new folder ACLs
      if [ ! -z "$acl_01" ]; then
        setfacl ${acl_arg} g:${acl_01} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z "$acl_02" ]; then
        setfacl ${acl_arg} g:${acl_02} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z "$acl_03" ]; then
        setfacl ${acl_arg} g:${acl_03} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z "$acl_04" ]; then
        setfacl ${acl_arg} g:${acl_04} "$DIR_SCHEMA/$dir"
      fi
      if [ ! -z "$acl_05" ]; then
        setfacl ${acl_arg} g:${acl_05} "$DIR_SCHEMA/$dir"
      fi
      echo
    fi
  done <<< $(printf "%s\n" "${nas_subfolder_LIST[@]}")

  # Chattr set share points attributes to +a
  while IFS=',' read -r dir fast user group permission inherit acl_01 acl_02 acl_03 acl_04 acl_05
  do
    # Check if storage volume option, main or fast, and set 'DIR_SCHEMA' accordingly
    if [ "$DIR_MAIN_SCHEMA" == "$DIR_FAST_SCHEMA" ]; then
      DIR_SCHEMA="$DIR_MAIN_SCHEMA" # Override 'fast' arg (fast not available)
    else
      if [ "$fast" -eq 0 ]; then
        DIR_SCHEMA="$DIR_MAIN_SCHEMA" # Set to use main storage
      elif [ "$fast" -eq 1 ]; then
        DIR_SCHEMA="$DIR_FAST_SCHEMA" # Set to use fast storage
      fi
    fi

    if [ ! -f "$DIR_SCHEMA/$dir/.foo_protect" ]; then
      touch "$DIR_SCHEMA/$dir/.foo_protect"
    fi
    chattr +i "$DIR_SCHEMA/$dir/.foo_protect"
    # chmod +t ${dir}/.foo_protect
  done <<< $(printf "%s\n" "${nas_subfolder_LIST[@]}")
fi

# Chattr set 'VOLUME_MAIN_DIR' & 'VOLUME_FAST_DIR' attributes to +a
if [ -d "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR" ]; then
  if [ ! -f "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR/.foo_protect" ]; then
    touch "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR/.foo_protect"
    chattr +i "$DIR_MAIN_SCHEMA/$VOLUME_MAIN_DIR/.foo_protect"
  fi
fi
if [ "$DIR_FAST_SCHEMA" != "$DIR_MAIN_SCHEMA" ]; then
  if [ -d "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR" ]; then
    if [ ! -f "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR/.foo_protect" ]; then
      touch "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR/.foo_protect"
      chattr +i "$DIR_FAST_SCHEMA/$VOLUME_FAST_DIR/.foo_protect"
    fi
  fi
fi
#-----------------------------------------------------------------------------------