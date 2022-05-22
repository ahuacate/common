#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_tester_ct_ubuntu.sh
# Description:  A Ubuntu CT for testing
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source Github
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/common/master/pve/tool/pve_tester_ct_ubuntu.sh)"

#---- Source local Git
# /mnt/pve/nas-01-git/ahuacate/common/pve/tool/pve_tester_ct_ubuntu.sh

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SRC_DIR="${DIR}/../src"

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
source ${COMMON_PVE_SRC_DIR}/pvesource_bash_defaults.sh


#---- Static Variables -------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='Tester CT'

# PVE host IP
PVE_HOST_IP=$(hostname -i)
PVE_HOST_NAME=$(hostname)

# SSHd Status (0 is enabled, 1 is disabled)
SSH_ENABLE=0

# Developer enable git mounts inside CT (0 is enabled, 1 is disabled)
DEV_GIT_MOUNT_ENABLE=0

#---- Other Variables --------------------------------------------------------------

#---- Common Machine Variables
# VM Type ( 'ct' or 'vm' only lowercase )
VM_TYPE='ct'
# Use DHCP. '0' to disable, '1' to enable.
NET_DHCP='1'
#  Set address type 'dhcp4'/'dhcp6' or '0' to disable.
NET_DHCP_TYPE='dhcp4'
# CIDR IPv4
CIDR='24'
# CIDR IPv6
CIDR6='64'
# SSHd Port
SSH_PORT='22'

#----[COMMON_GENERAL_OPTIONS]
# Hostname
HOSTNAME='tester'
# Description for the Container (one word only, no spaces). Shown in the web-interface CT’s summary. 
DESCRIPTION=''
# Allocated memory or RAM (MiB).
MEMORY='512'
# Limit number of CPU sockets to use.  Value 0 indicates no CPU limit.
CPULIMIT='0'
# CPU weight for a VM. Argument is used in the kernel fair scheduler. The larger the number is, the more CPU time this VM gets.
CPUUNITS='1024'
# The number of cores assigned to the vm/ct. Do not edit - its auto set.
CORES='1'

#----[COMMON_NET_OPTIONS]
# Bridge to attach the network device to.
BRIDGE='vmbr0'
# A common MAC address with the I/G (Individual/Group) bit not set. 
HWADDR=""
# Controls whether this interface’s firewall rules should be used.
FIREWALL='1'
# VLAN tag for this interface (value 0 for none, or VLAN[2-N] to enable).
TAG='0'
# VLAN ids to pass through the interface
TRUNKS=""
# Apply rate limiting to the interface (MB/s). Value "" for unlimited.
RATE=""
# MTU - Maximum transfer unit of the interface.
MTU=""

#----[COMMON_NET_DNS_OPTIONS]
# Nameserver server IP (IPv4 or IPv6) (value "" for none).
NAMESERVER=''
# Search domain name (local domain)
SEARCHDOMAIN=''

#----[COMMON_NET_STATIC_OPTIONS]
# IP address (IPv4). Only works with static IP (DHCP=0).
IP='192.168.1.10'
# IP address (IPv6). Only works with static IP (DHCP=0).
IP6=''
# Default gateway for traffic (IPv4). Only works with static IP (DHCP=0).
GW='192.168.1.5'
# Default gateway for traffic (IPv6). Only works with static IP (DHCP=0).
GW6=''


#---- PVE CT
#----[CT_GENERAL_OPTIONS]
# Unprivileged container status 
CT_UNPRIVILEGED='1'
# Memory swap
CT_SWAP='512'
# OS
CT_OSTYPE='ubuntu'
# Onboot startup
CT_ONBOOT='1'
# Timezone
CT_TIMEZONE='host'
# Root credentials
CT_PASSWORD='ahuacate'
# Virtual OS/processor architecture.
CT_ARCH='amd64'

#----[CT_FEATURES_OPTIONS]
# Allow using fuse file systems in a container.
CT_FUSE='0'
# For unprivileged containers only: Allow the use of the keyctl() system call.
CT_KEYCTL='0'
# Allow mounting file systems of specific types. (Use 'nfs' or 'cifs' or 'nfs;cifs' for both or leave empty "")
CT_MOUNT=''
# Allow nesting. Best used with unprivileged containers with additional id mapping.
CT_NESTING='0'
# A public key for connecting to the root account over SSH (insert path).

#----[CT_ROOTFS_OPTIONS]
# Virtual Disk Size (GB).
CT_SIZE='5'
# Explicitly enable or disable ACL support.
CT_ACL='1'

#----[CT_STARTUP_OPTIONS]
# Startup and shutdown behavior ( '--startup order=1,up=1,down=1' ). Order is a non-negative number defining the general startup order. Up=1 means first to start up. Shutdown in done with reverse ordering so down=1 means last to shutdown.
CT_ORDER='1'
CT_UP='2'
CT_DOWN='2'

#----[CT_NET_OPTIONS]
# Name of the network device as seen from inside the VM/CT.
CT_NAME='eth0'
CT_TYPE='veth'

#----[CT_OTHER]
# OS Version
CT_OSVERSION='21.04'
# CTID numeric ID of the given container.
CTID='188'


#---- Other Files ------------------------------------------------------------------

# Required PVESM Storage Mounts for CT ( new version )
unset pvesm_required_LIST
pvesm_required_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ ^\#.*$ ]] && continue
  pvesm_required_LIST+=( "$line" )
done << EOF
# Example
# backup:CT settings backup storage
EOF


#---- Body -------------------------------------------------------------------------

# if [ "$(pct_list | awk -F',' '{ print $1 }' | grep -w $CTID > /dev/null; echo $?)" != 0 ] && [ $(ls /var/lib/vz/dump/vzdump-lxc-${CTID}-*.tar.zst > /dev/null 2>&1; echo $?) == 0 ]; then
#   GET_FILE=$(ls -t /var/lib/vz/dump/vzdump-lxc-${CTID}-*.tar.zst | head -n 1)
#   pct restore ${CTID} ${GET_FILE} -storage local-zfs
#   pct start ${CTID}
#   CT_NEW=1
# else
#   CT_NEW=0
# fi

#---- Introduction
source ${COMMON_PVE_SRC_DIR}/pvesource_ct_intro.sh

echo hello
#---- Set variables
source ${COMMON_PVE_SRC_DIR}/pvesource_set_allvmvars.sh

#---- Create OS CT
source ${COMMON_PVE_SRC_DIR}/pvesource_ct_createvm.sh

# #---- Create CT Bind Mounts
# source ${COMMON_PVE_SRC_DIR}/pvesource_ct_createbindmounts.sh

# #---- Configure New CT OS
# source ${COMMON_PVE_SRC_DIR}/pvesource_ct_ubuntubasics.sh



# #---- Create new CT
# if [ $CT_NEW == 0 ] && [ "$(pct_list | awk -F',' '{ print $1 }' | grep -w $CTID > /dev/null; echo $?)" != 0 ]; then
#   #---- Developer Options
#   FUNC_NAS_HOSTNAME=nas
#   if [ -f /mnt/pve/nas-*[0-9]-git/ahuacate/developer_settings.git ]; then
#     while IFS== read -r var val; do
#       eval ${var}=${val}
#     done < <(cat /mnt/pve/nas-*[0-9]-git/ahuacate/developer_settings.git | grep -v '^#')
#   fi
#   if [ $dev_git_mount = 0 ] && [ $DEV_GIT_MOUNT_ENABLE = 0 ]; then
#     pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-git" | awk '{print $1,"/mnt/pve/"$1}' >> pvesm_input_list
#   else
#     touch pvesm_input_list
#   fi

#   #---- Create OS CT
#   source ${COMMON_PVE_SOURCE}/pvesource_ct_createvm.sh

#   #---- Pre-Configuring PVE CT
#   section "Pre-Configure ${OSTYPE^} CT"

#   # Create CT Bind Mounts
#   source ${COMMON_PVE_SOURCE}/pvesource_ct_createbindmounts.sh

#   # Configure New CT OS
#   source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntubasics.sh

#   # Download and Install Prerequisites
#   pct exec $CTID -- apt-get install -y acl >/dev/null
#   pct exec $CTID -- apt-get install -y putty-tools >/dev/null

#   #---- Creating PVE NAS Users and Groups
#   section "Creating Users and Groups."

#   # Change Home folder permissions
#   msg "Setting default adduser home folder permissions (DIR_MODE)..."
#   pct exec $CTID -- sed -i "s/DIR_MODE=.*/DIR_MODE=0750/g" /etc/adduser.conf
#   info "Default adduser permissions set: ${WHITE}0750${NC}"
#   pct exec $CTID -- bash -c 'echo "HOME_MODE 0750" >> /etc/login.defs'

#   # Create users and groups
#   msg "Creating CT default user groups..."
#   # Create Groups
#   pct exec $CTID -- bash -c 'groupadd -g 65605 medialab > /dev/null'
#   info "Default user group created: ${YELLOW}medialab${NC}"
#   pct exec $CTID -- bash -c 'groupadd -g 65606 homelab > /dev/null'
#   info "Default user group created: ${YELLOW}homelab${NC}"
#   pct exec $CTID -- bash -c 'groupadd -g 65607 privatelab > /dev/null'
#   info "Default user group created: ${YELLOW}privatelab${NC}"
#   pct exec $CTID -- bash -c 'groupadd -g 65608 chrootjail > /dev/null'
#   info "Default user group created: ${YELLOW}chrootjail${NC}"
#   echo

#   # Create Base User Accounts
#   msg "Creating CT default users..."
#   pct exec $CTID -- bash -c 'useradd -u 1605 -g medialab -s /bin/bash media >/dev/null'
#   info "Default user created: ${YELLOW}media${NC} of group medialab"
#   pct exec $CTID -- bash -c 'useradd -u 1606 -g homelab -G medialab -s /bin/bash home >/dev/null'
#   info "Default user created: ${YELLOW}home${NC} of groups medialab, homelab"
#   pct exec $CTID -- bash -c 'useradd -u 1607 -g privatelab -G medialab,homelab -s /bin/bash private >/dev/null'
#   info "Default user created: ${YELLOW}private${NC} of groups medialab, homelab and privatelab"
#   echo

  # #---- Webmin
  # section "Installing Webmin."
  # # Install Webmin Prerequisites
  # msg "Installing Webmin prerequisites (be patient, might take a while)..."

  # pct exec $CTID -- bash -c "echo 'deb http://download.webmin.com/download/repository sarge contrib' | sudo tee -a /etc/apt/sources.list"
  # pct exec $CTID -- bash -c 'wget -qL http://www.webmin.com/jcameron-key.asc'
  # pct exec $CTID -- bash -c 'apt-key add jcameron-key.asc 2>/dev/null'
  # pct exec $CTID -- apt-get update
  # pct exec $CTID -- apt-get install -y webmin

  # #---- Finish Up
  # msg "Creating snapshot to local-zfs..."
  # vzdump 888 --dumpdir /var/lib/vz/dump/ --mode snapshot --compress zstd
# fi

#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

# msg "${HOSTNAME^} installation was a success. To manage your new Ubuntu CT use Webmin (a Linux web management tool). Webmin login credentials are user 'root' and password '${PASSWORD}'.\n\n  --  ${WHITE}https://$(echo "$CT_IP" | sed  's/\/.*//g'):10000/${NC}\n  --  ${WHITE}https://${CT_HOSTNAME}:10000/${NC}"

# Cleanup
# trap cleanup EXIT

# pct create 101 local:vztmpl/ubuntu-21.04-standard_21.04-1_amd64.tar.gz --hostname nas-01 \
# --memory 512 \
# --cpulimit 0 \
# --cpuunits 1024 \
# --cores 1 \
# --unprivileged 1 \
# --swap 512 \
# --ostype ubuntu \
# --onboot 1 \
# --timezone host \
# --password ahuacate \
# --arch amd64 \
# --rootfs local-zfs:5,acl=1 \
# --net0 name=eth0,bridge=vmbr0,firewall=1,ip=dhcp \
# --features fuse=0,keyctl=0,nesting=0 \
# --startup order=1,up=2,down=2