#!/usr/bin/env bash

#Static Default Function VAR
FUNC_NAS_HOSTNAME=nas

set -Eeuo pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
trap cleanup EXIT

function error_exit() {
  trap - ERR
  local DEFAULT='Unknown failure occured.'
  local REASON="\e[97m${1:-$DEFAULT}\e[39m"
  local FLAG="\e[91m[ERROR] \e[93m$EXIT@$LINE"
  msg "$FLAG $REASON"
  [ ! -z ${CTID-} ] && cleanup_failed
  exit $EXIT
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT" | fmt -s -w 80 
}
function msg_nofmt() {
  local TEXT="$1"
  echo -e "$TEXT"
}
function warn() {
  local REASON="${WHITE}$1${NC}"
  local FLAG="${RED}[WARNING]${NC}"
  msg "$FLAG"
  msg "$REASON"
}
function info() {
  local REASON="$1"
  local FLAG="\e[36m[INFO]\e[39m"
  msg_nofmt "$FLAG $REASON"
}
function section() {
  local REASON="-\e[97m$1\e[37m"
  printf -- '-%.0s' {1..84}; echo ""
  msg "$SECTION_HEAD $REASON"
  printf -- '-%.0s' {1..84}; echo ""
  echo
}
# Msg Box Function
function msg_box () {
  echo -e "$1" | fmt -w 80 | boxes -d stone -p a1l3 -s 84
}
function cleanup_failed() {
  if [ ! -z ${MOUNT+x} ]; then
    pct unmount $CTID
  fi
  if $(pct status $CTID &>/dev/null); then
    if [ "$(pct status $CTID | awk '{print $2}')" == "running" ]; then
      pct stop $CTID
    fi
    pct destroy $CTID
  elif [ "$(pvesm list $STORAGE --vmid $CTID)" != "" ]; then
    pvesm free $ROOTFS
  fi
}
function pushd () {
  command pushd "$@" &> /dev/null
}
function popd () {
  command popd "$@" &> /dev/null
}
function cleanup() {
  popd
  rm -rf $TEMP_DIR
  unset TEMP_DIR
}
function load_module() {
  if ! $(lsmod | grep -Fq $1); then
    modprobe $1 &>/dev/null || \
      die "Failed to load '$1' module."
  fi
  MODULES_PATH=/etc/modules
  if ! $(grep -Fxq "$1" $MODULES_PATH); then
    echo "$1" >> $MODULES_PATH || \
      die "Failed to add '$1' module to load at boot."
  fi
}
# Set PVE container storage location
function set_ct_storage () {
  msg "Select PVE CT storage location..."
  STORAGE_LIST=( $(pvesm status -content rootdir | awk 'NR>1 {print $1}') )
  if [ ${#STORAGE_LIST[@]} -eq 0 ]; then
    warn "\nPVE containers requires at least one storage location."
    die "Unable to detect a valid storage location on PVE host '${HOSTNAME^^}'."
  elif [ ${#STORAGE_LIST[@]} -eq 1 ]; then
    STORAGE=${STORAGE_LIST[0]}
    info "PVE CT 'storage location' is set: ${YELLOW}$STORAGE${NC}"
    echo
  else
    msg "\n\nMore than one storage location has been detected.\n"
    PS3=$'\n'"Which storage location would you like to use (Recommend local-zfs) ? "
    select s in "${STORAGE_LIST[@]}"; do
      if [[ " ${STORAGE_LIST[@]} " =~ " ${s} " ]]; then
        STORAGE=$s
        info "PVE CT 'storage location' is set: ${YELLOW}$STORAGE${NC}"
        echo
        break
      fi
      echo -en "\e[1A\e[K\e[1A"
    done
  fi
}
# PCT list fix
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
# Check IP Validity of Octet
function valid_ip() {
  local  ip=$1
  local  stat=1
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      OIFS=$IFS
      IFS='.'
      ip=($ip)
      IFS=$OIFS
      [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
          && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
      stat=$?
  fi
  return $stat
}
# Indent Tab Command
function indent() {
    eval "$@" |& sed "s/^/\t/"
    return "$PIPESTATUS"
}
# Set PVE CT Hostname Function
function set_ct_hostname() {
  msg "Setting CT hostname..."
  while true; do
    read -p "Enter a CT CT hostname: " -e -i $CT_HOSTNAME_VAR CT_HOSTNAME
    CT_HOSTNAME=${CT_HOSTNAME,,}
    if [ $(pct_list | grep -w $CT_HOSTNAME >/dev/null; echo $?) == 0 ]; then
      warn "\nThere are problems with your input:\n1. The CT hostname \"$CT_HOSTNAME\" already exists.\n\n   Try again..."
      echo
    elif [ $(pct_list | grep -w $CT_HOSTNAME >/dev/null; echo $?) == 1 ] && [ $CT_HOSTNAME  = "$CT_HOSTNAME_VAR" ]; then
      info "$SECTION_HEAD CT hostname is set: ${YELLOW}$CT_HOSTNAME${NC}"
      echo
      break  
    elif [ $(pct_list | grep -w $CT_HOSTNAME >/dev/null; echo $?) == 1 ] && [ "$CT_HOSTNAME"  = "$CT_HOSTNAME_VAR" ]; then
      warn "\nThere maybe issues with your input:\n1. The CT hostname \"$CT_HOSTNAME\" is suitable and is available, BUT\n2. We recommended you adhere to our naming convention and use the default\n   hostname \"$CT_HOSTNAME_VAR\". But your CT hostname \"$CT_HOSTNAME\"\n   can also be used.\n\n   Proceed with caution - you have been advised."
      read -p "Accept your non-standard CT hostname ${RED}"$CT_HOSTNAME"${NC} [y/n]?: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "$SECTION_HEAD CT hostname is set: ${YELLOW}$CT_HOSTNAME${NC} (non-standard)"
        echo
        break
      else
        msg "Try again..."
        echo
      fi
    fi
  done
}
# Set PVE CT IP Function
function set_ct_ip() {
  msg "Setting CT \"$CT_HOSTNAME\" IPv4 address..."
  while true; do
    read -p "Enter a CT IPv4 address: " -e -i $CT_IP_VAR CT_IP
    msg "Performing checks on your input (be patient, may take a while)..."
    if [ $(valid_ip $CT_IP >/dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 "$CT_IP" > /dev/null; echo $?) != 0 ] && [ "$(echo "$CT_IP" | sed  's/\/.*//g' | awk -F"." '{print $3}')" = "$CT_TAG_VAR" ]; then
      read -p "Is your LAN network VLAN ready & enabled (L2/L3 switches) [y/n]?: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "$SECTION_HEAD CT IPv4 address is set: ${YELLOW}$CT_IP${NC}"
        echo
        break
      else
        msg "Then best use a VLAN1 IPv4 address.\nTry again..."
        echo
      fi
    elif [ $(valid_ip $CT_IP >/dev/null; echo $?) != 0 ]; then
      warn "\nThere are problems with your input:\n1. The IP address is incorrectly formatted.\n   It must be in the IPv4 format, quad-dotted octet format (i.e xxx.xxx.xxx.xxx ).\n\n   Try again..."
      echo
    elif [ $(valid_ip $CT_IP >/dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 $CT_IP > /dev/null; echo $?) == 0 ]; then
      warn "\nThere are problems with your input:\n1. The IP address meets the IPv4 standard, BUT\n2. The IP address $(echo "$CT_IP" | sed  's/\/.*//g') is already in-use by\n   another device on your your LAN.\n\n   Try again..."
      echo
    elif [ $(valid_ip $CT_IP >/dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 $CT_IP > /dev/null; echo $?) != 0 ] && [ $(echo "$CT_IP" | awk -F'.' '{print $3}') == 1 ]; then
      warn "\nThere maybe issues with your input:\n1. The IP address meets the IPv4 standard,\n2. The IP address $(echo "$CT_IP" | sed  's/\/.*//g') is not in use (available), BUT\n3. While we recommend VLAN$CT_TAG_VAR for your new CT with a\n   IPv4 address of $CT_IP_VAR your input of $CT_IP\n   is still valid if your LAN network is not VLAN ready (no VLAN support).\n   If you choose to proceed with $CT_IP you must set all your\n   $(echo $SECTION_HEAD | grep -Eo '^[^ ]+') CTs with the same VLAN$(echo "$CT_IP" | sed  's/\/.*//g' | awk -F"." '{print $3}') setting and assign a\n   valid VLAN$(echo "$CT_IP" | sed  's/\/.*//g' | awk -F"." '{print $3}') IPv4 address to avoid network issues.\n\n   Proceed with caution - you have been advised."
      echo
      read -p "Accept your IPv4 address ${WHITE}"$CT_IP"${NC} [y/n]?: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "$SECTION_HEAD CT IPv4 address is set: ${YELLOW}$CT_IP${NC} (no VLAN)"
        echo
        break
      else
        msg "Try again..."
        echo
      fi
    elif [ $(valid_ip $CT_IP >/dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 $CT_IP > /dev/null; echo $?) != 0 ] && [ $(echo $CT_IP | awk -F'.' '{print $3}') != "$CT_TAG_VAR" ] || [ $(echo $CT_IP | awk -F'.' '{print $3}') != 1 ]; then
      warn "\nThere are issues with your input:\n1. The IP address meets the IPv4 standard,\n2. The IP address $(echo "$CT_IP" | sed  's/\/.*//g') is not in use (available), BUT\n3. We recommend VLAN$CT_TAG_VAR for your new CT with a IPv4 address of $CT_IP_VAR.\n   Changing to a non-standard VLAN$(echo $CT_IP | sed  's/\/.*//g' | awk -F"." '{print $3}') may cause network issues with our suite of $(echo $SECTION_HEAD |grep -Eo '^[^ ]+') CTs.\n   For example, this setting may result in your CT having NO network or NAS access.\n\n   Proceed with caution - you have been advised."
      echo
      read -p "Is your LAN network VLAN ready & enabled (L2/L3 switches) [y/n]?: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Accept your non-standard IPv4 address ${RED}"$CT_IP"${NC} [y/n]?: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          info "$SECTION_HEAD CT IPv4 address is set: ${YELLOW}$CT_IP${NC} (non-standard)"
          echo
          break
        else
          msg "Try again..."
          echo
        fi
      else
        msg "Then best use a VLAN1 IPv4 address.\nTry again..."
        echo
      fi
    fi
  done
}
# Set PVE CT VLAN Function
function set_ct_vlan() {
  msg "Setting CT \"$CT_HOSTNAME\" VLAN..."
  while true; do
    if [ $(echo $CT_IP | awk -F'.' '{print $3}') = 1 ]; then
      CT_TAG=0
      info "The CT VLAN is set: ${YELLOW}$CT_TAG${NC}."
      echo
      break
    elif [ $(echo $CT_IP | awk -F'.' '{print $3}') = $CT_TAG_VAR ]; then
      CT_TAG=$CT_TAG_VAR
      info "The CT VLAN is set: ${YELLOW}$CT_TAG${NC}."
      echo
      break
    elif [ $(echo $CT_IP | awk -F'.' '{print $3}') != 1 ] || [ $(echo $CT_IP | awk -F'.' '{print $3}') != $CT_TAG_VAR ]; then
      warn "\nWe need you to confirm your VLAN because:\n1. The CT IP address is $CT_IP which is non-standard for our $(echo $SECTION_HEAD |grep -Eo '^[^ ]+') builds.\n2. A likely VLAN number is VLAN$(echo $CT_IP | sed  's/\/.*//g' | awk -F"." '{print $3}')."
      echo
      read -p "Is network ${WHITE}VLAN$(echo $CT_IP | awk -F'.' '{print $3}')${NC} correct for this CT [y/n]?: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        CT_TAG=$(echo $CT_IP | awk -F'.' '{print $3}')
        info "The CT VLAN is set: ${YELLOW}$CT_TAG${NC}."
        echo
        break
      else
        read -p "Enter a new valid network CT VLAN tag number: " -e -i $(echo $CT_IP | awk -F'.' '{print $3}') CT_TAG
        read -p "Is network ${WHITE}VLAN$CT_TAG${NC} correct for this CT [y/n]?: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          CT_TAG=$(echo $CT_IP | awk -F'.' '{print $3}')
          info "The CT VLAN is set: ${YELLOW}$CT_TAG${NC}."
          echo
          break
        else
          msg "Try again..."
          echo
        fi
      fi
    fi
  done
}
# Set PVE CT Gateway IPv4 Address
function set_ct_gw() {
  msg "Setting CT \"$CT_HOSTNAME\" Gateway IPv4 address..."
  while true; do
    if [ $CT_IP = $CT_IP_VAR ] && [ $(ping -s 1 -c 2 $CT_GW_VAR > /dev/null; echo $?) = 0 ]; then
      CT_GW=CT_GW_VAR
      info "$SECTION_HEAD CT Gateway IP is set: ${YELLOW}$CT_GW${NC}"
      echo
      break
    elif [ $(echo $CT_IP | awk -F'.' -v OFS="." '{print $1,$2,$3}') =  $(ip route show | grep default | awk '{print $3}' | awk -F'.' -v OFS="." '{print $1,$2,$3}') ] && [ $(ping -s 1 -c 2 $(ip route show | grep default | awk '{print $3}') > /dev/null; echo $?) = 0 ]; then
      CT_GW=$(ip route show | grep default | awk '{print $3}')
      info "$SECTION_HEAD CT Gateway IP is set: ${YELLOW}$CT_GW${NC}"
      echo
      break
    elif [ $CT_IP != $CT_IP_VAR ] || [ $(echo $CT_IP | awk -F'.' -v OFS="." '{print $1,$2,$3}') != $(ip route show | grep default | awk '{print $3}' | awk -F'.' -v OFS="." '{print $1,$2,$3}') ]; then
      msg "Because you have chosen to use a non-standard CT IP ${WHITE}$CT_IP${NC} and VLAN setting\nwe cannot determine your Gateway IP address for this CT.\nYou must manually input a working Gateway IPv4 address."
      echo
      read -p "Enter a working Gateway IPv4 address for this CT: " -e -i $(echo $CT_IP | awk -F'.' -v OFS="." '{print $1,$2,$3,"xxx"}') CT_GW
      msg "Performing checks on your input (be patient, may take a while)..."
      if [ $(valid_ip $CT_GW >/dev/null; echo $?) == 1 ]; then
        warn "\nThere are problems with your input:\n1. Your IP address is incorrectly formatted.\n   It must be in the IPv4 format, quad-dotted octet format (i.e xxx.xxx.xxx.xxx ).\n\n   Try again..."
        echo
      elif [ $(valid_ip $CT_GW >/dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 $CT_GW > /dev/null; echo $?) == 0 ]; then
        info "$SECTION_HEAD Gateway IP is set: ${YELLOW}$CT_GW${NC}"
        echo
        break
      elif [ $(valid_ip $CT_GW >/dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 $CT_GW > /dev/null; echo $?) = 1 ]; then
        warn "\nThere are problems with your input:\n1. The IP address meets the IPv4 standard, BUT\n2. The IP address $CT_GW is NOT reachable (cannot ping).\n\n   Try again..."
        echo
      fi
    fi
  done
}
# Set PVE CT ID
function set_ctid() {
  msg "Setting CT \"$CT_HOSTNAME\" container CTID..."
  while true; do
    if [ $(echo $CT_IP | awk -F'.' '{print $4}') -ge 100 ]; then
      CTID_VAR=$(echo $CT_IP | awk -F'.' '{print $4}')
      msg "Proxmox CTID numeric IDs must be greater than 100. Our PVE CTID numeric ID\nsystem uses the last octet or host section value of your CT IPv4 address to\ncalculate a valid CTID."
      if [ "$(pct_list | grep -w $CTID_VAR > /dev/null; echo $?)" != 0 ]; then
        CTID=$CTID_VAR
        info "$SECTION_HEAD CTID is set: ${YELLOW}$CTID${NC}"
        echo
        break
      else
        warn "\nThere are problems with your input:\n1. PVE CTID numeric ID $CTID_VAR is in use by another CT labelled \"$(pct_list | grep -w $CTID_VAR | awk -F',' '{print $4}')\".\n\n   PVE will auto-generate a valid CTID.\n   (press ENTER to accept)."
        read -p "Accept the PVE generated CTID or type a new CTID numeric ID: " -e -i "$(pvesh get /cluster/nextid)" CTID_VAR
        if [ "$(pct_list | grep -w $CTID_VAR > /dev/null; echo $?)" != 0 ]; then
          CTID=$CTID_VAR
          info "$SECTION_HEAD CTID is set: ${YELLOW}$CTID${NC}"
          echo
          break
        else
          warn "\nThere are problems with your input:\n1. PVE CTID numeric ID $CTID_VAR is also in use by another CT labelled \"$(pct_list | grep -w $CTID_VAR | awk -F',' '{print $4}')\".\n\n   Try again..."
          echo
        fi
      fi
    elif [ $(echo $CT_IP | awk -F'.' '{print $4}') -lt 100 ]; then
      CTID_VAR="$(( $(echo $CT_IP | awk -F'.' '{print $4}') + 100 ))"
      msg "Proxmox CTID numeric IDs must be greater than 100. Our PVE CTID numeric ID\nsystem uses the last octet or host section value of your CT IPv4 address to\ncalculate a valid CTID. Because your CT IP last octet value $(echo "$CT_IP" | awk  -F'.' -v OFS="." '{print $1, $2, $3, "\033[1;37m"$4"\033[0m"}')\nis outside the PVE range, 100 units will be added to the value ($(( $(echo $CT_IP | awk -F'.' '{print $4}') + 100 )))."
      echo
      msg "Performing PVE PCT check on CTID $CTID_VAR..."
      if [ "$(pct_list | grep -w $CTID_VAR > /dev/null; echo $?)" != 0 ]; then
        CTID=$CTID_VAR
        info "$SECTION_HEAD CTID is set: ${YELLOW}$CTID${NC}"
        echo
        break
      else
        warn "\nThere are problems with your input:\n1. PVE CTID numeric ID $CTID_VAR is in use by another CT labelled \"$(pct_list | grep -w $CTID_VAR | awk -F',' '{print $4}')\".\n\n   PVE will auto-generate a valid CTID.\n   (press ENTER to accept)."
        read -p "Accept the PVE generated CTID or type a new CTID numeric ID: " -e -i "$(pvesh get /cluster/nextid)" CTID_VAR
        if [ "$(pct_list | grep -w $CTID_VAR > /dev/null; echo $?)" != 0 ]; then
          CTID=$CTID_VAR
          info "$SECTION_HEAD CTID is set: ${YELLOW}$CTID${NC}"
          echo
          break
        else
          warn "\nThere are problems with your input:\n1. PVE CTID numeric ID $CTID_VAR is also in use by another CT labelled \"$(pct_list | grep -w $CTID_VAR | awk -F',' '{print $4}')\".\n\n   Try again..."
          echo
        fi
      fi     
    fi
  done
}
# Set PVE CT Bind Mount Function
function set_bind_mount () {
  # PVE default scan
  while read -r line; do
    if [[ $(pvesm status | grep -v 'local' | grep -wEi "^$FUNC_NAS_HOSTNAME\-[0-9]+\-$line") ]]; then
      pvesm status | grep -v 'local' | grep -wEi "^$FUNC_NAS_HOSTNAME\-[0-9]+\-$line" | awk '{print $1}' | sed "s/$/ \/mnt\/$line/" >> pvesm_input_list_default_var01
    fi
  done <<< $(cat pvesm_required_list | awk -F'|' '{print $1}' | grep -v 'none')
  if [[ ! $(comm -23 <(sort -u <<< $(cat pvesm_required_list | grep -vi 'none' | awk -F'|' '{print $1}')) <(sort -u <<< $(cat pvesm_input_list_default_var01 | awk '{print $2}' | sed 's/\/mnt\///'))) ]]; then
    msg "Performing PVE host storage mount scan..."
    PVESM_INPUT=0
    cp pvesm_input_list_default_var01 pvesm_input_list
    msg "Easy Script has detected a default set of PVE storage folders. Proceeding with the following CT bind mounts:"
    echo
    i=1
    while read -r var1 var2; do
      msg "     $i) Auto assigned and set: $var1 ${WHITE}--->${NC} $var2"
      ((i=i+1))
    done < pvesm_input_list_default_var01
    echo
  else
    PVESM_INPUT=1
  fi

  if [ $PVESM_INPUT = 1 ]; then
    # PVE host scan
    msg "Performing PVE host storage mount scan..."
    msg "Easy Script is scanning your PVE host. Availability is shown:"
    echo
    i=1
    while read -r line; do
      if [[ $(pvesm status | grep -v 'local' | grep -wEi "^.*\-.*\-$line") ]]; then
        msg "     $i) Auto assigned and set: $(pvesm status | grep -v 'local' | grep -wE "^.*\-.*\-$line" | awk '{print $1}') ${WHITE}--->${NC} /mnt/$line"
        pvesm status | grep -v 'local' | grep -wEi "^.*\-.*\-$line" | awk '{print $1}' | sed "s/$/ \/mnt\/$line/" >> pvesm_input_list_var01
      else
        msg "     $i) PVE storage mount '$line' is: ${RED}missing${NC}"
      fi
      ((i=i+1))
    done <<< $(cat pvesm_required_list | awk -F'|' '{print $1}' | grep -v 'none')
    echo
    if [[ ! $(comm -23 <(sort -u <<< $(cat pvesm_required_list | grep -vi 'none' | awk -F'|' '{print $1}')) <(sort -u <<< $(cat pvesm_input_list_var01 | awk '{print $2}' | sed 's/\/mnt\///'))) ]]; then
      read -p "Confirm if the PVE storage mount assignments are correct [y/n]?: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp pvesm_input_list_var01 pvesm_input_list
        PVESM_MANUAL_ASSIGN=1
        info "PVE CT storage mount points are set."
        echo
      else
        PVESM_MANUAL_ASSIGN=0
      fi
    fi
    if [[ $(comm -23 <(sort -u <<< $(cat pvesm_required_list | grep -vi 'none' | awk -F'|' '{print $1}')) <(sort -u <<< $(cat pvesm_input_list_var01 | awk '{print $2}' | sed 's/\/mnt\///'))) ]] || [ $PVESM_MANUAL_ASSIGN = 0 ]; then
      msg "We cannot identify and assign all of the required PVE storage mounts. You have two options. Abort or manually assign a media type to every available PVE host storage mount. This works for PVE hosts where the storage mounts exist but have non-standard label names causing Easy Script to fail. Remember, you MUST have all $(cat pvesm_required_list | grep -vi 'none' | wc -l)x media types available $(cat pvesm_required_list | grep -vi 'none' | awk -F'|' '{print $1}' | tr '\n' ',' | sed 's/,$//' | sed -e 's/^/(/g' -e 's/$/)/g') on your PVE host for a $SECTION_HEAD CT.\nIf you choose to abort then use the Proxmox Web Management interface storage manager setup tool to create your PVE storage mounts:\n\n    ${WHITE}https://$(hostname -i):8006${NC}"
      echo
      read -p "Manually assign each media type to your PVE storage mounts [y/n]?: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        # Manual Assign PVE host storage mounts
        mapfile -t STORAGE_TYPE <<< $(cat pvesm_required_list | awk -F'|' '{print "\033[1;33m"toupper($1)"\033[0m","-",$2}')
        while IFS= read -r line; do
          PS3="Select the media type for PVE storage mount ${WHITE}$line${NC} (entering numeric) : "
          select media_type in "${STORAGE_TYPE[@]}"; do
          echo
          msg "You have assigned and set: '$line' ${WHITE}--->${NC} '$(echo ${media_type,,} | awk -F' - ' '{print $1}' | sed 's/\x1b\[[^\x1b]*m//g')'"
          read -p "Confirm your setting is correct: [y/n]?: " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo $line /mnt/$(echo ${media_type,,} | awk '{print $1}' | sed "s/\x1B\[\([0-9]\{1,2\}\(;[0-9]\{1,2\}\)\?\)\?[mGK]//g") >> pvesm_input_list_var02
            echo
            break
          else
            echo
            msg "No problem. Try again..."
            sleep 1
            echo
          fi
          # done
          done < /dev/tty
        done <<< $(pvesm status | grep -v 'local' | awk 'NR>1 {print $1}')
        # Check if manual inputs are correct
        if [[ $(comm -23 <(sort -u <<< $(cat pvesm_required_list | grep -vi 'none' | awk -F'|' '{print $1}')) <(sort -u <<< $(cat pvesm_input_list_var02 | awk '{print $2}' | sed 's/\/mnt\///'))) ]]; then
          # List missing PVE Storage mounts
          msg "There are problems with your input:"
          echo
          i=1
          while IFS= read -r line; do
            msg "     $i) PVE storage mount '$line' is: ${RED}missing${NC}"
            ((i=i+1))
          done <<< $(comm -23 <(sort -u <<< $(cat pvesm_required_list | grep -vi 'none' | awk -F'|' '{print $1}')) <(sort -u <<< $(cat pvesm_input_list_var02 | awk '{print $2}' | sed 's/\/mnt\///')))
          echo
          msg "The PVE host is missing some required storage mounts. We cannot continue. Go to your Proxmox Web Management interface storage manager (${WHITE}https://$(hostname -i):8006${NC}) and create all of the following PVE storage mounts (be smart, label them exactly as shown below - replacing NAS appliance identifier, nas-0X, with for example nas-01):"
          echo
          i=1
          while IFS= read -r line; do
            msg "     $i) 'nas-0X-$(echo $line | awk -F'|' '{print $1}')' <---  $(echo $line | awk -F'|' '{print $2}')"
            ((i=i+1))
          done <<< $(cat pvesm_required_list | grep -vi 'none')
          echo
          msg "After you have created the above PVE storage mounts run this Easy Script again. Aborting in 2 seconds..."
          echo
          sleep 2
          cleanup
        else
          cp pvesm_input_list_var02 pvesm_input_list
          info "PVE CT storage mount points are set."
          echo
        fi
      else
        msg "Good choice. Fix the issue and try again..."
        echo
        sleep 2
        cleanup
      fi
    fi
  fi
  # Create CT Bind Mount Points
  if [[ -f pvesm_input_list ]]; then
    msg "Creating ${CT_HOSTNAME_VAR^} CT bind mounts..."
    IFS=' '
    i=0
    while read -r PVE_MNT CT_MNT; do
      # pct set $CTID -mp$i $PVE_MNT,mp=$CT_MNT
      ((i=i+1))
      info "${CT_HOSTNAME_VAR^} CT bind mount created: $PVE_MNT ---> ${YELLOW}$CT_MNT${NC}"
    done < pvesm_input_list
    echo
  fi
}

# Terminal Colours
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'

# Bash Package Prerequisites
if [ $(dpkg -s boxes >/dev/null 2>&1; echo $?) = 1 ]; then
  apt-get install -y boxes >/dev/null
fi

# Resize Terminal
printf '\033[8;40;120t'

# Detect modules and automatically load at boot
load_module aufs
load_module overlay

# Set Temp Folder
if [ -z "${TEMP_DIR+x}" ]; then
    TEMP_DIR=$(mktemp -d)
    pushd $TEMP_DIR >/dev/null
else
    if [ $(pwd -P) != $TEMP_DIR ]; then
    cd $TEMP_DIR >/dev/null
    fi
fi
