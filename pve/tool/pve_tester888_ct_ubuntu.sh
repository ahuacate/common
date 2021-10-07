#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_tester888_ct_ubuntu.sh
# Description:  A Ubuntu CT for testing
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/common/master/pve/tool/pve_tester888_ct_ubuntu.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SOURCE="${DIR}/../source"

#---- Dependencies -----------------------------------------------------------------

# Check for Internet connectivity
if nc -zw1 google.com 443; then
  echo
else
  echo "Checking for internet connectivity..."
  echo -e "Internet connectivity status: \033[0;31mDown\033[0m\n\nCannot proceed without a internet connection.\nFix your PVE hosts internet connection and try again..."
  echo
  exit 0
fi

# Run Bash Header
source ${COMMON_PVE_SOURCE}/pvesource_bash_defaults.sh


#---- Static Variables -------------------------------------------------------------

# Set Max CT Host CPU Cores 
HOST_CPU_CORES=$(( $(lscpu | grep -oP '^Socket.*:\s*\K.+') * ($(lscpu | grep -oP '^Core.*:\s*\K.+') * $(lscpu | grep -oP '^Thread.*:\s*\K.+')) ))
if [ ${HOST_CPU_CORES} -gt 4 ]; then 
  CT_CPU_CORES_VAR=$(( ${HOST_CPU_CORES} / 2 ))
elif [ ${HOST_CPU_CORES} -le 4 ]; then
  CT_CPU_CORES_VAR=2
fi

# PVE host IP
PVE_HOST_IP=$(hostname -i)
PVE_HOST_NAME=$(hostname)

# SSHd Status (0 is enabled, 1 is disabled)
SSH_ENABLE=0

# Developer enable git mounts inside CT (0 is enabled, 1 is disabled)
DEV_GIT_MOUNT_ENABLE=0

#---- Other Variables --------------------------------------------------------------

# Container Hostname
CT_HOSTNAME='tester888'
# Container IP Address
CT_IP='192.168.1.88'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW='192.168.1.5'
# DNS Server
CT_DNS_SERVER='192.168.1.5'
# Container Number
CTID='888'
# Container VLAN
CT_TAG='0'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE='8'
# Container allocated RAM
CT_RAM='1024'
# Easy Script Section Header Body Text
SECTION_HEAD='Ubuntu Tester'
#---- Do Not Edit
# Container Swap
CT_SWAP="$(( $CT_RAM / 2 ))"
# CT CPU Cores
CT_CPU_CORES="$CT_CPU_CORES_VAR"
# CT unprivileged status
CT_UNPRIVILEGED='0'
# Features (0 means none)
CT_FUSE='0'
CT_KEYCTL='0'
CT_MOUNT='nfs'
CT_NESTING='1'
# Startup Order
CT_STARTUP='2'
# Container Root Password ( 0 means none )
CT_PASSWORD='ahuacate'
# PVE Container OS
OSTYPE='ubuntu'
OSVERSION='21.04'

# CT SSH Port
SSH_PORT='22'


#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

if [ "$(pct_list | awk -F',' '{ print $1 }' | grep -w $CTID > /dev/null; echo $?)" != 0 ] && [ $(ls /var/lib/vz/dump/vzdump-lxc-${CTID}-*.tar.zst > /dev/null 2>&1; echo $?) == 0 ]; then
  GET_FILE=$(ls -t /var/lib/vz/dump/vzdump-lxc-${CTID}-*.tar.zst | head -n 1)
  pct restore ${CTID} ${GET_FILE} -storage local-zfs
  pct start ${CTID}
  CT_NEW=1
else
  CT_NEW=0
fi

#---- Create new CT
if [ $CT_NEW == 0 ] && [ "$(pct_list | awk -F',' '{ print $1 }' | grep -w $CTID > /dev/null; echo $?)" != 0 ]; then
  #---- Developer Options
  FUNC_NAS_HOSTNAME=nas
  if [ -f /mnt/pve/nas-*[0-9]-git/ahuacate/developer_settings.git ]; then
    while IFS== read -r var val; do
      eval ${var}=${val}
    done < <(cat /mnt/pve/nas-*[0-9]-git/ahuacate/developer_settings.git | grep -v '^#')
  fi
  if [ $dev_git_mount = 0 ] && [ $DEV_GIT_MOUNT_ENABLE = 0 ]; then
    pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-git" | awk '{print $1,"/mnt/pve/"$1}' >> pvesm_input_list
  else
    touch pvesm_input_list
  fi

  #---- Create OS CT
  source ${COMMON_PVE_SOURCE}/pvesource_ct_createvm.sh

  #---- Pre-Configuring PVE CT
  section "Pre-Configure ${OSTYPE^} CT"

  # Create CT Bind Mounts
  source ${COMMON_PVE_SOURCE}/pvesource_ct_createbindmounts.sh

  # Configure New CT OS
  source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntubasics.sh

  # Download and Install Prerequisites
  pct exec $CTID -- apt-get install -y acl >/dev/null
  pct exec $CTID -- apt-get install -y putty-tools >/dev/null

  #---- Creating PVE NAS Users and Groups
  section "Creating Users and Groups."

  # Change Home folder permissions
  msg "Setting default adduser home folder permissions (DIR_MODE)..."
  pct exec $CTID -- sed -i "s/DIR_MODE=.*/DIR_MODE=0750/g" /etc/adduser.conf
  info "Default adduser permissions set: ${WHITE}0750${NC}"
  pct exec $CTID -- bash -c 'echo "HOME_MODE 0750" >> /etc/login.defs'

  # Create users and groups
  msg "Creating CT default user groups..."
  # Create Groups
  pct exec $CTID -- bash -c 'groupadd -g 65605 medialab > /dev/null'
  info "Default user group created: ${YELLOW}medialab${NC}"
  pct exec $CTID -- bash -c 'groupadd -g 65606 homelab > /dev/null'
  info "Default user group created: ${YELLOW}homelab${NC}"
  pct exec $CTID -- bash -c 'groupadd -g 65607 privatelab > /dev/null'
  info "Default user group created: ${YELLOW}privatelab${NC}"
  pct exec $CTID -- bash -c 'groupadd -g 65608 chrootjail > /dev/null'
  info "Default user group created: ${YELLOW}chrootjail${NC}"
  echo

  # Create Base User Accounts
  msg "Creating CT default users..."
  pct exec $CTID -- bash -c 'useradd -u 1605 -g medialab -s /bin/bash media >/dev/null'
  info "Default user created: ${YELLOW}media${NC} of group medialab"
  pct exec $CTID -- bash -c 'useradd -u 1606 -g homelab -G medialab -s /bin/bash home >/dev/null'
  info "Default user created: ${YELLOW}home${NC} of groups medialab, homelab"
  pct exec $CTID -- bash -c 'useradd -u 1607 -g privatelab -G medialab,homelab -s /bin/bash private >/dev/null'
  info "Default user created: ${YELLOW}private${NC} of groups medialab, homelab and privatelab"
  echo

  #---- Webmin
  section "Installing Webmin."
  # Install Webmin Prerequisites
  msg "Installing Webmin prerequisites (be patient, might take a while)..."

  pct exec $CTID -- bash -c "echo 'deb http://download.webmin.com/download/repository sarge contrib' | sudo tee -a /etc/apt/sources.list"
  pct exec $CTID -- bash -c 'wget -qL http://www.webmin.com/jcameron-key.asc'
  pct exec $CTID -- bash -c 'apt-key add jcameron-key.asc 2>/dev/null'
  pct exec $CTID -- apt-get update
  pct exec $CTID -- apt-get install -y webmin

  #---- Finish Up
  msg "Creating snapshot to local-zfs..."
  vzdump 888 --dumpdir /var/lib/vz/dump/ --mode snapshot --compress zstd
fi

#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

msg "${CT_HOSTNAME^^} installation was a success. To manage your new Ubuntu CT use Webmin (a Linux web management tool). Webmin login credentials are user 'root' and password '${CT_PASSWORD}'.\n\n  --  ${WHITE}https://$(echo "$CT_IP" | sed  's/\/.*//g'):10000/${NC}\n  --  ${WHITE}https://${CT_HOSTNAME}:10000/${NC}"

# Cleanup
trap cleanup EXIT