#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_set_allvmvars.sh
# Description:  Source script for setting CT and VM variables
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Nmap
if [ ! $(dpkg -s nmap >/dev/null 2>&1; echo $?) == 0 ]; then
  apt-get install nmap -yqq
fi

# Ethtool
if [ ! $(dpkg -s ethtool >/dev/null 2>&1; echo $?) == 0 ]; then
  apt-get install ethtool -yqq
fi

#---- Static Variables -------------------------------------------------------------

# NAS generic name
FUNC_NAS_HOSTNAME='(nas|storage|fileserver)'

# Menu optional addon vars
PVESM_NONE='none:Ignore this share'
PVESM_EXIT='exit:Perform a full exit ( kill ) of the installer'

# Host reserved RAM (MiB)
MEMORY_HOST_RESERVE='2000'

# Network rate limit ( % of NIC maximum in MB/s)
unset net_ratelimit_LIST
net_ratelimit_LIST=( "100%" "75%" "50%" "25%" "10%" )

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

#---- Other Variables --------------------------------------------------------------

# Developer Options
if [ -f /mnt/pve/nas-*[0-9]-git/ahuacate/developer_settings.git ]; then
  while IFS== read -r var val; do
    eval ${var}=${val}
  done < <(cat /mnt/pve/nas-*[0-9]-git/ahuacate/developer_settings.git | grep -v '^#')
fi

#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

#---- Arrays
# PVESM required storage array
function pvesm_required_list() {
  unset pvesm_required_LIST
  mapfile -t pvesm_required_LIST < <( echo -e "${PVESM_REQUIRED_LIST}" | sed '/^$/d' )
}

# PCT list array
function pct_list() {
  fieldwidths=$(echo "$(pct list)" | head -n 1 | grep -Po '\S+\s*' | awk '{printf "%d ", length($0)}' | sed 's/^[ ]*//;s/[ ]*$//')
  unset pctLIST
  while read -r line; do
    pctLIST+=( "$(echo $line)" )
  done < <( pct list | awk 'BEGIN { FIELDWIDTHS="$fieldwidths"; OFS=":" } { if(NR>1) print $1, $NF, $2 }' )
}

# QM list array
function qm_list() {
  fieldwidths=$(echo "$(qm list)" | head -n 1 | grep -Po '\S+\s*' | awk '{printf "%d ", length($0)}' | sed 's/^[ ]*//;s/[ ]*$//')
  unset qmLIST
  while read -r line; do
    qmLIST+=( "$(echo $line)" )
  done < <( qm list | awk 'BEGIN { FIELDWIDTHS="$fieldwidths"; OFS=":" } { if(NR>1) print $1, $2, $3 }' )
}

#---- Validate functions

# Regex for functions
ip4_regex='^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
ip6_regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'
hostname_regex='^(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$'
domain_regex='^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$'
R_NUM='^[0-9]+$' # Check numerals only

# Check IP validity
function valid_ip() {
  local  ip=$1
  local  stat=1
  if [[ $ip =~ ${ip4_regex} ]]; then
    stat=$?
  elif [[ $ip =~ ${ip6_regex} ]]; then
    stat=$?
  fi
  return $stat
}

# Check IP availability status
function ip_free() {
  local  ip=$1
  local  stat=1
  # Set IP version
  if [[ $ip =~ ${ip4_regex} ]]; then
    var='4'
  elif [[ $ip =~ ${ip6_regex} ]]; then
    var='6'
  fi
  # Run function
  if [[ -f /etc/pve/lxc/* ]]; then
    if [[ ! $(grep -h -Po 'ip[0-9]?=\K[^/]*' /etc/pve/lxc/* 2> /dev/null) =~ $ip ]] && [ $(ping$var -s 1 -c 2 $ip > /dev/null; echo $?) != 0 ]; then
      stat=$?
    fi
  else
    if [ $(ping$var -s 1 -c 2 $ip > /dev/null; echo $?) != 0 ]; then
      stat=$?
    fi
  fi
  return $stat
}

# Check Gateway IPv4/6 validity
function valid_gw() {
  local  gw=$1
  local  vlan=$2
  local  stat=1
  # Set IP version
  if [[ $gw =~ ${ip4_regex} ]]; then
    ip_ver='4'
    reg_var=${ip4_regex}
  elif [[ $gw =~ ${ip6_regex} ]]; then
    ip_ver='6'
    reg_var=${ip6_regex}
  fi
  # Run function
  if [[ $gw =~ ${ip4_regex} ]] && [[ $(echo $gw | cut -d . -f 3) =~ ^(30|40)$ ]] && [[ ${TAG} =~ ^(30|40)$ ]]; then
    stat=$?
  elif [[ $gw =~ ${ip4_regex} ]] && [[ ! $(echo $gw | cut -d . -f 3) =~ ^(30|40)$ ]] && [ $(ping${ip_ver} -s 1 -c 2 $gw > /dev/null; echo $?) == 0 ]; then
    stat=$?
  elif [[ $gw =~ ${ip6_regex} ]] && [ $(ping${ip_ver} -s 1 -c 2 $gw > /dev/null; echo $?) == 0 ]; then
    stat=$?
  fi
  return $stat
}

# Check Hostname availability status
function valid_hostname() {
  local  name=$1
  local  stat=1
  # Run function
  if [[ $name =~ ${hostname_regex} ]] && [[ ! $name =~ ^(pve).*$ ]] && [[ ! $(grep -h -Po 'hostname: \K[^/]*' /etc/pve/lxc/* 2> /dev/null | grep "^${name}$") ]] && [[ ! $(grep -h -Po 'name: \K[^/]*' /etc/pve/qemu-server/* 2> /dev/null | grep "^${name}$") ]] && [[ ! $name == $(echo $(hostname) | awk '{ print tolower($0) }') ]] && [ ! $(ping -s 1 -c 2 ${name} > /dev/null; echo $?) == '0' ]; then
    stat=$?
  fi
  return $stat
}

# Check DNS status
function valid_dns() {
  local  ip=$1
  local  stat=1
  local  dnsURLS+=( "www.google.com" "www.ibm.com" "www.tecmint.com" "www.github.com" )
  # Set IP version
  if [[ $ip =~ ${ip4_regex} ]]; then
    ip_ver='4'
    reg_var=${ip4_regex}
  elif [[ $ip =~ ${ip6_regex} ]]; then
    ip_ver='6'
    reg_var=${ip6_regex}
  fi
  # Run function
  if [[ $ip =~ ${ip4_regex} ]] && [[ $(echo $ip | cut -d . -f 3) =~ ^(30|40)$ ]] && [[ ${TAG} =~ ^(30|40)$ ]]; then
    return 0
  elif [[ $ip =~ ${ip4_regex} ]] && [[ ! $(echo $ip | cut -d . -f 3) =~ ^(30|40)$ ]] && [ $(ping${ip_ver} -s 1 -c 2 $ip > /dev/null; echo $?) == 0 ]; then
    while read url; do
      if [ $(host -W 1 $url $ip > /dev/null 2>&1; echo $?) == 0 ]; then
        return 0
      fi
    done < <(printf '%s\n' "${dnsURLS[@]}")
    return $stat
  elif [[ $ip =~ ${ip6_regex} ]] && [ $(ping${ip_ver} -s 1 -c 2 $ip > /dev/null; echo $?) == 0 ]; then
    while read url; do
      if [ $(host -W 1 $url $ip > /dev/null 2>&1; echo $?) == 0 ]; then
        return 0
      fi
    done < <(printf '%s\n' "${dnsURLS[@]}")
    return $stat
  else
    return $stat
  fi
}

# Check for a Broadcast DHCP server
function valid_broadcastdhcp() {
  # Check if a DHCP server exists on the network
  # Cmd for DHCP4 'valid_broadcastdhcp' and for DHCP6 'valid_broadcastdhcp 6'
  local  i=$1
  local  stat=1
  # Run function
  result=$(nmap -${i} --script broadcast-dhcp-discover 2> /dev/null | grep -oP 'IP Offered: \K.*' > /dev/null 2>&1)
  if [ $? == 0 ]; then
    return 0
  else
    return $stat
  fi
}

# Check CTID/VMID
function valid_machineid() {
  local  id=$1
  local  stat=1
  # Run function
  result1=$(printf '%s\n' "${pctLIST[@]}" | grep -w "^${id}:*" > /dev/null 2>&1; echo $?)
  result2=$(printf '%s\n' "${qmLIST[@]}" | grep -w "^${id}:*" > /dev/null 2>&1; echo $?)
  result3=$([[ ${id} -le 100 ]] > /dev/null 2>&1; echo $?)
  if [ ! $result1 == 0 ] && [ ! $result2 == 0 ] && [ ! $result3 == 0 ]; then
    return 0
  else
    return $stat
  fi
}


#---- Other functions

# ES function on errors
function es_check_errors() {
	if [ $? -ne 0 ]; then
		info "$FAIL"
    echo
		return
	fi
}

# Maximum memory (RAM) MiB available for CT/VMs
function max_ram_allocation() {
  local totalram=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*' | awk -v mem_res="${MEMORY_HOST_RESERVE}" '{$1/=1024;printf "%.0f\n",$1-mem_res}')
  echo $totalram
}

# NIC Speed limit check - check limit is below maximum
function valid_netspeedlimit() {
  local  limit=$1
  local  stat=1
  # Run function
  iface=$(brctl show ${BRIDGE} | awk 'NF>1 && NR>1 {print $4}')
  iface_speed=$(ethtool ${iface} | grep -i -Po '^\s?\Speed:\s?\K[^/][0-9]+')
  if [ ${limit} -le "$(echo "${iface_speed}/8" | bc | awk '{print int($1+0.5)}')" ]; then
    return 0
  else
    return $stat
  fi
}

# Set CPU Core assignment ( Auto calculator )
function cpu_core_set() {
  local  cpu_limit=$1
  # Run function
  if [ ${cpu_limit} == 0 ]; then
    # No CPU socket limit
    CPU_CORE_CNT=$(( $(lscpu -b -p=Core,Socket | grep -v '^#' | sort -u | wc -l) / 2 ))
  elif [ ! ${cpu_limit} == 0 ]; then
    # Apply CPU socket limit
    CPU_CORE_CNT=$(( ${cpu_limit} * ($(lscpu | grep -oP '^Core.*:\s*\K.+') * $(lscpu | grep -oP '^Thread.*:\s*\K.+')) ))
  fi
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites
section "Installer Prerequisites"
# Set VM type ( CT or VM )
if [ ! -n "${VM_TYPE}" ]; then
  warn "Cannot proceed. No VM type set (CT or VM)."
  echo
  trap cleanup EXIT
fi

# Confirm VLAN support
if [ $(hostname -i | awk -F'.' '{ print $3 }') == '0' ] && [[ $(hostname -i) =~ $ip4_regex ]]; then
  msg_box "#### VLAN SUPPORT ####\n\nIt appears your LAN does not support VLANs. PVE host IPv4 address '$(hostname -i)' third octet is set at '0' which commonly indicates the LAN does not support VLANs."
fi
msg "Does your LAN network support VLANs ( L2/L3 switches )..."
unset OPTIONS_VALUES_INPUT
unset OPTIONS_LABELS_INPUT
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" )
OPTIONS_LABELS_INPUT=( "VLAN enabled - LAN supports VLAN L2/3" \
"VLAN disabled - LAN does NOT support VLANs ( basic home LAN )" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"
echo
# Set VLAN support
if [ ${RESULTS} == 'TYPE02' ]; then
  # Set VLAN to disable/off
  if [ ! ${TAG} == '0' ]; then
    TAG='0'
  fi
  VLAN_STATUS='0'
fi


# Confirm search domain (local domain name)
if [[ $(printf '%s\n' "${searchdomain_LIST[@]}" | awk -F':' '{ print $1 }' | grep "^$(hostname -d)$" >/dev/null 2>&1; echo $?) == '0' ]]; then
  # Set search domain to use host settings
  SEARCHDOMAIN=''
else
  msg_box "#### SEARCH DOMAIN SERVER - Local Domain Name ####\n\nThe User must set a 'search domain' or 'local domain' name.
  The search name the User selects or inputs must match the setting used in your router configuration setting labelled as 'Local Domain' or 'Search Domain' depending on the device manufacturer. We recommend you change search domain setting '$(hostname -d)' on your router and all devices to avoid potential problems. Search domain or local domain is NOT your DNS server IP address.
  We recommend only top-level domain (spTLD) names for residential and small networks names because they cannot be resolved across the internet. Routers and DNS servers know, in theory, not to forward ARPA requests they do not understand onto the public internet. It is best to choose one of our listed names.\n\n$(printf '%s\n' "${searchdomain_LIST[@]}" | column -s ":" -t -N "LOCAL DOMAIN NAME,DESCRIPTION" | indent2)\n\nIf you insist on using a made-up search domain name, then DNS requests may go unfulfilled by your router and forwarded onto global internet DNS root servers. This leaks information about your network such as device names. Alternatively, you can use a registered domain name or subdomain if you know what you are doing by selecting the 'Other' option."
  unset OPTIONS_VALUES_INPUT
  unset OPTIONS_LABELS_INPUT
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${searchdomain_LIST[@]}" | awk -F':' '{ print $1 }')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${searchdomain_LIST[@]}" | awk -F':' '{ print $1 "  --  " $2 }')
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"
  # Set Searchdomain
  FAIL_MSG="The search domain name is not valid. A valid search domain name is when all of the following constraints are satisfied:\n
    Valid Registered Domain Name
    --  its construct meets the domain naming convention.
    --  it contains only lowercase characters.
    --  it doesn't contain any white space.
    Custom User Made-up Name
    --  it does not exist on the network.
    --  it contains only lowercase characters.
    --  it may include numerics, hyphens (-) and periods (.) but not start or end with them.
    --  it doesn't contain any other special characters [!#$&%*+_].
    --  it doesn't contain any white space.
    --  a name that begins with 'pve' is not allowed.\n
    Try again..."

  if [ ! ${RESULTS} == 'other' ]; then
    SEARCHDOMAIN=${RESULTS}
  elif [ ${RESULTS} == 'other' ]; then
    while true; do
      read -p "Input a search domain name ( registered or made-up ): " -e SEARCHDOMAIN
      if [[ ${SEARCHDOMAIN} =~ ${domain_regex} ]] || [[ ${SEARCHDOMAIN} =~ ${hostname_regex} ]]; then
        echo
        break
      else
        warn "$FAIL_MSG"
      fi
    done
  fi
fi


# Query and match or map network variables to PVE host IP format
if [[ "$(hostname -i)" =~ ${ip4_regex} ]] && [[ ${NET_DHCP} == '0' || ${VLAN_STATUS} == '0' ]]; then
  # Copy preset variable
  preset_IP=$IP
  preset_IP6=$IP6
  preset_GW=$GW
  preset_GW6=$GW6
  preset_NAMESERVER=$NAMESERVER

  # Create & display list of variable changes
  unset ipVARS
  unset displayVARS
  ipVARS+=( 'IP' 'GW' 'NAMESERVER' )
  i=1
  while IFS= read j
  do
    eval k='$'$j
    # Set VLAN octet
    if [ ${TAG} == '0' ]; then
      octet3=$(hostname -i | awk -F'.' '{ print $3 }')
      nameserver_octet4=$(cat /etc/resolv.conf | grep -i '^nameserver' | head -n1 | cut -d ' ' -f2 | awk -F'.' '{ print $4 }')
      gw_octet4=$(ip route show default | awk '/default/ {print $3}' | awk -F'.' '{ print $4 }')
    elif [ ! ${TAG} == '0' ]; then
      octet3=$(echo "${k}" | awk -F'.' '{ print $3 }')
      nameserver_octet4=$(cat /etc/resolv.conf | grep -i '^nameserver' | head -n1 | cut -d ' ' -f2 | awk -F'.' '{ print $4 }')
      gw_octet4=$(ip route show default | awk '/default/ {print $3}' | awk -F'.' '{ print $4 }')
    fi
    # Edit variable
    if [ -n "${k}" ]; then
      if [[ ${IP} =~ $k ]] && [ 'IP' == $j ]; then
        type="${VM_TYPE^^} IPv4 address"
        displayVARS+=( "$type:$k:$(hostname -i | awk -F'.' -v octet3="${octet3}" -v octet4="$(echo $k | awk -F'.' '{ print $4 }')" 'BEGIN {OFS=FS} { print $1, $2, octet3, octet4 }')" )
        IP=$(hostname -i | awk -F'.' -v octet3="${octet3}" -v octet4="$(echo $k | awk -F'.' '{ print $4 }')" 'BEGIN {OFS=FS} { print $1, $2, octet3, octet4 }')
      elif [[ ${GW} =~ $k ]] && [ 'GW' == $j ]; then
        type="${VM_TYPE^^} Gateway address"
        displayVARS+=( "$type:$k:$(hostname -i | awk -F'.' -v octet3="${octet3}" -v octet4="$(echo $k | awk -F'.' '{ print $4 }')" 'BEGIN {OFS=FS} { print $1, $2, octet3, octet4 }')" )
        GW=$(hostname -i | awk -F'.' -v octet3="${octet3}" -v octet4="${gw_octet4}" 'BEGIN {OFS=FS} { print $1, $2, octet3, octet4 }')
      elif [[ ${NAMESERVER} =~ $k ]] && [ 'NAMESERVER' == $j ]; then
        type="${VM_TYPE^^} DNS address"
        displayVARS+=( "$type:$k:$(hostname -i | awk -F'.' -v octet3="${octet3}" -v octet4="$(echo $k | awk -F'.' '{ print $4 }')" 'BEGIN {OFS=FS} { print $1, $2, octet3, octet4 }')" )
        NAMESERVER=$(hostname -i | awk -F'.' -v octet3="${octet3}" -v octet4="${nameserver_octet4}" 'BEGIN {OFS=FS} { print $1, $2, octet3, octet4 }')
      fi
    fi
  done <<< $(printf '%s\n' "${ipVARS[@]}")

  # Display msg for static IP only
  if [ ${NET_DHCP} == '0' ]; then
    msg_box "#### MODIFYING EASY SCRIPT IPv4 PRESETS ####\n\nOur Easy Scripts (ES) settings for your IPv4 ${VM_TYPE^^} addresses have been modified where required to match your PVE hosts IPv4 range, nameserver and gateway addresses and VLAN status ( $(if [ ${TAG} == '0' ]; then echo "disabled"; else echo "enabled"; fi) ).\n\n$(printf '%s\n' "${displayVARS[@]}" | column -s ":" -t -N "IP DESCRIPTION,DEFAULT ES PRESET,NEW ES PRESET" | indent2)\n\nThe new ES presets will be checked and validated in the next steps."
    echo
  fi
elif [ ${NET_DHCP} == '1' ]; then
  if [[ $(hostname -i) =~ ${ip4_regex} ]]; then
    # Nameserver - match to PVE host IP format & VLAN ( for IPv4 only )
    if [ ! ${TAG} == '0' ]; then
      nameserver_octet3=$TAG
      nameserver_octet4=$(ip route show default | awk '/default/ {print $3}' | awk -F'.' '{ print $4 }')
      NAMESERVER=$(hostname -i | awk -F'.' -v octet3="${nameserver_octet3}" -v octet4="${nameserver_octet4}" 'BEGIN {OFS=FS} { print $1, $2, octet3, octet4 }')
    fi
    # Copy preset variable
    preset_IP=$IP
    preset_IP6=$IP6
    preset_GW=$GW
    preset_GW6=$GW6
    preset_NAMESERVER=$NAMESERVER
    # Null/void any IP conflict settings when dhcp is enabled
    IP='dhcp'
    IP6=''
    GW=''
    GW6=''
    # Set Nameserver
    if [ ! ${TAG} == '0' ]; then
      NAMESERVER=$NAMESERVER
    else
      NAMESERVER=''
    fi
    NET_DHCP_TYPE='dhcp4'
  elif [[ $(hostname -i) =~ ${ip6_regex} ]]; then
    # Copy preset variable
    preset_IP=$IP
    preset_IP6=$IP6
    preset_GW=$GW
    preset_GW6=$GW6
    preset_NAMESERVER=$NAMESERVER
    # Null/void any IP conflict settings when dhcp is enabled
    IP=''
    IP6='dhcp'
    GW=''
    GW6=''
    NAMESERVER=''
    NET_DHCP_TYPE='dhcp6'
  fi
fi

# Auto set CPU Core Cnt
cpu_core_set "${CPULIMIT}"
if [ ${VM_TYPE} == 'ct' ]; then
  CORES=${CPU_CORE_CNT}
fi

#---- Easy Script automatic VAR validation
section "Easy Script Validation"

# Performing ES validation of all variables
FAIL_MSG="Cannot perform a 'Easy Script' installation.\nProceeding to User input based installation."
while true; do
  msg "Performing 'Easy Script' installation..."

  # Hostname validation
  result=$(valid_hostname ${HOSTNAME} > /dev/null 2>&1)
  if [ $? -ne 0 ]; then
		info "$FAIL_MSG"
    echo
		break
	fi

  # Validate IP static/dhcp IP
  if [ ${NET_DHCP} == '0' ]; then
    # IP validation
    if [ -n "${IP}" ]; then
      result=$(valid_ip ${IP} > /dev/null 2>&1)
      if [ $? -ne 0 ]; then
        info "$FAIL_MSG"
        echo
        break
      fi
      # Unset Ipv6 vars
      unset IP6
      unset GW6
    elif [ -n "${IP6}" ]; then
      result=$(valid_ip ${IP} > /dev/null 2>&1)
      if [ $? -ne 0 ]; then
        info "$FAIL_MSG"
        echo
        break
      fi
      # Unset Ipv4 vars
      unset IP
      unset GW
    fi

    # IP free validation
    if [ -n "${IP}" ]; then
      result=$(ip_free ${IP} > /dev/null 2>&1)
      if [ $? -ne 0 ]; then
        info "$FAIL_MSG"
        echo
        break
      fi
    elif [ -n "${IP6}" ]; then
      result=$(ip_free ${IP} > /dev/null 2>&1)
      if [ $? -ne 0 ]; then
        info "$FAIL_MSG"
        echo
        break
      fi
    fi

    # GW validation
    if [ -n "${GW}" ]; then
      result=$(valid_gw ${GW} > /dev/null 2>&1)
      if [ $? -ne 0 ]; then
        info "$FAIL_MSG"
        echo
        break
      fi
    elif [ -n "${GW6}" ]; then
      result=$(valid_gw ${GW6} > /dev/null 2>&1)
      if [ $? -ne 0 ]; then
        info "$FAIL_MSG"
        echo
        break
      fi
    fi

    # DNS validation
    if [ -n "${NAMESERVER}" ]; then
      result=$(valid_dns ${NAMESERVER} > /dev/null 2>&1)
      if [ $? -ne 0 ]; then
        info "$FAIL_MSG"
        echo
        break
      fi
    fi

    # Check CTID/VMID
    if [ ${VM_TYPE} == 'ct' ]; then
      ID_NUM=${CTID}
    elif [ ${VM_TYPE} == 'vm' ]; then
      ID_NUM=${VMID}
    fi
    result=$(valid_machineid ${ID_NUM} > /dev/null 2>&1)
    if [ $? -ne 0 ]; then
      info "$FAIL_MSG"
      echo
      break
    fi

  elif [ ${NET_DHCP} == '1' ]; then
    # DHCP validation
    if [ ${NET_DHCP_TYPE} == 'dhcp4' ]; then
      result=$(valid_broadcastdhcp > /dev/null 2>&1)
      if [ $? -ne 0 ]; then
        info "$FAIL_MSG"
        echo
        break
      fi
    elif [ ${NET_DHCP_TYPE} == 'dhcp6' ]; then
      result=$(valid_broadcastdhcp 6 > /dev/null 2>&1)
      if [ $? -ne 0 ]; then
        info "$FAIL_MSG"
        echo
        break
      fi
    fi

    # Set CTID/VMID
    if [ ${VM_TYPE} == 'ct' ]; then
      CTID=$(pvesh get /cluster/nextid)
    elif [ ${VM_TYPE} == 'vm' ]; then
      VMID=$(pvesh get /cluster/nextid)
    fi
  fi

  # Rate validation
  if [ -n "${RATE}" ]; then
    result=$(valid_netspeedlimit ${RATE} > /dev/null 2>&1)
    if [ $? -ne 0 ]; then
      info "$FAIL_MSG"
      echo
      break
    fi
  fi

  # PVESM Storage validation
  unset pvesm_input_LIST
  pvesm_input_LIST=()
  pvesm_check_LIST=()
  if [ ${#pvesm_required_LIST[@]} -ge '1' ]; then
    while read -r line; do
      if [[ $(pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-$line") ]]; then
        pvesm_input_LIST+=( "$(pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-$line" | awk '{print $1}' | sed "s/$/,\/mnt\/$line/")" )
      else
        unset pvesm_input_LIST
        info "$FAIL_MSG"
        echo
        break 2 > /dev/null 2>&1
      fi 
    done <<< $(printf '%s\n' "${pvesm_required_LIST[@]}" | awk -F':' '{ print $1 }' | grep -v 'none')
  fi
  # Add developer git mount
  if [ ${DEV_GIT_MOUNT_ENABLE} == '0' ] && [[ $(pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-git") ]]; then
    pvesm_input_LIST+=( "$(pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-git" | awk 'BEGIN {OFS = ","}{print $1,"/mnt/pve/"$1}')" )
  fi

  # Confirm ES settings
  msg "Easy Script has done its best to confirm all default variable settings are valid (Recommended). The settings for '${HOSTNAME^}' ${VM_TYPE^^} are:"

  # Set ES display variables
  unset displayVARS
  # Display vm type
  if [ ${VM_TYPE} == 'ct' ]; then
    displayVARS+=( 'CTID' )
  elif [ ${VM_TYPE} == 'vm' ]; then
    displayVARS+=( 'VMID' )
  fi
  # Description
  if [ -n "${DESCRIPTION}" ]; then
    displayVARS+=( 'DESCRIPTION' )
  fi
  # Display IP type
  if [ ${NET_DHCP} == '0' ]; then
    if [ -n "${IP}" ] && [ -n "${GW}" ]; then
      displayVARS+=( 'HOSTNAME' 'IP' 'GW' )
    elif [ -n "${IP6}" ] && [ -n "${GW6}" ]; then
      displayVARS+=( 'HOSTNAME' 'IP6' 'GW6' )
    fi
  elif [ ${NET_DHCP} == '1' ] && [ ${NET_DHCP_TYPE} == 'dhcp4' ]; then
    displayVARS+=( 'HOSTNAME' 'IP' )
  elif [ ${NET_DHCP} == '1' ] && [ ${NET_DHCP_TYPE} == 'dhcp6' ]; then
    displayVARS+=( 'HOSTNAME' 'IP6' )
  fi
  # Display Nameserver
  if [ -n "${NAMESERVER}" ]; then
    displayVARS+=( 'NAMESERVER' )
  fi
  # Display Search Domain
  if [ -n "${SEARCHDOMAIN}" ]; then
    displayVARS+=( 'SEARCHDOMAIN' )
  fi
  # Display VLAN
  if [ -n "${TAG}" ] && [[ ! ${TAG} =~ ^(0|1)$ ]]; then
    displayVARS+=( 'TAG' )
  fi
  # Display net speed limit
  if [ -n "${RATE}" ]; then
    displayVARS+=( 'RATE' )
  fi

  # Print list of ES variables
  i=1
  while IFS= read j
  do
    eval k='$'$j
    if [ 'HOSTNAME' == $j ]; then
      msg "\t$i. Hostname : ${YELLOW}${HOSTNAME}${NC}"
      (( i=i+1 ))
    elif [ 'DESCRIPTION' == $j ]; then
      msg "\t$i. Description : ${YELLOW}${DESCRIPTION}${NC}"
      (( i=i+1 ))
    elif [ 'CTID' == $j ]; then
      msg "\t$i. CTID : ${YELLOW}${CTID}${NC}"
      (( i=i+1 ))
    elif [ 'VMID' == $j ]; then
      msg "\t$i. VMID : ${YELLOW}${VMID}${NC}"
      (( i=i+1 ))
    elif [ 'IP' == $j ]; then
      msg "\t$i. IPv4 address : ${YELLOW}${IP}${NC}"
      (( i=i+1 ))
    elif [ 'GW' == $j ]; then
      msg "\t$i. Gateway IPv4 address : ${YELLOW}${GW}${NC}"
      (( i=i+1 ))
    elif [ 'IP6' == $j ]; then
      msg "\t$i. IPv6 address : ${YELLOW}${IP6}${NC}"
      (( i=i+1 ))
    elif [ 'GW6' == $j ]; then
      msg "\t$i. Gateway IPv6 address : ${YELLOW}${GW6}${NC}"
      (( i=i+1 ))
    elif [ 'NAMESERVER' == $j ]; then
      msg "\t$i. Name server : ${YELLOW}${NAMESERVER}${NC} ( user best check )"
      (( i=i+1 ))
    elif [ 'SEARCHDOMAIN' == $j ]; then
      msg "\t$i. Search domain ( local domain ) : ${YELLOW}${SEARCHDOMAIN}${NC}"
      (( i=i+1 ))
    elif [ 'TAG' == $j ]; then
      msg "\t$i. VLAN : ${YELLOW}${TAG}${NC}"
      (( i=i+1 ))
    elif [ 'RATE' == $j ]; then
      msg "\t$i. Speed Limit : ${YELLOW}${RATE}${NC}"
      (( i=i+1 ))
    fi
  done <<< $(printf '%s\n' "${displayVARS[@]}")
  # Print list of bind mounts
  if [ ${#pvesm_input_LIST[@]} -ge '1' ]; then
    while IFS=, read -r var1 var2; do
      msg "\t$i. Bind mount: ${var1} ${WHITE}--->${NC} ${var2}"
      (( i=i+1 ))
    done <<< $(printf '%s\n' "${pvesm_input_LIST[@]}")
  fi
  echo

  while true; do
    read -p "Proceed with our Easy Script defaults (Recommended) [y/n]?: " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        if [ ! ${SSH_ENABLE} = 0 ]; then
          SSH_PORT=''
        fi
        info "'${HOSTNAME^}' ${VM_TYPE^^} build is set to use Easy Script defaults."
        echo
        return
        ;;
      [Nn]*)
        info "Proceeding with manual installation."
        echo
        # Reset preset variable
        IP=$preset_IP
        IP6=$preset_IP6
        GW=$preset_GW
        GW6=$preset_GW6
        NAMESERVER=$preset_NAMESERVER
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
  break
done


#---- Non ES Auto VAR Setting ------------------------------------------------------
section "Manual variable setting"

#---- Set Hostname
msg "Setting hostname..."
while true; do
  read -p "Enter a Hostname: " -e -i ${HOSTNAME} HOSTNAME
  FAIL_MSG="The hostname is not valid. A valid hostname is when all of the following constraints are satisfied:\n
  --  it does not exist on the network.
  --  it contains only lowercase characters.
  --  it may include numerics, hyphens (-) and periods (.) but not start or end with them.
  --  it doesn't contain any other special characters [!#$&%*+_].
  --  it doesn't contain any white space.
  --  a name that begins with 'pve' is not allowed.\n
  Try again..."
  PASS_MSG="Hostname is set: ${YELLOW}${HOSTNAME}${NC}"
  result=$(valid_hostname ${HOSTNAME} > /dev/null 2>&1)
  if [ $? == 0 ]; then
		info "$PASS_MSG"
    # HOSTNAME=${HOSTNAME}
    echo
    break
  elif [ $? != 0 ]; then
		warn "$FAIL_MSG"
    echo
	fi
done

#---- Select a network bridge
unset vmbr_LIST
vmbr_LIST=($(grep -E '^\s?\iface vmbr[0-9].*' /etc/network/interfaces | grep -oP 'vmbr[0-9]'))
if [ -n "${BRIDGE}" ]; then
  BRIDGE='vmbr0'
fi
if [ "${#vmbr_LIST[@]}" -gt '1' ]; then
  msg "Select a PVE virtual network bridge interface ( default is vmbr0 )..."
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${vmbr_LIST[@]}")
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${vmbr_LIST[@]}")
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  BRIDGE=${RESULTS}
fi

#---- Apply rate limiting to interface (MB/s). Value '' for unlimited.
iface=$(brctl show ${BRIDGE} | awk 'NF>1 && NR>1 {print $4}')
iface_speed=$(ethtool ${iface} | grep -i -Po '^\s?\Speed:\s?\K[^/][0-9]+')
msg "Apply a network speed limit to ${VM_TYPE^^} interface ( ${BRIDGE,,} )..."
unset OPTIONS_VALUES_INPUT
unset OPTIONS_LABELS_INPUT
while IFS= read -r var; do
  if [ ! ${var} == '100%' ]; then
    j=$(( (${iface_speed} / 8) * $(echo $var | sed 's/%$//')/100 ))
    k=$(( ${iface_speed} * $(echo $var | sed 's/%$//')/100 ))
    OPTIONS_VALUES_INPUT+=( "$(echo $j)" )
    OPTIONS_LABELS_INPUT+=( "$(echo "$j MB/s - Speed limited to $k Mbps")" )
  elif [ ${var} == '100%' ]; then
    OPTIONS_VALUES_INPUT+=( "0" )
    OPTIONS_LABELS_INPUT+=( "$(echo "No rate limit - Full speed $iface_speed Mbps")" )
  fi
done <<< $(printf '%s\n' "${net_ratelimit_LIST[@]}")
makeselect_input2 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
singleselect SELECTED "$OPTIONS_STRING"
# Set speed limit
if [ ${RESULTS} == '0' ]; then
  RATE=''
elif [ ! ${RESULTS} == '0' ]; then
  RATE=${RESULTS}
fi

#---- Set IP Method
msg "Select static IP or DHCP address assignment..."
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" )
OPTIONS_LABELS_INPUT=( "DHCP - Use DHCP IPv4 format address assignment" \
"DHCP6 - Use DHCP IPv6 format address assignment" \
"Static - Create a IPv4 or IPv6 static address" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"
# Set IP method type
if [ ${RESULTS} == 'TYPE01' ]; then
  NET_DHCP='1'
  NET_DHCP_TYPE='dhcp'
  IP='dhcp'
  GW=''
  IP6=''
  GW6=''
  NAMESERVER=''
elif [ ${RESULTS} == 'TYPE02' ]; then
  NET_DHCP='1'
  NET_DHCP_TYPE='dhcp6'
  IP6='dhcp'
  GW6=''
  IP=''
  GW=''
  NAMESERVER=''
elif [ ${RESULTS} == 'TYPE03' ]; then
  NET_DHCP='0'
  NET_DHCP_TYPE='0'
fi


#---- Set VLAN
if [ ! ${TAG} == '0' ]; then
  msg "Setting VLAN ID for network..."
  while true; do
    read -p "Enter a VLAN ID ( numeric [2-254] or '0' for no vlan ): " -e -i ${TAG} VLAN
    if [ ${VLAN} == 0 ]; then
      TAG=${VLAN}
      info "VLAN status : ${YELLOW}${VLAN}${NC} - disabled"
      echo
      break
    elif [[ ${VLAN} =~ ^([2-9][0-9]?|254)$ ]]; then
      TAG=${VLAN}
      info "VLAN status : ${YELLOW}${VLAN}${NC} - enabled"
      echo
      break
    else
      warn "A VLAN ID is a numeric number between '2' to '254' which matches the virtual machines IPv4 third octet. '1' is a reserved IPv4 third octet value which defines VLAN off. Try again..."
      echo
    fi
  done
fi


#---- Set Static IP Address
if [ ${NET_DHCP} == '0' ]; then
  msg "Setting '${HOSTNAME^} IPv4 or IPv6 address..."
  if [ -n "${IP}" ] && [ ! -n "${IP6}" ]; then
    IP_VAR=${IP}
  elif [ ! -n "${IP}" ] && [ -n "${IP6}" ]; then
    IP_VAR=${IP6}
  elif [ -n "${IP}" ] && [ -n "${IP6}" ]; then
    IP_VAR=${IP}
  fi
  while true; do
    read -p "Enter a IP address ( IPv4 or IPv6 ): " -e -i ${IP_VAR} IP_VAR
    if [[ ${IP_VAR} =~ ${ip4_regex} ]] && [ ${TAG} == 0 ] && [ ! $(echo "${IP_VAR}" | awk -F'.' '{print $3}') == 1 ]; then
      warn "The IPv4 address '${IP_VAR}' is set for VLAN $(echo "${IP_VAR}" | awk -F'.' '{print $3}'). Network VLAN is currently set as disabled. Try again..."
      echo
      break
    elif [[ ${IP_VAR} =~ ${ip4_regex} ]] && [ ! ${TAG} == 0 ] && [[ ! $(echo "${IP_VAR}" | awk -F'.' '{print $3}') == ${TAG} ]]; then
      warn "The IPv4 address '${IP_VAR}' third octet '$(echo "${IP_VAR}" | awk -F'.' '{print $3}')' does not match your VLAN ID ${TAG}. This installer script always sets the third IPv4 octet to match the VLAN number. Try again..."
      echo
      break
    fi
    # Validate IP
    FAIL_MSG="The IP address is not valid. A valid IP address is when all of the following constraints are satisfied:\n
    --  it does not exist on the network.
    --  it meets the IPv4 or IPv6 standard.
    --  it is not assigned to any other PVE CT or VM.
    --  it doesn't contain any white space.\n
    Try again..."
    PASS_MSG="IP address is set: ${YELLOW}${IP_VAR}${NC}\nVLAN is set: ${YELLOW}${TAG}${NC}$(if [ ${TAG} == 0 ]; then echo " - disabled"; else echo " - enabled"; fi)"
    result=$(valid_ip ${IP_VAR} > /dev/null 2>&1)
    check1=$?
    result=$(ip_free ${IP_VAR} > /dev/null 2>&1)
    check2=$?
    if [ $check1 == $check2 ]; then
      info "$PASS_MSG"
      if [[ ${IP_VAR} =~ ${ip4_regex} ]]; then
        IP=${IP_VAR}
        IP6=''
      elif [[ ${IP_VAR} =~ ${ip6_regex} ]]; then
        IP6=${IP_VAR}
        IP=''
      fi
      echo
      break
    elif [ $check1 != $check2 ]; then
      warn "$FAIL_MSG"
      # break
      echo
    fi
  done

  #---- Set Gateway IP Address
  msg "Setting '${HOSTNAME^}' Gateway IP address..."
  if [ -n "${GW}" ] && [ ! -n "${GW6}" ]; then
    GW_VAR=${GW}
  elif [ ! -n "${GW}" ] && [ -n "${GW6}" ]; then
    GW_VAR=${GW6}
  elif [ -n "${GW}" ] && [ -n "${GW6}" ]; then
    GW_VAR=${GW}
  fi
  while true; do
    read -p "Enter a Gateway IP address: " -e -i ${GW_VAR} GW_VAR
    FAIL_MSG="The Gateway address is not valid. A valid Gateway IP address is when all of the following constraints are satisfied:\n
    --  it does exist on the network ( passes ping test ).
    --  it meets the IPv4 or IPv6 standard.\n
    Try again..."
    PASS_MSG="Gateway IP is set: ${YELLOW}${GW_VAR}${NC}"
    result=$(valid_gw ${GW_VAR} > /dev/null 2>&1)
    if [ $? == 0 ]; then
      info "$PASS_MSG"
      if [[ ${GW_VAR} =~ ${ip4_regex} ]]; then
        GW=${GW_VAR}
        GW6=''
      elif [[ ${GW_VAR} =~ ${ip6_regex} ]]; then
        GW6=${GW_VAR}
        GW=''
      fi
      echo
      break
    elif [ $? != 0 ]; then
      warn "$FAIL_MSG"
      echo
    fi
  done
fi


#---- Set Nameserver IP Address ( DNS )
if [ ! ${TAG} == '0' ] && [[ "${NET_DHCP_TYPE}" =~ ^(0|dhcp)$ ]] || [[ ${IP} =~ ${ip4_regex} ]] && [ $(ip route show default | awk '/default/ {print $3}' | awk -F'.' '{ print $3 }') != ${TAG} ]; then
  # Nameserver - match to PVE host IP format ( for IPv4 only )
  nameserver_octet3=$TAG
  nameserver_octet4=$(ip route show default | awk '/default/ {print $3}' | awk -F'.' '{ print $4 }')
  NAMESERVER_VAR=$(hostname -i | awk -F'.' -v octet3="${nameserver_octet3}" -v octet4="${nameserver_octet4}" 'BEGIN {OFS=FS} { print $1, $2, octet3, octet4 }')
  # Set nameserver
  msg "Setting '${HOSTNAME^}' Nameserver IP address..."
  while true; do
    read -p "Enter a Nameserver IP address for vlan${TAG}: " -e -i ${NAMESERVER_VAR} NAMESERVER
    FAIL_MSG="The Nameserver address 'appears' to be not valid. A valid Nameserver IP address is when all of the following constraints are satisfied:\n
    --  the Nameserver server IP exists on the network ( passes ping test ).
    --  it meets the IPv4 or IPv6 standard.
    --  can resolve host command tests of public URLs ( ibm.com, github.com ).\n
    This fail warning may be false flag. Because the Nameserver IP address is on a VLAN different to the host LAN network security maybe blocking access to '${NAMESERVER}' vlan.\n
    Manually accept or try again..."
    PASS_MSG="Nameserver IP server is set: ${YELLOW}${NAMESERVER}${NC}"
    result=$(valid_dns ${NAMESERVER} > /dev/null 2>&1)
    if [ $? == 0 ]; then
      info "$PASS_MSG"
      echo
      break
    elif [ $? != 0 ]; then
      warn "$FAIL_MSG"
      # Manually validate the entry
      while true; do
        read -p "Accept Nameserver IP '${NAMESERVER}' as correct [y/n]?: " -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            info "$PASS_MSG"
            echo
            break 2
            ;;
          [Nn]*)
            msg "Try again..."
            echo
            break
            ;;
          *)
            warn "Error! Entry must be 'y' or 'n'. Try again..."
            echo
            ;;
        esac
      done

      echo
    fi
  done
elif [ ! ${TAG} == '0' ] && [[ "${NET_DHCP_TYPE}" =~ ^(0|dhcp)$ ]] || [[ ${IP} =~ ${ip4_regex} ]] && [ $(ip route show default | awk '/default/ {print $3}' | awk -F'.' '{ print $3 }') == ${TAG}]; then
  # Set nameserver to match host (same vlan)
  NAMESERVER=$(ip route show default | awk '/default/ {print $3}')
elif [ ! ${TAG} == '0' ] && [[ "${NET_DHCP_TYPE}" =~ ^(0|dhcp6)$ ]] || [[ ${IP6} =~ ${ip6_regex} ]]; then
  # IPv6 Nameserver set to host
  NAMESERVER=''
elif [ ${TAG} == '0' ]; then
  # Nameserver set to host
  NAMESERVER=''
fi


#---- Set CTID/VMID
if [ ${VM_TYPE} == 'ct' ]; then
  ID_NUM_TMP=${CTID}
  ID_NUM_TYPE=CTID
elif [ ${VM_TYPE} == 'vm' ]; then
  ID_NUM_TMP=${VMID}
  ID_NUM_TYPE=VMID
fi
msg "Setting ${HOSTNAME^} ${ID_NUM_TYPE}..."
# Set temporary ID number if script CTID/VMID preset is not available
if [ -n "${IP}" ] && [[ ${IP} =~ ${ip4_regex} ]] && [ ! $(valid_machineid ${ID_NUM_TMP} > /dev/null 2>&1; echo $?) == 0 ]; then
  if [ $(valid_machineid "$(echo ${IP} | awk -F'.' '{print $4}')" > /dev/null 2>&1; echo $?) == 0 ]; then
    # Last octet of IPv4
    ID_NUM_TMP=$(echo ${IP} | awk -F'.' '{print $4}')
  elif [ ! $(valid_machineid "$(echo ${IP} | awk -F'.' '{print $4}')" > /dev/null 2>&1; echo $?) == 0 ]; then
    # Auto generated CTID
    ID_NUM_TMP=$(pvesh get /cluster/nextid)
  fi
elif [ -n "${IP}" ] && [ ${IP} == 'dhcp' ]; then
  # Auto generated VMID
  ID_NUM=$(pvesh get /cluster/nextid)
  PASS_MSG="${ID_NUM_TYPE} is set: ${YELLOW}${ID_NUM}${NC}"
  if [ ${VM_TYPE} == 'ct' ]; then
    CTID=${ID_NUM}
    info "$PASS_MSG"
    echo
  elif [ ${VM_TYPE} == 'vm' ]; then
    VMID=${ID_NUM}
    info "$PASS_MSG"
    echo
  fi
elif [ -n "${IP6}" ] && [ ! $(valid_machineid ${ID_NUM_TMP} > /dev/null 2>&1; echo $?) == 0 ]; then
  # Auto generated VMID
  ID_NUM=$(pvesh get /cluster/nextid)
  PASS_MSG="${ID_NUM_TYPE} is set: ${YELLOW}${ID_NUM}${NC}"
  if [ ${VM_TYPE} == 'ct' ]; then
    CTID=${ID_NUM}
    info "$PASS_MSG"
    echo
  elif [ ${VM_TYPE} == 'vm' ]; then
    VMID=${ID_NUM}
    info "$PASS_MSG"
    echo
  fi
fi
# Query for non-dhcp
if [ -n "${IP}" ] && [ ! ${IP} == 'dhcp' ] || [ -n "${IP6}" ] && [ ! ${IP6} == 'dhcp' ]; then
  msg "Proxmox ${ID_NUM_TMP} numeric IDs must be greater than 100. $(if [ -n "${IP}" ] && [ $(echo ${IP} | awk -F'.' '{print $4}') >= '100' ]; then echo -e "We recommend the User uses the last octet or host section value of your ${HOSTNAME^} IPv4 address to set a valid ${ID_NUM_TYPE}. If this ${ID_NUM_TYPE} is not available then PVE will auto-generate a valid ${ID_NUM_TYPE} for the User to accept or reject."; fi)"
  while true; do
    read -p "Enter ${ID_NUM_TYPE} : " -e -i ${ID_NUM_TMP} ID_NUM
    FAIL_MSG="The ${ID_NUM_TYPE} is not valid. A valid ${ID_NUM_TYPE} is when all of the following constraints are satisfied:\n
      --  it is not assigned to any other PVE CT or VM machine.
      --  it must be greater than 100.
      --  it is a numerical number.\n
    Try again..."
    PASS_MSG="${ID_NUM_TYPE} is set: ${YELLOW}${ID_NUM}${NC}"
    result=$(valid_machineid ${ID_NUM} > /dev/null 2>&1)
    if [ $? == 0 ]; then
      info "$PASS_MSG"
      if [ ${VM_TYPE} == 'ct' ]; then
        CTID=${ID_NUM}
      elif [ ${VM_TYPE} == 'vm' ]; then
        VMID=${ID_NUM}
      fi
      echo
      break
    elif [ $? != 0 ]; then
      warn "$FAIL_MSG"
      echo
    fi
  done
fi

#---- Set Root Disk Size
if [ ${VM_TYPE} == 'ct' ]; then
  SIZE_VAR=${CT_SIZE}
elif [ ${VM_TYPE} == 'vm' ]; then
  SIZE_VAR=${VM_SIZE}
fi
while true; do
  read -p "Enter Root Disk Size (GiB): " -e -i ${SIZE_VAR} SIZE_VAR
  FAIL_MSG="The input is not valid. A valid input is when all of the following constraints are satisfied:\n
      --  it must be less than 50 (The User can always change after build).
      --  it is a numerical number.\n
    Try again..."
  PASS_MSG="Root disk size is set: ${YELLOW}${SIZE_VAR}${NC}"
  result=$([[ ${SIZE_VAR} =~ ${R_NUM} ]] && [[ ${SIZE_VAR} -lt 50 ]] > /dev/null 2>&1)
  if [ $? == 0 ]; then
		info "$PASS_MSG"
    if [ ${VM_TYPE} == 'ct' ]; then
      CT_SIZE=${SIZE_VAR}
    elif [ ${VM_TYPE} == 'vm' ]; then
      VM_SIZE=${SIZE_VAR}
    fi
    echo
    break
  elif [ $? != 0 ]; then
		warn "$FAIL_MSG"
    echo
	fi
done

#---- Set CT Memory (RAM)
while true; do
  read -p "Enter memory (RAM) to be allocated (MiB): " -e -i ${MEMORY} MEMORY
  FAIL_MSG="The input is not valid. A valid input is when all of the following constraints are satisfied:\n
      --  it must be less than $(max_ram_allocation)MiB.
          (${MEMORY_HOST_RESERVE}MiB is reserved for Proxmox core)
      --  it is a numerical number.\n
    Try again..."
  PASS_MSG="Memory size is set: ${YELLOW}${MEMORY}${NC} (MiB)"
  result=$([[ ${MEMORY} =~ ${R_NUM} ]] && [[ ${MEMORY} -lt $(max_ram_allocation) ]] > /dev/null 2>&1)
  if [ $? == 0 ]; then
		info "$PASS_MSG"
    # MEMORY_VAR=${MEMORY}
    echo
    break
  elif [ $? != 0 ]; then
		warn "$FAIL_MSG"
    echo
	fi
done


#---- Set CT SSHd Port
if [ ${SSH_ENABLE} == 0 ]; then
  if [ ! -n "${SSH_PORT}" ]; then
    SSH_PORT='22'
  fi
  while true; do
    read -p "Enter a SSHd Port number: " -e -i ${SSH_PORT} SSH_PORT
    FAIL_MSG="The input is not valid. A valid input is when all of the following constraints are satisfied:\n
        --  it is a numerical number.
        --  not in use by other well known protocols ( i.e 138,443,8080,587 )\n
      Try again..."
    PASS_MSG="SSHd port is set: ${YELLOW}${SSH_PORT}${NC}"
    result=$([[ ${SSH_PORT} =~ ${R_NUM} ]] > /dev/null 2>&1)
    if [ $? == 0 ]; then
      info "$PASS_MSG"
      SSH_PORT=${SSH_PORT}
      echo
      break
    elif [ $? != 0 ]; then
      warn "$FAIL_MSG"
      echo
    fi
  done
fi

#---- PVESM Storage Bind Mounts
if [[ ${#pvesm_required_LIST[@]} -ge 1 ]]; then
  unset pvesm_input_LIST
  while IFS=':' read -r var1 var2; do
    if [[ $(pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-$var1") ]]; then
      pvesm_input_LIST+=( "$(pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-$var1" | awk '{print $1}' | sed "s/$/,\/mnt\/$var1/")" )
    else
      pvesm_missing_LIST+=( "$(echo $var1:$var2)" )
    fi
  done <<< $(printf '%s\n' "${pvesm_required_LIST[@]}" | grep -v 'none')


  # Validate ES Auto match
  msg "Easy Script has auto assigned '${#pvesm_input_LIST[@]}' of the required '${#pvesm_required_LIST[@]}' storage bind mounts. The User must confirm all '${#pvesm_input_LIST[@]}' storage bind mounts are correctly assigned. $(if [[ ${#pvesm_missing_LIST[@]} -ge 1 ]]; then echo "The missing '${#pvesm_missing_LIST[@]}' storage bind mounts can me manually assigned in the next steps."; fi)"
  echo
  # Display ES auto assigned bind mounts
  if [[ ${#pvesm_input_LIST[@]} -ge 1 ]]; then
    i=1
    while IFS=',' read -r var1 var2; do
      msg "\t$i. Auto assignment: $var1 ${WHITE}--->${NC} $var2"
      (( i=i+1 ))
    done <<< $(printf '%s\n' "${pvesm_input_LIST[@]}")
  fi
  # Display ES missing bind mounts
  if [[ ${#pvesm_missing_LIST[@]} -ge 1 ]]; then
    if [[ ${#pvesm_input_LIST[@]} -eq 0 ]]; then
      i=1
    fi
    while IFS=':' read -r var1 var2; do
      msg "\t$i. Missing assignment: $var1 ${WHITE}--->${NC} ?"
      (( i=i+1 ))
    done <<< $(printf '%s\n' "${pvesm_missing_LIST[@]}")
  fi
  echo

  # Confirmation of ES auto assigned bind mounts
  while true; do
    read -p "Confirm the '${#pvesm_input_LIST[@]}' auto assignments are correct [y/n]?: " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        info "'${#pvesm_input_LIST[@]} auto assignment status: ${YELLOW}set${NC}"
        echo
        break
        ;;
      [Nn]*)
        unset pvesm_input_LIST
        unset pvesm_missing_LIST
        while IFS= read -r line; do
          [[ "$line" =~ ^none ]] && continue
          pvesm_missing_LIST+=( "$line" )
        done <<< $(printf '%s\n' "${pvesm_required_LIST[@]}")
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done

  # Manual assignment
  if [[ ${#pvesm_missing_LIST[@]} -ge 1 ]]; then
    msg_box "#### PLEASE READ CAREFULLY - ASSIGNMENT OF STORAGE BIND MOUNTS ####\n\nThe User has '${#pvesm_missing_LIST[@]}' storage bind mount(s) to manually assign. The User must select and assign a PVE storage mount ( PVESM ) for each required media category (type). If the User is missing any PVE storage mounts then select menu option 'NONE' and use the PVE Web Management interface storage manager setup tool to create the missing PVE storage mount(s). Then re-run this installation script again.\n\n$(printf '%s\n' "${pvesm_missing_LIST[@]}" | column -s ":" -t -N "MEDIA CATEGORY,DESCRIPTION" | indent2))\n\nAll the above PVE storage mounts MUST be assigned."
    echo

    OPTIONS_VALUES_INPUT=$(pvesm status | grep -v 'local' | awk 'NR>1{ print $1 }' | sed -e '$a\'none'')
    OPTIONS_LABELS_INPUT=$(pvesm status | grep -v 'local' | awk 'NR>1{ $4=sprintf("%.0f",$4*512/(1024*1024*1024)); print $1, "Storage mount ("$4" GB)" }' OFS=':' | sed -e '$a\''none:No match. Exit installer & fix the issue. Then try again.''' | awk -F':' '{print toupper($1), $2}' OFS=':' | column -s : -t)
    a=0
    until [ ! $a -lt "${#pvesm_missing_LIST[@]}" ]
    do
    var01=$(printf '%s\n' "${pvesm_missing_LIST[${a}]}" | awk -F':' '{ print $1 }')
    var02=$(printf '%s\n' "${pvesm_missing_LIST[${a}]}" | awk -F':' '{ print $2 }')
    msg "Select a PVE storage mount point for:\n\n\t${WHITE}${var01}${NC} - ( ${var02} )\n"
      makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
      singleselect SELECTED "$OPTIONS_STRING"
      a=$((a+1))
      if [ $(echo ${RESULTS}) == 'none' ]; then
        msg "You have chosen to abort this installation. To fix the issue use the PVE Web Management interface storage manager setup tool and create any missing PVE storage mounts. Then try again."
        echo
        trap cleanup EXIT
      else
        pvesm_input_LIST+=( "$(echo ${RESULTS} | sed "s/$/,\/mnt\/${var01}/")" )
        echo
      fi
    done
  fi

  # Auto Add developer git mount
  if [ ${DEV_GIT_MOUNT_ENABLE} == 0 ] && [[ $(pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-git") ]]; then
    pvesm_input_LIST+=( "$(pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-git$" | awk 'BEGIN {OFS = ","}{print $1,"/mnt/pve/"$1}')" )
  fi
fi # End of bind mounts statement