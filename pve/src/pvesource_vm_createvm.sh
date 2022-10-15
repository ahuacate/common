#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_vm_createvm.sh
# Description:  Source script for creating PVE VM containers
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Set OS version
OSTYPE=${VM_OSTYPE}
OS_DIST=${VM_OS_DIST}
OSVERSION=$(echo ${VM_OSVERSION} | sed 's/[.|_]//') # Remove and '. or '_' from version number
OTHER_OS_URL=${VM_OTHER_OS_URL}

# Regex for Ipv4 and IPv6
ip4_regex='^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
ip6_regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'

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

# Read variable file list
printsection() {
  # Example: $(printSection SECTION_NAME | sed -n 's/^name//p/' < /etc/applications.conf)
  section="$1"
  found=false
  # Run function
  while read line
  do
    [[ $found == false && "$line" != "#----[${section}]" ]] && continue
    [[ $found == true && "${line:0:6}" == '#----[' ]] && break
    found=true
    echo "$line" | sed '/^#/d' | sed -r '/^\s*$/d'
  done
}

# Spinner takes the pid of the process as the first argument and
# string to display as second argument (default provided) and spins
# until the process completes.
# Usage command && spinner $!
spinner() {
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
if [ ! -d ${OS_TMPL_PATH} ]; then
	mkdir -p ${OS_TMPL_PATH}
fi

# Check for Generic OS local availability
if [ -n "${OS_DIST}" ] && [ -n "${OSVERSION}" ]; then
  # Match download SRC for Generic OS compatible images
  eval OS_TMPL_URL='$'${OS_DIST^^}_${OSVERSION}_URL
  OS_TMPL_FILENAME="${OS_TMPL_URL##*/}"
  # Check for existing template
  while read -r storage; do
    if [[ $(pvesm list ${storage} | grep "\/${OS_TMPL_FILENAME}") ]]; then
      # Set existing tmpl location
      OS_TMPL=$(pvesm list ${storage} | grep "\/${OS_TMPL_FILENAME}" | awk '{print $1}')
      break
    fi
  done <<< $(pvesm status -content vztmpl -enabled | awk 'NR>1 {print $1}')
  # Download Generic OS compatible images
  if [ -n "${OS_TMPL}" ]; then
    msg "Downloading installation iso/img ( be patient, might take a while )..."
    while true; do
      wget -qNLc -T 15 --show-progress -c ${OS_TMPL_URL} -O ${OS_TMPL_PATH}/${OS_TMPL_FILENAME} && break
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
  OS_TMPL_URL=${OTHER_OS_URL}
  msg "Downloading installation iso/img ( be patient, might take a while )..."
  while true; do
    wget -qNLc -T 15 --show-progress --content-disposition -c ${OS_TMPL_URL} -P ${OS_TMPL_PATH} && break
  done
  # Set OS_TMPL filename
  OS_TMPL_FILENAME=$(wget --spider --server-response ${OS_TMPL_URL} 2>&1 | grep -i content-disposition | awk -F"filename=" '{if ($2) print $2}' | tr -d '"')
  if [[ $(pvesm list local | grep "\/${OS_TMPL_FILENAME}") ]]; then
    # Set tmpl location
    OS_TMPL=$(pvesm list local | grep "\/${OS_TMPL_FILENAME}" | awk '{print $1}')
  fi
fi

# OS_TMPL="$(find ${OS_TMPL_PATH} -type f)"

# VM Install dir location
rootdir_LIST=( $(pvesm status --content rootdir -enabled | awk 'NR>1 {print $1}') )
if [ ${#rootdir_LIST[@]} -eq '0' ]; then
  warn "Aborting install. A error has occurred:\n  --  Cannot determine a valid VM image storage location.\n  --  Cannot proceed until the User creates a storage location (i.e local-lvm, local-zfs).\nAborting installation..."
  echo
  sleep 2
  exit 0
elif [ ${#rootdir_LIST[@]} -eq '1' ]; then
  VOLUME="${rootdir_LIST[0]}"
elif [ ${#rootdir_LIST[@]} -gt '1' ]; then
  msg "Multple PVE storage locations have been detected to use as a VM root volume.\n\n$(pvesm status -content rootdir -enabled | awk 'BEGIN { FIELDWIDTHS="$fieldwidths"; OFS=":" } { $6 = $6 / 1048576 } { if(NR>1) print $1, $2, $3, int($6) }' | column -s ":" -t -N "LOCATION,TYPE,STATUS,CAPACITY (GB)" | indent2)\n\nThe User must make a selection."
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${rootdir_LIST[@]}")
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${rootdir_LIST[@]}")
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  VOLUME=${RESULTS}
  info "VM root volume is set: ${YELLOW}${VOLUME}${NC}"
  echo
fi


#---- Validate & set architecture dependent variables
ARCH=$(dpkg --print-architecture)

#---- Create VM input arrays
# general_LIST array
unset general_LIST
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]; then
    # Wrap Description var in quotes
    if [ "${var}" == 'DESCRIPTION' ]; then
      i=\"${i}\"
    fi
    general_LIST+=( "$(echo "--${var,,} ${i}")" )
  fi
done <<< $(printsection COMMON_GENERAL_OPTIONS < ${PRESET_VAR_SRC})
printf '%s\n' "${general_LIST[@]}"
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]; then
    j=$(echo ${var} | sed 's/^VM_//')
    general_LIST+=( "$(echo "--${j,,} ${i}")" )
  fi
done <<< $(printsection VM_GENERAL_OPTIONS < ${PRESET_VAR_SRC})
printf '%s\n' "${general_LIST[@]}"

# scsi0_LIST
unset scsi0_LIST
scsi0_LIST+=$(echo "--scsi0")
scsi0_LIST+=( "$(echo "${VOLUME}:${VM_SCSI0_SIZE}")" )
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]; then
    # Ignore VM_SCSI0_SIZE
    if [ "${var}" == 'VM_SCSI0_SIZE' ]; then 
      continue
    fi
    j=$(echo ${var} | sed 's/^VM_SCSI0_//')
    scsi0_LIST+=( "$(echo "${j,,}=${i}")" )
  fi
done <<< $(printsection VM_SCSI0_OPTIONS < ${PRESET_VAR_SRC} | grep -v '^VM_SCSI0_SIZE.*')

# scsi1_LIST
unset scsi1_LIST
scsi0_LIST+=$(echo "--scsi1")
scsi0_LIST+=( "$(echo "${VOLUME}:${VM_SCSI1_SIZE}")" )
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]; then
    # Ignore VM_SCSI1_SIZE
    if [ "${var}" == 'VM_SCSI1_SIZE' ]; then 
      continue
    fi
    j=$(echo ${var} | sed 's/^VM_SCSI1_//')
    scsi1_LIST+=( "$(echo "${j,,}=${i}")" )
  fi
done <<< $(printsection VM_SCSI1_OPTIONS < ${PRESET_VAR_SRC} | grep -v '^VM_SCSI1_SIZE.*')

# net_LIST
unset net_LIST
net_LIST+=$(echo "--net0")
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]; then
    # Ignore of tag=(0|1)
    if [ "${var}" == 'TAG' ] && [[ ${i} =~ (0|1) ]]; then 
      continue
    fi
    net_LIST+=( "$(echo "${var,,}=${i}")" )
  fi
done <<< $(printsection COMMON_NET_OPTIONS < ${PRESET_VAR_SRC})
# while IFS== read var value
# do
#   eval i='$'$var
#   if [ -n "${i}" ]; then
#     j=$(echo ${var} | sed 's/^VM_//')
#     net_LIST+=( "$(echo "${j,,}=${i}")" )
#   fi
# done <<< $(printsection VM_NET_OPTIONS < ${PRESET_VAR_SRC})

# startup_LIST
unset startup_LIST
startup_LIST+=$(echo "--startup")
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]; then
    j=$(echo ${var} | sed 's/^VM_//')
    startup_LIST+=( "$(echo "${j,,}=${i}")" )
  fi
done <<< $(printsection VM_STARTUP_OPTIONS < ${PRESET_VAR_SRC})

# cloudinit_LIST
unset cloudinit_LIST
cloudinit_LIST=()
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]; then
    j=$(echo ${var} | sed 's/^CT_//')
    cloudinit_LIST+=( "$(echo "${j,,}=${i}")" )
  fi
done <<< $(printsection VM_CLOUD_INIT < ${PRESET_VAR_SRC})

# cloudinit_ipconfig_LIST
unset cloudinit_ipconfig_LIST
cloudinit_ipconfig_LIST+=$(echo "--ipconfig0")
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]; then
    # Add CIDR value to IP/IP6
    if [ "${var}" == 'IP' ] && [[ $i =~ ${ip4_regex} ]]; then
      i=$(echo ${i} | sed "s/$/\/${CIDR}/")
    elif [ "${var}" == 'IP' ] || [ "${var}" == 'IP6' ] && [[ $i =~ 'dhcp' ]]; then
      i=$(echo ${i})
    elif [ "${var}" == 'IP6' ] && [[ $i =~ ${ip6_regex} ]]; then
      i=$(echo ${i} | sed "s/$/\/${CIDR6}/")
    fi
    j=$(echo ${var} | sed 's/^CT_//')
    cloudinit_ipconfig_LIST+=( "$(echo "${j,,}=${i}")" )
  fi
done <<< $(printsection VM_CLOUD_INIT_IPCONFIG < ${PRESET_VAR_SRC})


#---- Create VM
# Create VM variables
unset qm_create_LIST
qm_create_LIST=()
# Set VMID
qm_create_LIST+=( "$(echo "${VMID}")" )
# general_LIST vars
if [ ${#general_LIST[@]} -ge '1' ]; then
  qm_create_LIST+=( "$(printf '%s\n' "${general_LIST[@]}" | sed 's/$//')" )
fi
# net_LIST vars
qm_create_LIST+=( "$(printf '%s\n' "${net_LIST[@]}" | xargs | sed 's/ /,/2g')" )
# startup_LIST vars
if [ ${#startup_LIST[@]} -ge '2' ]; then
  qm_create_LIST+=( "$(printf '%s\n' "${startup_LIST[@]}" | xargs | sed 's/ /,/2g')" )
fi
# scsi0_LIST vars
if [ ${#scsi0_LIST[@]} -ge '2' ]; then
  qm_create_LIST+=( "$(printf '%s\n' "${scsi0_LIST[@]}" | xargs | sed 's/ /,/2g')" )
fi
# scsi1_LIST vars
if [ ${#scsi1_LIST[@]} -ge '2' ]; then
  qm_create_LIST+=( "$(printf '%s\n' "${scsi1_LIST[@]}" | xargs | sed 's/ /,/2g')" )
fi
# Set IDE/CDROM
qm_create_LIST+=( "$(echo "--ide2 ${OS_TMPL},media=cdrom")" )
# # Create VM
# msg "Creating ${HOSTNAME^} VM..."
# qm create $(printf '%s ' "${pct_create_LIST[@]}" | sed 's/$//')
# echo


printf '%s ' "${pct_create_LIST[@]}"





# # Create VM
# msg "Creating PVE ${VM_OSTYPE^} VM..."
# qm create ${VMID} \
# --name ${VM_HOSTNAME} \
# --bios seabios \
# --sockets ${VM_CPU_SOCKETS} \
# --cores ${VM_CPU_CORES} \
# --vcpus ${VM_VCPU} \
# --cpulimit ${VM_CPU_LIMIT} \
# --cpuunits ${VM_CPU_UNITS} \
# --ostype ${VM_OS_TYPE} \
# --memory ${VM_RAM} \
# --balloon ${VM_RAM_BALLOON} \
# --nameserver ${VM_DNS_SERVER} \
# --net0 ${VM_NET_MODEL},bridge=${VM_NET_BRIDGE},firewall=${VM_NET_FIREWALL}$(if [ ${VM_NET_MAC_ADDRESS} != 'auto' ]; then echo ",macaddr=${VM_NET_MAC_ADDRESS}"; fi)$(if [ ${VM_TAG} -gt 1 ]; then echo ",tag=${VM_TAG}"; fi) \
# --scsihw virtio-scsi-single \
# --scsi0 ${STORAGE}:${VM_DISK_SIZE} \
# --ide2 ${TEMPLATE_STRING},media=cdrom \
# --autostart ${VM_AUTOSTART} \
# --onboot ${VM_ONBOOT} \
# --start ${VM_START} \
# $(if [ ${VM_STARTUP_ORDER} > 0 ]; then echo "--startup order=${VM_STARTUP_ORDER}"; fi)$(if [ ${VM_STARTUP_ORDER} > 0 ] && [ ${VM_STARTUP_DELAY} -gt 0 ]; then echo ",up=${VM_STARTUP_DELAY}"; fi) >/dev/null

# #qm set --ipconfig0 gw=${VM_GW},ip=${VM_IP}/${VM_IP_SUBNET}

# # Checking VM Status
# n=0
# until [ "$n" -ge 5 ]
# do
#   if [ "$(qm list | grep -w ${VMID} > /dev/null; echo $?)" = 0 ]; then
#     if [ "$(qm status ${VMID})" == "status: stopped" ]; then
#       info "${VM_HOSTNAME^} CT has been created. Current status: ${YELLOW}$(qm status ${VMID} | awk '{print $2}')${NC}"
#       echo
#       break
#     elif [ "$(qm status ${VMID})" == "status: running" ]; then
#       info "${VM_HOSTNAME^} CT has been created. Current status: ${YELLOW}$(qm status ${VMID}| awk '{print $2}')${NC}"
#       echo
#       break
#     fi
#   elif [ "$(qm list | grep -w ${VMID} > /dev/null; echo $?)" != 0 ] && [ "$n" == 4 ]; then
#     warn "Something went wrong creating the PVE VM. ${VM_HOSTNAME^} VM has NOT been created.\nAborting this installation in 2 seconds..."
#     sleep 1
#     echo
#     # exit 0
#   fi
#   n=$((n+1)) 
#   sleep 1
# done

# # Test Run
# VMID='120'
# VM_OS_TYPE='l26'
# VM_HOSTNAME='nas-04'
# VM_CPU_UNITS='1024'
# VM_CPU_LIMIT='0'
# VM_CPU_SOCKETS='1'
# VM_CPU_CORES='1'
# VM_VCPU='1'
# VM_RAM='1024'
# VM_RAM_BALLOON='512'
# VM_DNS_SERVER='192.168.1.5'
# VM_TAG='1'
# VM_GW='192.168.1.5'
# VM_IP='192.168.1.77'
# VM_IP_SUBNET='24'
# VM_NET_BRIDGE='vmbr0'
# VM_NET_MODEL='virtio'
# VM_NET_MAC_ADDRESS='auto'
# VM_NET_FIREWALL='1'
# VM_DISK_SIZE='10'
# VM_ISO='TrueNAS-12.0-U5.1.iso'
# VM_AUTOSTART='1'
# VM_ONBOOT='1'
# VM_STARTUP_ORDER='1'
# VM_STARTUP_DELAY='30'
# VM_START='0'
# SRC_ISO_URL='https://download.freenas.org/latest/x64/TrueNAS-12.0-U5.1.iso'