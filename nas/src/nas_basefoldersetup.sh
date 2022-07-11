#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_basefoldersetup.sh
# Description:  Source script for creating NAS base and sub folders
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Check for ACL installation
if [ $(dpkg -s acl > /dev/null 2>&1; echo $?) != 0 ]; then
  apt-get install -y acl > /dev/null
fi

# Check for chattr
if [ ! $(chattr --help &> /dev/null; echo $?) == 1 ]; then
  apt-get -y install e2fsprogs > /dev/null
fi

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Set DIR Schema ( PVE host or CT mkdir )
if [ $(uname -a | grep -Ei --color=never '.*linux*|.*pve*' &> /dev/null; echo $?) == 0 ] && ! [[ $(dpkg -l | grep -w openmediavault) ]]; then
  DIR_SCHEMA="/${POOL}/${HOSTNAME}"
else
  # Select or input a storage path ( set DIR_SCHEMA )
  source ${COMMON_DIR}/nas/src/nas_identify_storagepath.sh
fi


#---- Other Files ------------------------------------------------------------------

# Create empty files
touch nas_basefolderlist-xtra

#---- Body -------------------------------------------------------------------------

#---- Setting Folder Permissions
section "Create and Set Folder Permissions."

# Create Default Proxmox Share points
msg_box "#### PLEASE READ CAREFULLY - SHARED FOLDERS ####\n
Shared folders are the basic directories where you can store files and folders on your NAS. Below is a list of default NAS shared folders. You can create additional custom shared folders in the coming steps.

$(while IFS=',' read -r var1 var2; do msg "  --  /srv/${HOSTNAME}/'${var1}'\n"; done <<< $( cat nas_basefolderlist | sed 's/^#.*//' | sed '/^$/d' ))"
echo

while true; do
  if [ $(cat nas_basefolderlist-xtra | wc -l) == 0 ]; then
    read -p "Do you want to create a custom shared folder [y/n]? " -n 1 -r YN
  else
    read -p "Do you want to another custom shared folder [y/n]? " -n 1 -r YN
  fi
  echo
  case $YN in
    [Yy]*)
      while true; do
        # Function to input dir name
        input_dirname_val
        if [ $(cat nas_basefolderlist | sed '/^#/d' | sed '/^$/d' | awk '{ print $1 }' | grep -xqFe ${DIR_NAME} > /dev/null; echo $?) == 0 ];then
          warn "There are issues with your input:\n  1. The folder '${DIR_NAME}' already exists.\n  Try again..."
          echo
        else
          break
        fi
      done
      XTRA_SHARE01="Standard User - For restricted jailed users (GID: chrootjail)." >/dev/null
      XTRA_SHARE02="Medialab - Photos, series, movies, music and general media content only." >/dev/null
      XTRA_SHARE03="Homelab - Everything to do with your smart home." >/dev/null
      XTRA_SHARE04="Privatelab - User has access to all NAS data." >/dev/null
      PS3="Select the group permission rights for the new folder (entering numeric) : "
      msg "Your options are:"
      options=("$XTRA_SHARE01" "$XTRA_SHARE02" "$XTRA_SHARE03" "$XTRA_SHARE04")
      select menu in "${options[@]}"; do
        case $menu in
          "$XTRA_SHARE01")
            echo "${DIR_NAME},Custom folder,root,0750,65608:rwx,65607:rwx" >> nas_basefolderlist
            echo "${DIR_NAME},Custom folder,root,0750,65608:rwx,65607:rwx" >> nas_basefolderlist-xtra
            info "You have selected: ${YELLOW}Standard User${NC} for folder '${DIR_NAME}'."
            echo
            break
            ;;
          "$XTRA_SHARE02")
            echo "${DIR_NAME},Custom folder,root,0750,65605:rwx,65607:rwx" >> nas_basefolderlist
            echo "${DIR_NAME},Custom folder,root,0750,65605:rwx,65607:rwx" >> nas_basefolderlist-xtra
            info "You have selected: ${YELLOW}Medialab${NC} for folder '${DIR_NAME}'."
            echo
            break
            ;;
          "$XTRA_SHARE03")
            echo "${DIR_NAME},Custom folder,root,0750,65606:rwx,65607:rwx" >> nas_basefolderlist
            echo "${DIR_NAME},Custom folder,root,0750,65606:rwx,65607:rwx" >> nas_basefolderlist-xtra
            info "You have selected: ${YELLOW}Homelab${NC} for folder '${DIR_NAME}'."
            echo
            break
            ;;
          "$XTRA_SHARE04")
            echo "${DIR_NAME},Custom folder,root,0750,65607:rwx" >> nas_basefolderlist
            echo "${DIR_NAME},Custom folder,root,0750,65607:rwx" >> nas_basefolderlist-xtra
            info "You have selected: ${YELLOW}Privatelab${NC} for folder '${DIR_NAME}'."
            echo
            break
            ;;
          *) warn "Invalid entry. Try again.." >&2
        esac
      done
      ;;
    [Nn]*)
      if [ $(cat nas_basefolderlist-xtra | wc -l) == 0 ]; then
        XTRA_SHARES=1
        info "You have chosen not create any custom shared folders."
      else
        XTRA_SHARES=0
        info "You have chosen not create any more custom shared folders."
      fi
      echo
      break
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done

# Create Proxmox ZFS Share points
msg "Creating $SECTION_HEAD base /$POOL/$HOSTNAME folder shares..."
echo
cat nas_basefolderlist | sed '/^#/d' | sed '/^$/d' >/dev/null > nas_basefolderlist_input
while IFS=',' read -r dir desc group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
  if [ -d "${DIR_SCHEMA}/${dir}" ]; then
    info "Pre-existing folder: ${UNDERLINE}"${DIR_SCHEMA}/${dir}"${NC}\n  Setting ${group} group permissions for existing folder."
    find "${DIR_SCHEMA}/" -name .foo_protect -exec chattr -i {} \;
    chgrp -R "${group}" "${DIR_SCHEMA}/${dir}" >/dev/null
    chmod -R "${permission}" "${DIR_SCHEMA}/${dir}" >/dev/null
    if [ ! -z ${acl_01} ]; then
      setfacl -Rm g:${acl_01} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_02} ]; then
      setfacl -Rm g:${acl_02} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_03} ]; then
      setfacl -Rm g:${acl_03} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_04} ]; then
      setfacl -Rm g:${acl_04} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_05} ]; then
      setfacl -Rm g:${acl_05} "${DIR_SCHEMA}/${dir}"
    fi
    echo
  else
    info "New base folder created:\n  ${WHITE}"${DIR_SCHEMA}/${dir}"${NC}"
    find "${DIR_SCHEMA}/" -name .foo_protect -exec chattr -i {} \;
    mkdir -p "${DIR_SCHEMA}/${dir}" >/dev/null
    chgrp -R "${group}" "${DIR_SCHEMA}/${dir}" >/dev/null
    chmod -R "${permission}" "${DIR_SCHEMA}/${dir}" >/dev/null
    if [ ! -z ${acl_01} ]; then
      setfacl -Rm g:${acl_01} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_02} ]; then
      setfacl -Rm g:${acl_02} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_03} ]; then
      setfacl -Rm g:${acl_03} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_04} ]; then
      setfacl -Rm g:${acl_04} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_05} ]; then
      setfacl -Rm g:${acl_05} "${DIR_SCHEMA}/${dir}"
    fi
    echo
  fi
done < nas_basefolderlist_input

# # Chattr set ZFS share points attributes to +a
# while read -r dir group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
#   chattr +a "${DIR_SCHEMA}/${dir}"
# done < nas_basefolderlist_input


# Create Default SubFolders
if [ -f nas_basefoldersubfolderlist ]; then
  msg "Creating $SECTION_HEAD subfolder shares..."
  echo
  echo -e "$(eval "echo -e \"`<nas_basefoldersubfolderlist`\"")" | sed '/^#/d' | sed '/^$/d' >/dev/null > nas_basefoldersubfolderlist_input
  while IFS=',' read -r dir group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
    if [ -d "${dir}" ]; then
      info "${dir} exists.\n  Setting ${group} group permissions for this folder."
      find ${dir} -name .foo_protect -exec chattr -i {} \;
      chgrp -R "${group}" "${dir}" >/dev/null
      chmod -R "${permission}" "${dir}" >/dev/null
      if [ ! -z ${acl_01} ]; then
        setfacl -Rm g:${acl_01} "${dir}"
      fi
      if [ ! -z ${acl_02} ]; then
        setfacl -Rm g:${acl_02} "${dir}"
      fi
      if [ ! -z ${acl_03} ]; then
        setfacl -Rm g:${acl_03} "${dir}"
      fi
      if [ ! -z ${acl_04} ]; then
        setfacl -Rm g:${acl_04} "${dir}"
      fi
      if [ ! -z ${acl_05} ]; then
        setfacl -Rm g:${acl_05} "${dir}"
      fi
      echo
    else
      info "New subfolder created:\n  ${WHITE}"${dir}"${NC}"
      mkdir -p "${dir}" >/dev/null
      chgrp -R "${group}" "${dir}" >/dev/null
      chmod -R "${permission}" "${dir}" >/dev/null
      if [ ! -z ${acl_01} ]; then
        setfacl -Rm g:${acl_01} "${dir}"
      fi
      if [ ! -z ${acl_02} ]; then
        setfacl -Rm g:${acl_02} "${dir}"
      fi
      if [ ! -z ${acl_03} ]; then
        setfacl -Rm g:${acl_03} "${dir}"
      fi
      if [ ! -z ${acl_04} ]; then
        setfacl -Rm g:${acl_04} "${dir}"
      fi
      if [ ! -z ${acl_05} ]; then
        setfacl -Rm g:${acl_05} "${dir}"
      fi
      echo
    fi
  done < nas_basefoldersubfolderlist_input
  # Chattr set ZFS share points attributes to +a
  while IFS=',' read -r dir group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
    touch ${dir}/.foo_protect
    chattr +i ${dir}/.foo_protect
    # chmod +t ${dir}/.foo_protect
  done < nas_basefoldersubfolderlist_input
fi

#---- Finish Line ------------------------------------------------------------------