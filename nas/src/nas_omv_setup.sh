#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_omv_setup.sh
# Description:  Setup script for OMV NAS
#
# Usage:        SSH into OMV. Login as 'root'.
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Requires file: 'nas_basefolderlist' & 'nas_basefoldersubfolderlist'

# Check OMV version
majorversion=$(dpkg -l | grep -i "openmediavault -" | awk {'print $3'} | cut -d '.' -f1)
OMV_MIN='6'
if ! [[ $(dpkg -l | grep -w openmediavault) ]]; then
  echo "There are problems with this installation:

    --  Wrong Hardware. This setup script is for a OpenMediaVault (OMV).
  
  Bye..."
  sleep 2
  return
elif [[ $(dpkg -l | grep -w openmediavault) ]] && [ ! ${majorversion} -ge ${OMV_MIN} ] || [ ! $(id -u) == 0 ]; then
  echo "There are problems with this installation:

  $(if [ ! ${majorversion} -ge ${OMV_MIN} ]; then echo "  --  Wrong OMV OS version. This setup script is for a OMV Version ${DSM_MIN} or later. Try upgrading your OMV OS."; fi)
  $(if [ ! $(id -u) == 0 ]; then echo "  --  This script must be run under User 'root'."; fi)

  Fix the issues and try again. Bye..."
  return
fi

# Install chattr
if [ $(chattr --help &> /dev/null; echo $?) != 1 ]; then
 apt-get install e2fsprogs -y
fi

# Install nslookup
if [ $(dpkg -s dnsutils >/dev/null 2>&1; echo $?) != 0 ]; then
  apt-get install dnsutils -y
fi

#---- Static Variables -------------------------------------------------------------

# Regex checks
ip4_regex='^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
ip6_regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'
hostname_regex='^(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$'
domain_regex='^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$'
R_NUM='^[0-9]+$' # Check numerals only
pve_hostname_regex='^(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[0-9])$'

#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='OMV NAS'

# No. of reserved PVE node IPs
PVE_HOST_NODE_CNT='5'

# NFS string and settings
NFS_STRING='(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100)'
NFS_EXPORTS='/etc/exports'

# SMB settings
SMB_CONF='/etc/samba/smb.conf'

# Search domain (local domain)
unset searchdomain_LIST
searchdomain_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ ^\#.*$ ]] && continue
  searchdomain_LIST+=( "$line" )
done << EOF
# Example
# local:Special use domain for LAN. Supports mDNS, zero-config devices.
local:Special use domain for LAN. Supports mDNS (Recommended)
home.arpa:Special use domain for home networks (Recommended)
lan:Common domain name for small networks
localdomain:Common domain name for small networks
other:Input your own registered or made-up domain name
EOF

#---- Other Files ------------------------------------------------------------------

# # Copy source files
# sed -i 's/65605/medialab/g' ${COMMON_DIR}/nas/src/nas_basefolderlist # Edit GUID to Group name
# sed -i 's/65606/homelab/g' ${COMMON_DIR}/nas/src/nas_basefolderlist # Edit GUID to Group name
# sed -i 's/65607/privatelab/g' ${COMMON_DIR}/nas/src/nas_basefolderlist # Edit GUID to Group name
# sed -i 's/65608/chrootjail/g' ${COMMON_DIR}/nas/src/nas_basefolderlist # Edit GUID to Group name
# sed -i 's/65605/medialab/g' ${COMMON_DIR}/nas/src/nas_basefoldersubfolderlist # Edit GUID to Group name
# sed -i 's/65606/homelab/g' ${COMMON_DIR}/nas/src/nas_basefoldersubfolderlist # Edit GUID to Group name
# sed -i 's/65607/privatelab/g' ${COMMON_DIR}/nas/src/nas_basefoldersubfolderlist # Edit GUID to Group name
# sed -i 's/65608/chrootjail/g' ${COMMON_DIR}/nas/src/nas_basefoldersubfolderlist # Edit GUID to Group name

#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# #---- Run Bash Header
# source ${COMMON_PVE_SRC_DIR}/pvesource_bash_defaults.sh

#---- Prerequisites
section "Prerequisites"

# # Perform OMV update
# msg "Performing OS update..."
# apt-get update -y
# apt-get upgrade -y

# Edit UID_MIN and UID_MAX in /etc/login.defs
msg "Increasing UID to 70000..."
sed -i 's|^UID_MAX.*|UID_MAX                 70000|g' /etc/login.defs
sed -i 's|^GID_MAX.*|GID_MAX                 70000|g' /etc/login.defs

# # Install OMV-Extras
# msg "Installing OMV-Extras..."
# sudo wget -O - https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install | sudo bash


#---- Search Domain
# Check DNS Search domain setting compliance with Ahuacate default options
section "Validate OMV NAS Search Domain"
SEARCHDOMAIN=$(hostname -d)
display_msg="#### ABOUT SEARCH DOMAINS ####
A Search domain is also commonly known as the local domain. Search domain means the domain that will be automatically appended when you only use the hostname for a particular host or computer. Its used to resolve a devices hostname to its assigned IP address between computers. It is especially important in DHCP networks where hostnames are used for inter-machine communication (NFS, SMB and Applications like Sonarr, Radarr). Search Domain is NOT your DNS server IP address.

It is important all network devices are set with a identical Search Domain name. Most important are your routers, switches and DNS servers including PiHole. It's best to choose only top-level domain (spTLD) names for residential and small networks names because they cannot be resolved across the internet. Routers and DNS servers know, in theory, not to forward ARPA requests they do not understand onto the public internet. Choose one of our listed names for your whole LAN network Search Domain and you will not have any problems.

If you insist on using a made-up search domain name, then DNS requests may go unfulfilled by your router and forwarded onto global internet DNS root servers. This leaks information about your network such as device names.

Alternatively, you can use a registered domain name or subdomain if you know what you are doing.\n\nWe recommend you change your Search Domain setting '${SEARCHDOMAIN}' on all your network devices.

$(printf '%s\n' "${searchdomain_LIST[@]}" | grep -v 'other' | awk -F':' '{ print "  --  "$1 }')\n"
# Confirm Search Domain
msg "Checking NAS Search Domain name..."
if [[ $(printf '%s\n' "${searchdomain_LIST[@]}" | awk -F':' '{ print $1 }' | grep "^${SEARCHDOMAIN}$" >/dev/null 2>&1; echo $?) == '0' ]]; then
  info "NAS Search Domain is set: ${YELLOW}${SEARCHDOMAIN}${NC} ( unchanged )"
  echo
else
  warn "The NAS DNS Search Domain name '${SEARCHDOMAIN}' is non-standard."
  echo
  msg_box "$display_msg"
  echo
  while true; do
    read -p "Proceed with your NAS Search Domain '${SEARCHDOMAIN}' [y/n]?: " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        echo
        break
        ;;
      [Nn]*)
        msg "You have chosen not to proceed. Change your NAS DNS Search Domain using the NAS DNS Server application. Then re-run this script again. Exiting script..."
        echo
        return
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
fi


#---- OMV Hostname
if [[ ! "$(hostname)" =~ ^.*([0-9])$ ]]; then
  section "Query Hostname"

  msg "You may want to change your NAS hostname from '$(hostname)' to 'nas-01' ( i.e when adding additional NAS appliances use hostnames nas-02/03/04/05 ). Conforming to our standard network NAS naming convention assists our scripts in automatically detecting and resolving storage variables and other scripted tasks.\n\nThe system will now scan the network in ascending order the availability of our standard NAS hostname names beginning with: 'nas-01'. You may choose to accept our suggested new hostname or not."
  echo
  while true; do
    # Check for available hostname(s)
    i=1
    counter=1
    until [ $counter -eq 5 ]
    do
      if [ ! $(ping -s 1 -c 2 nas-0${i} &> /dev/null; echo $?) = 0 ]; then
        HOSTNAME_VAR=nas-0${i}
        msg "Checking hostname 'nas-0${i}'..."
        info "New hostname 'nas-0${i}' status: ${GREEN}available${NC}"
        echo
        break
      else
        msg "Checking hostname 'nas-0${i}' status: ${WHITE}in use${NC} ( not available )"
      fi
      ((i=i+1))
      ((counter++))
    done
    # Confirm new hostname
    while true; do
      read -p "Change NAS hostname to '${HOSTNAME_VAR}' [y/n]? " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          info "New hostname is set: ${YELLOW}${HOSTNAME_VAR}${NC}"
          HOSTNAME_MOD=0
          echo
          break 2
          ;;
        [Nn]*)
          info "No problem. NAS hostname is unchanged."
          HOSTNAME_VAR="$(hostname)"
          HOSTNAME_MOD=1
          echo
          break 2
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  done
else
  HOSTNAME_VAR="$(hostname)"
  HOSTNAME_MOD=1
fi

#---- Validating your network setup
# Identify PVE host IP
source ${COMMON_PVE_SRC_DIR}/pvesource_identify_pvehosts.sh


#---- Start Build ------------------------------------------------------------------

#---- Create default base and sub folders
source ${COMMON_DIR}/nas/src/nas_basefoldersetup.sh
# Create temporary files of lists
printf "%s\n" "${nas_subfolder_LIST[@]}" > nas_basefoldersubfolderlist
printf '%s\n' "${nas_basefolder_LIST[@]}" > nas_basefolderlist
printf '%s\n' "${nas_basefolder_extra_LIST[@]}" > nas_basefolderlist_extra


#---- Create Users and Groups
section "Creating Users and Groups"
source ${COMMON_DIR}/nas/src/nas_create_users.sh

# Modifying SSHd
cat <<EOF >> /etc/ssh/sshd_config
# Settings for privatelab
Match Group privatelab
        AuthorizedKeysFile ${DIR_SCHEMA}/homes/%u/.ssh/authorized_keys
        PubkeyAuthentication yes
        PasswordAuthentication no
        AllowTCPForwarding no
        X11Forwarding no
# Settings for medialab
Match Group medialab
        AuthorizedKeysFile ${DIR_SCHEMA}/homes/%u/.ssh/authorized_keys
        PubkeyAuthentication yes
        PasswordAuthentication no
        AllowTCPForwarding no
        X11Forwarding no
EOF


#---- Install and Configure Samba
source ${COMMON_DIR}/nas/src/nas_installsamba.sh


#---- Install and Configure NFS
source ${COMMON_DIR}/nas/src/nas_installnfs.sh

# Read /etc/exports
sudo exportfs -ra

#---- Set Hostname
if [ ${HOSTNAME_MOD} == 0 ]; then
  # Assign old hostnames
  HOSTNAME_OLD=$(hostname)

  # Change hostname
  sudo hostnamectl set-hostname ${HOSTNAME_VAR}

  # Change hostname in /etc/hosts & /etc/hostname
  sudo sed -i "s/${HOSTNAME_OLD}/${HOSTNAME_VAR}/g" /etc/hosts
fi

#---- Finish Line ------------------------------------------------------------------

section "Completion Status"

# Get port
port=80
# Interface
interface=$(ip route ls | grep default | grep -Po '(?<=dev )(\S+)')
# Get IP type
if [[ $(ip addr show ${interface} | grep -q dynamic > /dev/null; echo $?) == 0 ]]; then # ip -4 addr show eth0 
    ip_type='dhcp - best use dhcp IP reservation'
else
    ip_type='static IP'
fi

#---- Set display text
# Webmin access URL
display_msg1=( "http://$(hostname).$(hostname -d):${port}/" )
display_msg1+=( "http://$(hostname -I | sed -r 's/\s+//g'):${port}/ (${ip_type})" )
display_msg1+=( "Username: admin" )
display_msg1+=( "Password: openmediavault" )

# User Management
display_msg2=( "medialab - GUID 65605:For media Apps (Sonarr, Radar, Jellyfin etc)" )
display_msg2+=( "homelab - GUID 65606:For Smart Home (CCTV, Home Assistant)" )
display_msg2+=( "privatelab - GUID 65607:Power, trusted and admin Users" )
display_msg2+=( "chrootjail - GUID 65608:Users are restricted to their home folder" )
                                  
display_msg3=( "media - UID 1605:Member of medialab" )
display_msg3+=( "home - UID 1606:Member of homelab. Supplementary medialab" )
display_msg3+=( "private - UID 1607:Member of privatelab. Supplementary medialab, homelab" )

# File server login
x='\\\\'
display_msg4=( "$x$(hostname -I | sed -r 's/\s+//g')\:" )
display_msg4+=( "$x$(hostname).$(hostname -d)\:" )
printf '%s\n' "${display_msg3[@]}" 

# Display msg
msg_box "${HOSTNAME^^} OMV NAS installation was a success. The NAS is fully configured and is ready to provide NFS and/or SMB/CIFS backend storage mounts to your PVE hosts.

OMV NAS has a WebGUI management interface. Your login credentials are user 'admin' and password 'openmediavault'. You can change your login credentials using the WebGUI.

$(printf '%s\n' "${display_msg1[@]}" | indent2)

The NAS is installed with Ahuacate default User accounts, Groups and file sharing permission. These new Users and Groups are a required for all our PVE containers (Sonarr, Radarr etc). We recommend the User uses our preset NAS Groups for new user management.

$(printf '%s\n' "${display_msg2[@]}" | column -s ":" -t -N "GROUP NAME,DESCRIPTION" | indent2)

$(printf '%s\n' "${display_msg3[@]}" | column -s ":" -t -N "NEW USERS,DESCRIPTION" | indent2)

To access ${HOSTNAME^^} files use SMB.

$(printf '%s\n' "${display_msg4[@]}" | column -s ":" -t -N "SMB NETWORK ADDRESS" | indent2)

NFSv4 is enabled and ready for creating PVE host storage mounts.

We recommend the User now reboots the OMV NAS."
#-----------------------------------------------------------------------------------