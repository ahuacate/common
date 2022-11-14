#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_vm_createvm.sh
# Description:  Source script for creating PVE VM containers
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

section "Create ${VM_OSTYPE^} VM"

# Check for latest PVE VM ISO template
pveam update >/dev/null
msg "Checking VM '$VM_ISO' installation iso (be patient, might take a while)..."
wget -qNLc --show-progress - ${SRC_ISO_URL} -P /var/lib/vz/template/iso


# Set Variables
ARCH=$(dpkg --print-architecture)
TEMPLATE_STRING="local:iso/${VM_ISO}"
STORAGE_LIST=( $(pvesm status -content rootdir | awk 'NR>1 {print $1}') )

if [ ${#STORAGE_LIST[@]} -eq 0 ]; then
  warn "A problem has occurred:\n  - To create a new '${OSTYPE^} $OSVERSION' Ct/LXC PVE requires a\n    valid storage location.\n  - Cannot proceed until the User creates a storage location (i.e local-zfs).\nAborting installation in 3 seconds..."
  echo
  exit 0
elif [ ${#STORAGE_LIST[@]} -eq 1 ]; then
  STORAGE=${STORAGE_LIST[0]}
  info "Storage location is set: ${YELLOW}${STORAGE}${NC}"
  echo
else
  echo
  msg "More than one PVE storage location has been detected. The User must make a selection."
  PS3="Which storage location would you like to use (entering numeric) ?"
  select s in "${STORAGE_LIST[@]}"; do
    case $s in
      $STORAGE_LIST)
        STORAGE=$s
        echo
        break
        ;;
      *) warn "Invalid entry. Try again.." >&2
    esac
  done
  info "Storage location is set: ${YELLOW}${STORAGE}${NC}"
  echo
fi


# Create VM
msg "Creating PVE ${VM_OSTYPE^} VM..."
qm create ${VMID} \
--name ${VM_HOSTNAME} \
--bios seabios \
--sockets ${VM_CPU_SOCKETS} \
--cores ${VM_CPU_CORES} \
--vcpus ${VM_VCPU} \
--cpulimit ${VM_CPU_LIMIT} \
--cpuunits ${VM_CPU_UNITS} \
--ostype ${VM_OS_TYPE} \
--memory ${VM_RAM} \
--balloon ${VM_RAM_BALLOON} \
--nameserver ${VM_DNS_SERVER} \
--net0 ${VM_NET_MODEL},bridge=${VM_NET_BRIDGE},firewall=${VM_NET_FIREWALL}$(if [ ${VM_NET_MAC_ADDRESS} != 'auto' ]; then echo ",macaddr=${VM_NET_MAC_ADDRESS}"; fi)$(if [ ${VM_TAG} -gt 1 ]; then echo ",tag=${VM_TAG}"; fi) \
--scsihw virtio-scsi-single --scsi0 ${STORAGE}:${VM_DISK_SIZE} \
--ide2 ${TEMPLATE_STRING},media=cdrom \
--autostart ${VM_AUTOSTART} \
--onboot ${VM_ONBOOT} \
--start ${VM_START} \
$(if [ ${VM_STARTUP_ORDER} > 0 ]; then echo "--startup order=${VM_STARTUP_ORDER}"; fi)$(if [ ${VM_STARTUP_ORDER} > 0 ] && [ ${VM_STARTUP_DELAY} -gt 0 ]; then echo ",up=${VM_STARTUP_DELAY}"; fi) >/dev/null

#qm set --ipconfig0 gw=${VM_GW},ip=${VM_IP}/${VM_IP_SUBNET}

# Checking VM Status
n=0
until [ "$n" -ge 5 ]
do
  if [ "$(qm list | grep -w ${VMID} > /dev/null; echo $?)" = 0 ]; then
    if [ "$(qm status ${VMID})" == "status: stopped" ]; then
      info "${VM_HOSTNAME^} CT has been created. Current status: ${YELLOW}$(qm status ${VMID} | awk '{print $2}')${NC}"
      echo
      break
    elif [ "$(qm status ${VMID})" == "status: running" ]; then
      info "${VM_HOSTNAME^} CT has been created. Current status: ${YELLOW}$(qm status ${VMID}| awk '{print $2}')${NC}"
      echo
      break
    fi
  elif [ "$(qm list | grep -w ${VMID} > /dev/null; echo $?)" != 0 ] && [ "$n" == 4 ]; then
    warn "Something went wrong creating the PVE VM. ${VM_HOSTNAME^} VM has NOT been created.\nAborting this installation in 2 seconds..."
    sleep 1
    echo
    # exit 0
  fi
  n=$((n+1)) 
  sleep 1
done

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