#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_createvm.sh
# Description:  Source script for creating PVE CT containers
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# PCT list
function pct_list() {
  pct list | perl -lne '
  if ($. == 1) {
      @head = ( /(\S+\s*)/g );
      pop @head;
      $patt = "^";
      $patt .= "(.{" . length($_) . "})" for @head;
      $patt .= "(.*)\$";
  }
  print join ",", map {s/"/""/g; s/\s+$//; qq($_)} (/$patt/o);'
}

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

section "Create ${OSTYPE^} CT"

# Download latest PVE CT OS template
pveam update >/dev/null
mapfile -t TEMPLATES < <(pveam available -section system | sed -n "s/.*\($OSTYPE-$OSVERSION.*\)/\1/p" | sort -t - -k 2 -V)
if [ $(printf '%s\n' "${vmid_LIST[@]}" | wc -l) > 1 ]; then
  TEMPLATE="${TEMPLATES[-1]}"
fi
if [ ! -f /var/lib/vz/template/cache/${TEMPLATE} ]; then
  msg "Updating Proxmox '${OSTYPE^} $OSVERSION' CT/LXC template (be patient, might take a while)..."
  pveam download local ${TEMPLATE} 2>&1
  if [ $? -ne 0 ]; then
    warn "A problem occurred while downloading the LXC template version: $OSTYPE-$OSVERSION\nCheck your internet connection and try again. Aborting installation in 3 seconds..."
    sleep 2
    exit 0
  fi
fi

# Set Variables
ARCH=$(dpkg --print-architecture)
TEMPLATE_STRING="local:vztmpl/${TEMPLATE}"
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


# Create CT
msg "Creating ${CT_HOSTNAME^} CT..."
pct create $CTID $TEMPLATE_STRING \
--arch $ARCH \
--cores $CT_CPU_CORES \
--hostname $CT_HOSTNAME \
--cpulimit 1 \
--cpuunits 1024 \
--memory $CT_RAM \
--nameserver $CT_DNS_SERVER \
--features fuse=${CT_FUSE},keyctl=${CT_KEYCTL},$(if [ ${CT_MOUNT} == 'cifs' ] || [ ${CT_MOUNT} == 'nfs' ] || [ ${CT_MOUNT} == 'nfs;cifs' ]|| [ ${CT_MOUNT} == 'cifs;nfs' ]; then echo "mount=${CT_MOUNT},"; fi)nesting=${CT_NESTING} \
--net0 name=eth0,bridge=vmbr0,$(if [ ${CT_TAG} -gt 1 ]; then echo "tag=$CT_TAG,"; fi)firewall=1,gw=$CT_GW,ip=$CT_IP/$CT_IP_SUBNET,type=veth \
--ostype $OSTYPE \
--rootfs $STORAGE:$CT_DISK_SIZE,acl=1 \
--swap $CT_SWAP \
--unprivileged $CT_UNPRIVILEGED \
--onboot 1 \
$(if ! [[ ${CT_PASSWORD} =~ ^[0-9]+$ ]]; then echo "--password ${CT_PASSWORD}"; fi) \
--startup order=$CT_STARTUP >/dev/null

# Check CT Status
sleep 2
if [ "$(pct_list | grep -w $CTID > /dev/null; echo $?)" = 0 ]; then
  if [ "$(pct status $CTID)" == "status: stopped" ]; then
    info "${CT_HOSTNAME^} CT has been created. Current status: ${YELLOW}$(pct status $CTID | awk '{print $2}')${NC}"
    echo
  elif [ "$(pct status $CTID)" == "status: running" ]; then
    info "${CT_HOSTNAME^} CT has been created. Current status: ${YELLOW}$(pct status $CTID | awk '{print $2}')${NC}"
    echo
  fi
elif [ "$(pct_list | grep -w $CTID > /dev/null; echo $?)" != 0 ]; then
  warn "Something went wrong. ${CT_HOSTNAME^} CT has NOT been created. Aborting this installation."
  echo
  exit 0
fi

#---- Finish Line ------------------------------------------------------------------