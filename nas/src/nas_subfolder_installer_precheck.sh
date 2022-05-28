#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_subfolder_installer_precheck.sh
# Description:  Source script for installers to check and create NAS subfolders
#               Run after 'pvesource_set_allvmvars.sh'
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Must run after 'pvesource_set_allvmvars.sh'

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
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Unset all list arrays
unset dir_check_LIST
unset nas_subfolder_LIST
unset display_dir_error_MSG
unset display_permission_error_MSG

# Create PVESM check list
unset dir_check_LIST
while IFS=',' read -r pve_mnt ct_mnt; do
  label=$(echo ${ct_mnt} | sed 's/^\/mnt\///')
  remote_mnt=$(df -h | awk -v var="${pve_mnt}" '{ if ($0 ~ var) print $1 }')
  mnt_protocol=$(pvesm status | grep "^${pve_mnt}" | awk '{ print $2 }')
  # Combine to list
  while IFS= read -r sub_dir; do
    remote_mnt_sub=$(echo $sub_dir | awk -F',' '{ print $1}' | sed "s|.*${pve_mnt}||")
    dir_check_LIST+=( "${label},${mnt_protocol},${remote_mnt}${remote_mnt_sub},${sub_dir}" )
  done <<< $(cat ${COMMON_DIR}/nas/src/nas_basefoldersubfolderlist | awk -F',' -v var="\\\${DIR_SCHEMA}\/${label}" '{ if ($1 ~ var) print $0 }' | sed "s/\${DIR_SCHEMA}\/${label}/\/mnt\/pve\/${pve_mnt}/")
done <<< $(printf '%s\n' "${pvesm_input_LIST[@]}" | sed '/\/mnt\/backup$/d')


# Create required SubFolder list
unset nas_subfolder_LIST
while IFS=',' read -r label mnt_protocol remote_mnt sub_dir other; do
  if ! [ -d "$sub_dir" ]; then
    nas_subfolder_LIST+=( "${label},${mnt_protocol},${remote_mnt},${sub_dir},${other}" )
  fi
done <<< $(printf '%s\n' "${dir_check_LIST[@]}")


# Create SubFolders required by CT
unset display_dir_error_MSG
unset display_permission_error_MSG
unset display_chattr_error_MSG
if [ ! ${#nas_subfolder_LIST[@]} == '0' ]; then
  section "${HOSTNAME^} Subfolders"
  msg "Creating ${SECTION_HEAD} subfolders required by CT applications..."
  echo
  while IFS=',' read -r label mnt_protocol remote_mnt sub_dir group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
    if [ -d "${sub_dir}" ]; then
      info "Pre-existing folder: ${UNDERLINE}"${sub_dir}"${NC}"
      # Check for '.foo_protect' file
      [ -f ${sub_dir}/.foo_protect ] || display_chattr_error_MSG+=( "Linux command: touch & chattr (missing .foo_protect)\nLocal PVE folder: ${sub_dir}\nRemote NAS folder: $(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\nLinux CLI: touch <foldername>/.foo_protect && chattr +i <foldername>/.foo_protect\n" )
      # Check folder grp ownership
      [ $(ls -ld ${sub_dir} | awk '{ print $4 }') = ${group} ] || display_dir_error_MSG+=( "Linux command: chgrp (not GID ${group})\nLocal PVE folder: ${sub_dir}\nRemote NAS folder: $(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\n" )
      echo
    else
      info "New subfolder created:\n  ${WHITE}"${sub_dir}"${NC}"
      mkdir -p "${sub_dir}" 2>/dev/null || display_dir_error_MSG+=( "Linux command: mkdir\nLocal PVE folder: ${sub_dir}\nRemote NAS folder:$(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\n" )
      chgrp -R "${group}" "${sub_dir}" 2>/dev/null || display_dir_error_MSG+=( "Linux command: chgrp\nLocal PVE folder: ${sub_dir}\nRemote NAS folder: $(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\n" )
      chmod -R "${permission}" "${sub_dir}" 2>/dev/null || display_dir_error_MSG+=( "Linux command: chmod\nLocal PVE folder: ${sub_dir}\nRemote NAS folder: $(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\n" )
      # If mkdir error
      if [ ! ${#display_dir_error_MSG[@]} == '0' ]; then
        # Fail msg
        # Display Installation error report
        source ${COMMON_PVE_SRC_DIR}/pvesource_error_report.sh
        echo
        trap error_exit EXIT
      fi

      # Set setfacl
      if [ ! -z ${acl_01} ]; then
        setfacl -Rm g:${acl_01} "${sub_dir}" 2> /dev/null || display_permission_error_MSG+=( "Linux command: setfacl\nLocal PVE folder: ${sub_dir}\nRemote NAS folder: $(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\nLinux CLI: setfacl -Rm g:${acl_01} <foldername>\n" )
      fi
      if [ ! -z ${acl_02} ]; then
        setfacl -Rm g:${acl_02} "${sub_dir}" 2> /dev/null || display_permission_error_MSG+=( "Linux command: setfacl\nLocal PVE folder: ${sub_dir}\nRemote NAS folder: $(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\nLinux CLI: setfacl -Rm g:${acl_02} <foldername>\n" )
      fi
      if [ ! -z ${acl_03} ]; then
        setfacl -Rm g:${acl_03} "${sub_dir}" 2> /dev/null || display_permission_error_MSG+=( "Linux command: setfacl\nLocal PVE folder: ${sub_dir}\nRemote NAS folder: $(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\nLinux CLI: setfacl -Rm g:${acl_03} <foldername>\n" )
      fi
      if [ ! -z ${acl_04} ]; then
        setfacl -Rm g:${acl_04} "${sub_dir}" 2> /dev/null || display_permission_error_MSG+=( "Linux command: setfacl\nLocal PVE folder: ${sub_dir}\nRemote NAS folder: $(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\nLinux CLI: setfacl -Rm g:${acl_04} <foldername>\n" )
      fi
      if [ ! -z ${acl_05} ]; then
        setfacl -Rm g:${acl_05} "${sub_dir}" 2> /dev/null || display_permission_error_MSG+=( "Linux command: setfacl\nLocal PVE folder: ${sub_dir}\nRemote NAS folder: $(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\nLinux CLI: setfacl -Rm g:${acl_05} <foldername>\n" )
      fi
    fi
  done <<< $(printf "%s\n" "${nas_subfolder_LIST[@]}")

  # Chattr set ZFS share points attributes to +a
  while IFS=',' read -r label mnt_protocol remote_mnt sub_dir group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
    if [ ! -f ${sub_dir}/.foo_protect ]; then
      touch ${sub_dir}/.foo_protect 2> /dev/null || display_chattr_error_MSG+=( "Linux command: touch\nLocal PVE folder: ${sub_dir}\nRemote NAS folder: $(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\nLinux CLI: touch <foldername>/.foo_protect\n" )
      chattr +i ${sub_dir}/.foo_protect 2> /dev/null || display_chattr_error_MSG+=( "Linux command: chattr\nLocal PVE folder: ${sub_dir}\nRemote NAS folder: $(echo ${remote_mnt} | awk -F':' '{ print $2 }')\nShare protocol: ${mnt_protocol}\nLinux CLI: chattr +i <foldername>/.foo_protect\n" )
    fi
  done <<< $(printf "%s\n" "${nas_subfolder_LIST[@]}")
fi
#---- Finish Line ------------------------------------------------------------------