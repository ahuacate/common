#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_subfolder_installer_precheck.sh
# Description:  Source script for installers to check and create NAS subfolders
#               Run after 'pvesource_set_allvmvars.sh'
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Must run after 'pvesource_set_allvmvars.sh'
# Check mnt Cnt. Exclude shares which have no sub folders.
if [ "$(printf '%s\n' "${pvesm_input_LIST[@]}" | grep -Ev '/mnt/(backup|music|photo)' | wc -l)" -eq 0 ]; then
    return
fi

# Check for ACL installation
if ! dpkg -s acl > /dev/null 2>&1; then
    apt-get install -y acl > /dev/null
fi

# Check for chattr command
if ! command -v chattr > /dev/null 2>&1; then
    # chattr not found, install e2fsprogs
    apt-get update -y
    apt-get -y install e2fsprogs > /dev/null
fi

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Initialize list arrays
dir_check_LIST=()
nas_subfolder_LIST=()
display_dir_error_MSG=()
display_permission_error_MSG=()
display_chattr_error_MSG=()

# Create PVESM check list
# Array 'pvesm_input_LIST' is the CT required list matched to PVESM mnt(s)
while IFS=',' read -r pve_mnt ct_mnt; do
    label=$(echo "$ct_mnt" | sed 's/^\/mnt\///')
    remote_mnt=$(df -h | awk -v var="$pve_mnt" '{ if ($0 ~ var) print $1 }')
    mnt_protocol=$(pvesm status | grep "^$pve_mnt" | awk '{ print $2 }')

    # Combine to create list
    while IFS= read -r sub_dir; do
        remote_mnt_sub=$(echo "$sub_dir" | awk -F',' '{ print $1}' | sed "s|.*${pve_mnt}||")
        dir_check_LIST+=( "$label,$mnt_protocol,$remote_mnt$remote_mnt_sub,$sub_dir" )
    done < <( cat "$COMMON_DIR/nas/src/nas_basefoldersubfolderlist" | awk -F',' -v var="$label" '{ if ($1 ~ "^" var) print $0 }' | sed "s/${label}/\/mnt\/pve\/${pve_mnt}/" )
done < <( printf '%s\n' "${pvesm_input_LIST[@]}" | grep -Ev '/mnt/(backup|music|photo)' )

# Check if dir exists
# Add missing dir to 'nas_subfolder_LIST'
while IFS=',' read -r label mnt_protocol remote_mnt sub_dir other; do
    if ! [ -d "$sub_dir" ]; then
        nas_subfolder_LIST+=( "$label,$mnt_protocol,$remote_mnt,$sub_dir,$other" )
    fi
done < <( printf '%s\n' "${dir_check_LIST[@]}" )

# Create subfolders required by CT
if [ ! "${#nas_subfolder_LIST[@]}" = 0 ]; then
    section "${HOSTNAME^} subfolders"
    msg "Creating ${SECTION_HEAD} subfolders required by CT application..."
    echo

    while IFS=',' read -r label mnt_protocol remote_mnt sub_dir user group permission inherit acl_01 acl_02 acl_03 acl_04 acl_05; do
        if [ -d "$sub_dir" ]; then
            info "Pre-existing folder: ${UNDERLINE}$sub_dir${NC}"

            # Check for '.foo_protect' file
            [ -f "$sub_dir/.foo_protect" ] || display_chattr_error_MSG+=( "Linux command: touch & chattr (missing .foo_protect)\nLocal PVE folder: $sub_dir\nRemote NAS folder: $(echo "$remote_mnt" | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\nLinux CLI: touch <foldername>/.foo_protect && chattr +i <foldername>/.foo_protect\n" )
            
            # Check folder grp ownership
            [ "$(ls -ld $sub_dir | awk '{ print $4 }')" = $group ] || display_dir_error_MSG+=( "Linux command: chgrp (not GID ${group})\nLocal PVE folder: $sub_dir\nRemote NAS folder: $(echo "$remote_mnt" | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\n" )
            echo
        else
            info "New subfolder created:\n  ${WHITE}$sub_dir${NC}"

            # Make dir
            mkdir -p "$sub_dir" 2>/dev/null || display_dir_error_MSG+=( "Linux command: mkdir\nLocal PVE folder: $sub_dir\nRemote NAS folder:$(echo "$remote_mnt" | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\n" )

            # Set dir Grp
            chgrp -R "$group" "$sub_dir" 2>/dev/null || display_dir_error_MSG+=( "Linux command: chgrp\nLocal PVE folder: $sub_dir\nRemote NAS folder: $(echo $remote_mnt | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\n" )
            chmod -R "$permission" "$sub_dir" 2>/dev/null || display_dir_error_MSG+=( "Linux command: chmod\nLocal PVE folder: $sub_dir\nRemote NAS folder: $(echo $remote_mnt | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\n" )

            # If mkdir error
            if [ ! ${#display_dir_error_MSG[@]} = 0 ]; then
                # Fail msg
                # Display Installation error report
                source $COMMON_PVE_SRC_DIR/pvesource_error_log.sh
                echo
                error_exit
            fi

            # Set setfacl
            # Set inherit permission acl
            if [ -n "$inherit" ] && [ "$inherit" -eq 0 ]; then
                perm_inherit='-m'
            elif [ -n "$inherit" ] && [ "$inherit" -eq 1 ]; then
                perm_inherit='-Rm'
            else
                perm_inherit='-Rm'
            fi
            # Only applied if setfacl cmd works
            if [ ! -z ${acl_01} ]; then
                setfacl $perm_inherit g:$acl_01 "$sub_dir" 2> /dev/null || display_permission_error_MSG+=( "Linux command: setfacl\nLocal PVE folder: $sub_dir\nRemote NAS folder: $(echo "$remote_mnt" | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\nLinux CLI: setfacl $perm_inherit g:$acl_01 <foldername>\n" )
            fi
            if [ ! -z ${acl_02} ]; then
                setfacl $perm_inherit g:$acl_02 "$sub_dir" 2> /dev/null || display_permission_error_MSG+=( "Linux command: setfacl\nLocal PVE folder: $sub_dir\nRemote NAS folder: $(echo "$remote_mnt" | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\nLinux CLI: setfacl $perm_inherit g:$acl_02 <foldername>\n" )
            fi
            if [ ! -z ${acl_03} ]; then
                setfacl $perm_inherit g:$acl_03 "$sub_dir" 2> /dev/null || display_permission_error_MSG+=( "Linux command: setfacl\nLocal PVE folder: $sub_dir\nRemote NAS folder: $(echo "$remote_mnt" | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\nLinux CLI: setfacl $perm_inherit g:$acl_03 <foldername>\n" )
            fi
            if [ ! -z ${acl_04} ]; then
                setfacl $perm_inherit g:$acl_04 "$sub_dir" 2> /dev/null || display_permission_error_MSG+=( "Linux command: setfacl\nLocal PVE folder: $sub_dir\nRemote NAS folder: $(echo "$remote_mnt" | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\nLinux CLI: setfacl $perm_inherit g:$acl_04 <foldername>\n" )
            fi
            if [ ! -z ${acl_05} ]; then
                setfacl $perm_inherit g:$acl_05 "$sub_dir" 2> /dev/null || display_permission_error_MSG+=( "Linux command: setfacl\nLocal PVE folder: $sub_dir\nRemote NAS folder: $(echo "$remote_mnt" | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\nLinux CLI: setfacl $perm_inherit g:$acl_05 <foldername>\n" )
            fi
        fi
    done < <( printf "%s\n" "${nas_subfolder_LIST[@]}" )

    # Chattr set ZFS share points attributes to +a
    while IFS=',' read -r label mnt_protocol remote_mnt sub_dir user group permission inherit acl_01 acl_02 acl_03 acl_04 acl_05; do
        if [ ! -f "$sub_dir/.foo_protect" ]; then
            # Create 'foo_protect' file
            touch "$sub_dir/.foo_protect" 2> /dev/null || display_chattr_error_MSG+=( "Linux command: touch\nLocal PVE folder: $sub_dir\nRemote NAS folder: $(echo "$remote_mnt" | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\nLinux CLI: touch <foldername>/.foo_protect\n" )
            # Chattr protect 'foo_protect' file
            chattr +i ${sub_dir}/.foo_protect 2> /dev/null || display_chattr_error_MSG+=( "Linux command: chattr\nLocal PVE folder: $sub_dir\nRemote NAS folder: $(echo "$remote_mnt" | awk -F':' '{ print $2 }')\nShare protocol: $mnt_protocol\nLinux CLI: chattr +i <foldername>/.foo_protect\n" )
        fi
    done < <( printf "%s\n" "${nas_subfolder_LIST[@]}" )
fi
#-----------------------------------------------------------------------------------