#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_vm_createvm.sh
# Description:  Source script for creating PVE VM machines
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Set OS version
OSTYPE="$VM_OSTYPE"
OS_DIST="$VM_OS_DIST"
OSVERSION=$(echo "$VM_OSVERSION" | sed 's/[.|_]//') # Remove and '. or '_' from version number
OTHER_OS_URL="$VM_OTHER_OS_URL"

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Generic OS URLS - Available compatible cloud-init images to download
DEBIAN_10_URL="https://cdimage.debian.org/cdimage/openstack/current-10/debian-10-openstack-amd64.raw"
DEBIAN_9_URL="https://cdimage.debian.org/cdimage/openstack/current-9/debian-9-openstack-amd64.raw"
UBUNTU_1804_URL="https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
UBUNTU_2004_URL="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
UBUNTU_2110_URL="https://cloud-images.ubuntu.com/impish/current/impish-server-cloudimg-amd64.img"
UBUNTU_2204_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"

#---- Functions --------------------------------------------------------------------

#---- printsection
printsection() {
  # Read variable file list by section.
  # Example: $(printsection section_name | sed -n 's/^name//p/' < /etc/applications.conf)

  # Local args
  local section="$1"
  found=false

  # Run function
  while read line; do
    [[ $found == false && "$line" != "#----[${section}]" ]] && continue
    [[ $found == true && "${line:0:6}" == '#----[' ]] && break
    found=true
    echo "$line" | sed '/^#/d' | sed -r '/^\s*$/d'
  done
}

#---- create_section_category_LIST
create_section_category_LIST() {
  # Get all section category names.
  # Creates array named: section_category_LIST

  # Unset list name
  section_category_LIST=()

  # Run function
  while read line
  do
    if [[ "$line" =~ ^\#[\-]{4}\[(CT|VM)_[\-A-Z0-9_]+_OPTIONS\]$ ]]; then
      section_category_LIST+=( "$(echo "$line" | sed -E 's/(^|\])[^[]*($|\[)//g')" )
    fi
  done < ${PRESET_VAR_SRC}
}
# create_section_category_LIST
# printf '%s\n' "${section_category_LIST[@]}"


#---- make_vm_create_LIST
function make_vm_create_LIST() {
  # Requires function 'printsection'
  # Requires src file input: "$PRESET_VAR_SRC" must be set.
  # To run example: make_vm_create_LIST "VM_NET_OPTIONS" "net_LIST"
  # "section_name" and "list_name" must be included.
  # If OPTION_STATUS='1:0' a single option value list is created:
  #   --name=nas-01
  #   --description='OMV NAS Appliance'
  #   --onboot=1
  # If OPTION_STATUS='1:net' a string option "--net" value list is created:
  #   --net ip=dhcp,gw=192.168.1.15
  # If OPTION_STATUS='0:0' the section is skipped. No array list is processed.

  # Unset list name.
  # unset ${string_name}

  # Local args
  local section_name=$1
  local list_name=$2

  # Create section list
  arr_LIST=()
  results_LIST=()

  while IFS== read var value; do
    eval $var=$value
    eval i='$'$var

    # Check enable option
    if [[ "$var" =~ ^OPTION_STATUS$ ]] && [[ "$i" =~ ^0\:.*$ ]]; then
      break
    elif [[ "$var" =~ ^OPTION_STATUS$ ]] && [[ "$i" =~ ^1\:[\-a-z_]+[0-9]?+$ ]]; then
      string_name=$(echo $i | awk -F':' '{ print $NF }')
      arr_LIST+=( "--${string_name}" )
      continue
    elif [[ "$var" =~ ^OPTION_STATUS$ ]] && [[ "$i" =~ ^1\:0$ ]]; then
      unset string_name
      continue
    fi
    # Make array value
    if [ -n "${i}" ]; then
      # j=$(echo ${var} | sed -e "s/^\(VM\|CT\)_//i")
      mod_list='QEMU\|VGA'
      j=$(echo ${var} | sed -e "s/^\(VM\|CT\)_//i" -e "s/^\(${mod_list}\)_//i" )
      if [ -n "${string_name}" ]; then
        # SCSI args
        if [[ "${string_name}" =~ ^scsi[0-9]$ ]] && [[ "${j}" =~ ^SCSI[0-9]_SIZE$ ]]; then
          arr_LIST+=( "${VOLUME}:${i}" )
        elif [[ "${string_name}" =~ ^scsi[0-9]$ ]] && [[ "${j}" =~ ^SCSI[0-9]_[A-Z]+$ ]]; then
          arr_LIST+=( "$(echo ${j,,} | sed -e "s/^\(SCSI[0-9]\)_//i")=${i}" )
        # CDROM args
        elif [[ "${string_name}" =~ ^cdrom$ ]] && [[ "${j}" =~ ^ISO_SRC$ ]]; then
          arr_LIST+=( "${OS_TMPL}" )
          echo "${OS_TMPL}"
          echo hello
          sleep 2
        # NET args 
        elif [[ "${string_name}" =~ ^net[0-9]$ ]] && [[ "${j}" =~ ^TAG$ ]] && [[ "${i}" =~ (0|1) ]]; then
          continue
        # IPv4 args
        elif [[ "${string_name}" =~ ^ipconfig[0-9]$ ]] && [[ "${j}" =~ ^IP$ ]] && [[ "${i}" =~ ${ip4_regex} ]]; then
          arr_LIST+=( "${j,,}=${i}/${CIDR}" )
        # IPv6 args
        elif [[ "${string_name}" =~ ^ipconfig[0-9]$ ]] && [[ "${j}" =~ ^IP$ ]] && [[ "${i}" =~ ${ip6_regex} ]]; then
          arr_LIST+=( "${j,,}=${i}/${CIDR6}" )
        # Standard string
        else
          arr_LIST+=( "$(echo "${j,,}=${i}")" )
        fi
      else
        arr_LIST+=( "$(echo "--${j,,} ${i}")" )
      fi
    fi
  done <<< $(printsection ${section_name} < ${PRESET_VAR_SRC})

  # Assemble 'results' array
  if [ "${#arr_LIST[@]}" != '0' ]; then
    if [ -n "${string_name}" ]; then
      # Add arr string options to results_LIST
      results_LIST+=( "$(echo "${arr_LIST[*]}" | sed 's/ /,/2g')" )
    else
      # Add single options to results_LIST
      for i in "${arr_LIST[@]}"
      do 
        results_LIST+=( "$(echo "$i")" )
      done
    fi
  fi

  # Create list by name
  if [ -n "${list_name}" ]; then
    name=${list_name}
    unset $name
    for ((i=0; i<${#results_LIST[@]}; ++i)) ; do
        read "$name[$i]" <<< "${results_LIST[i]}"
    done
  fi
}
# make_vm_create_LIST "VM_GENERAL_OPTIONS" "test_LIST"
# printf '%s\n' "${test_LIST[@]}"

#---- Spinner
spinner() {
  # Spinner takes the pid of the process as the first argument and
  # string to display as second argument (default provided) and spins
  # until the process completes.
  # Usage command && spinner $!
  local PROC="$1"
  local str="${2:-Working...}"
  local delay="0.1"
  tput civis  # hide cursor
  while [ -d /proc/$PROC ]; do
    printf '\033[s\033[u[ / ] %s\033[u' "$str"; sleep "$delay"
    printf '\033[s\033[u[ — ] %s\033[u' "$str"; sleep "$delay"
    printf '\033[s\033[u[ \ ] %s\033[u' "$str"; sleep "$delay"
    printf '\033[s\033[u[ | ] %s\033[u' "$str"; sleep "$delay"
  done
  printf '\033[s\033[u%*s\033[u\033[0m' $((${#str}+6)) " "  # return to normal
  tput cnorm  # restore cursor
  return 0
}

#---- Body -------------------------------------------------------------------------

#---- Prerequisites
section "Prerequisites"

# Update PVE VM OS template list
pveam update >/dev/null

# Template path
OS_TMPL_PATH='/var/lib/vz/template/iso'
# Check template path exists
if [ ! -d "$OS_TMPL_PATH" ]; then
	mkdir -p "$OS_TMPL_PATH"
fi

# Check for Generic OS local availability
if [ -n "${OS_DIST}" ] && [ -n "${OSVERSION}" ]; then
  # Match download SRC for Generic OS compatible images
  eval OS_TMPL_URL='$'${OS_DIST^^}_${OSVERSION}_URL
  OS_TMPL_FILENAME="${OS_TMPL_URL##*/}"

  # Check for existing template
  while read -r storage
  do
    if [[ $(pvesm list $storage | grep "\/${OS_TMPL_FILENAME}") ]]; then
      # Set existing tmpl location
      OS_TMPL=$(pvesm list $storage | grep "\/${OS_TMPL_FILENAME}" | awk '{print $1}')
      break
    fi
  done < <( pvesm status -content vztmpl -enabled | awk 'NR>1 {print $1}' )

  # Download Generic OS compatible images
  if [ -n "${OS_TMPL}" ]; then
    msg "Downloading installation iso/img ( be patient, might take a while )..."
    while true
    do
      wget -qNLc -T 15 --show-progress -c $OS_TMPL_URL -O $OS_TMPL_PATH/$OS_TMPL_FILENAME && break
    done
    if [[ $(pvesm list local | grep "\/${OS_TMPL_FILENAME}") ]]; then
      # Set tmpl location
      OS_TMPL=$(pvesm list local | grep "\/${OS_TMPL_FILENAME}" | awk '{print $1}')
    fi
  fi
fi

# Check for Custom OS local availability
if [ -n "${OTHER_OS_URL}" ]; then
  # Download src Custom iso/img
  OS_TMPL_URL="$OTHER_OS_URL"
  msg "Downloading installation iso/img ( be patient, might take a while )..."
  while true
  do
    wget -qNLc -T 15 --show-progress --content-disposition -c $OS_TMPL_URL -P $OS_TMPL_PATH && break
  done

  # Set OS_TMPL filename
  OS_TMPL_FILENAME=$(wget --spider --server-response $OS_TMPL_URL 2>&1 | grep -i content-disposition | awk -F"filename=" '{if ($2) print $2}' | tr -d '"')
  echo $OS_TMPL_FILENAME
  echo hello6
  if [[ $(pvesm list local | grep "\/${OS_TMPL_FILENAME}") ]]; then
    # Set tmpl location
    OS_TMPL=$(pvesm list local | grep "\/${OS_TMPL_FILENAME}" | awk '{print $1}')
  fi
  echo
fi

# VM Install dir location
rootdir_LIST=( $(pvesm status --content rootdir -enabled | awk 'NR>1 {print $1}') )
if [ "${#rootdir_LIST[@]}" = 0 ]; then
  warn "Aborting install. A error has occurred:\n  --  Cannot determine a valid VM image storage location.\n  --  Cannot proceed until the User creates a storage location (i.e local-lvm, local-zfs).\nAborting installation..."
  echo
  sleep 2
  exit 0
elif [ "${#rootdir_LIST[@]}" = 1 ]; then
  VOLUME="${rootdir_LIST[0]}"
elif [ "${#rootdir_LIST[@]}" -gt 1 ]; then
  msg "Multiple PVE storage locations have been detected to use as a VM root volume.\n\n$(pvesm status -content rootdir -enabled | awk 'BEGIN { FIELDWIDTHS="$fieldwidths"; OFS=":" } { $6 = $6 / 1048576 } { if(NR>1) print $1, $2, $3, int($6) }' | column -s ":" -t -N "LOCATION,TYPE,STATUS,CAPACITY (GB)" | indent2)\n\nThe User must make a selection."
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${rootdir_LIST[@]}")
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${rootdir_LIST[@]}")
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  VOLUME="$RESULTS"
  info "VM root volume is set: ${YELLOW}$VOLUME${NC}"
  echo
fi


#---- Create VM input arrays

# Create default lists
create_section_category_LIST

# Create VM run script
input_LIST=()
input_LIST+=( "$VMID" )
while read line
do
  # Run func 
  make_vm_create_LIST "$line"
  # Add results to input_LIST
  if [ ! "${#results_LIST[@]}" = 0 ]; then
    input_LIST+=( "$(printf '%s\n' "${results_LIST[@]}")" )
  fi
done < <( printf '%s\n' "${section_category_LIST[@]}" )

# Create VM
msg "Creating ${HOSTNAME^} VM..."
printf '%s ' "${input_LIST[@]}"
qm create $(printf '%s ' "${input_LIST[@]}")
echo
#-----------------------------------------------------------------------------------