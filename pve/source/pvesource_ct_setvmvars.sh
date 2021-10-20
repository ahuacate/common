#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_setvmvars.sh
# Description:  Source script for setting CT variables
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

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

# Check numerals only
R_NUM='^[0-9]+$'

#---- Static Variables -------------------------------------------------------------

FUNC_NAS_HOSTNAME=nas
PVESM_NONE='none|Ignore this share'
PVESM_EXIT='exit/finished|Nothing more to add'

#---- Other Variables --------------------------------------------------------------

# Developer Options
if [ -f /mnt/pve/nas-*[0-9]-git/ahuacate/developer_settings.git ]; then
  while IFS== read -r var val; do
    eval ${var}=${val}
  done < <(cat /mnt/pve/nas-*[0-9]-git/ahuacate/developer_settings.git | grep -v '^#')
fi

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

section "Set CT variables"

#---- ES Auto VAR Validation
# Easy Script check Hostname
if [ $(pct_list | grep -w ${CT_HOSTNAME_VAR} > /dev/null; echo $?) != 0 ]; then
  ES_AUTO_HOSTNAME=0
else
  ES_AUTO_HOSTNAME=1
fi

# Easy Script check IP
if [ $(echo ${CT_IP_VAR} | cut -d . -f 3) = 30 ] || [ $(echo ${CT_IP_VAR} | cut -d . -f 3) = 40 ] && [ ${CT_TAG_VAR} = 30 ] || [ ${CT_TAG_VAR} = 40 ] && [ $(valid_ip ${CT_IP_VAR} > /dev/null; echo $?) == 0 ] && [ $(grep -R 'net[0-9]*' /etc/pve/lxc/ | grep -oP '(?<=ip=).+?(?=,)' | sed 's/\/.*//' | grep ${CT_IP_VAR}  > /dev/null; echo $?) != 0 ]; then
  ES_AUTO_CT_IP=0
elif [ $(valid_ip ${CT_IP_VAR} > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 ${CT_IP_VAR} > /dev/null; echo $?) != 0 ] && [ $(grep -R 'net[0-9]*' /etc/pve/lxc/ | grep -oP '(?<=ip=).+?(?=,)' | sed 's/\/.*//' | grep ${CT_IP_VAR}  > /dev/null; echo $?) != 0 ]; then
  ES_AUTO_CT_IP=0
else
  ES_AUTO_CT_IP=1
fi

# Easy Script check Gateway
if [ $(echo ${CT_GW_VAR} | cut -d . -f 3) = 30 ] || [ $(echo ${CT_GW_VAR} | cut -d . -f 3) = 40 ] && [ ${CT_TAG_VAR} = 30 ] || [ ${CT_TAG_VAR} = 40 ] &&  [ $(valid_ip ${CT_GW_VAR} > /dev/null; echo $?) == 0 ] ; then
  ES_AUTO_CT_GW=0
elif [ $(ping -s 1 -c 2 ${CT_GW_VAR} > /dev/null; echo $?) = 0 ]; then
  ES_AUTO_CT_GW=0
elif [ $(ping -s 1 -c 2 ${CT_GW_VAR} > /dev/null; echo $?) != 0 ]; then
  ES_AUTO_CT_GW=1
fi

# Easy Script check CTID
if [ $(pct_list | grep -w ${CTID_VAR} > /dev/null; echo $?) != 0 ]; then
  ES_AUTO_CT_CTID=0
else
  ES_AUTO_CT_CTID=1
fi

# Easy Script check bind mounts
# Check if any PVESM Storage Mounts are required
if [ $(cat pvesm_required_list | awk -F'|' '{print $1}' | grep -v 'none' | wc -l) -ge 1 ]; then
  while read -r line; do
    if [[ $(pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-$line") ]]; then
      pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-$line" | awk '{print $1}' | sed "s/$/ \/mnt\/$line/" >> pvesm_input_list_default_var01
    fi
  done <<< $(cat pvesm_required_list | awk -F'|' '{print $1}' | grep -v 'none')
else
  # Create empty file
  touch pvesm_input_list_default_var01
fi
if [[ ! $(comm -23 <(sort -u <<< $(cat pvesm_required_list | awk -F'|' '{print $1}' | grep -v 'none')) <(sort -u <<< $(cat pvesm_input_list_default_var01 | awk '{print $2}' | sed 's/\/mnt\///'))) ]]; then
  PVESM_INPUT=0
  ES_AUTO_CT_BIND_MOUNTS=0
  if [ ${DEV_GIT_MOUNT_ENABLE} = 0 ]; then
    pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-git" | awk '{print $1,"/mnt/pve/"$1}' >> pvesm_input_list_default_var01
  fi
else
  ES_AUTO_CT_BIND_MOUNTS=1
  PVESM_INPUT=1
  if [ -f pvesm_input_list_default_var01 ]; then
    rm pvesm_input_list_default_var01
  fi
fi

# Validate Results
if [ ${ES_AUTO_HOSTNAME} = 0 ] && [ ${ES_AUTO_CT_IP} = 0 ] && [ ${ES_AUTO_CT_GW} = 0 ] && [ ${ES_AUTO_CT_CTID} = 0 ] && [ ${ES_AUTO_CT_BIND_MOUNTS} = 0 ]; then
msg "Easy Script has validated all default variable settings (recommended). The settings for '${CT_HOSTNAME_VAR^}' are:

  1) CT hostname: ${YELLOW}${CT_HOSTNAME_VAR}${NC}
  2) CT IPv4 address: ${YELLOW}${CT_IP_VAR}${NC}
  3) CT Gateway address: ${YELLOW}${CT_GW_VAR}${NC}
  4) CT CTID: ${YELLOW}${CT_GW_VAR}${NC}
  5) CT DNS Server address: ${YELLOW}${CT_DNS_SERVER_VAR}${NC}"
  i=6
  while read -r var1 var2; do
    msg "  $i) Bind mount: ${var1} ${WHITE}--->${NC} ${var2}"
    ((i=i+1))
  done < pvesm_input_list_default_var01
  echo
  while true; do
    read -p "Proceed with Easy Script defaults (recommended) [y/n]?: " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        CT_HOSTNAME=${CT_HOSTNAME_VAR,,}
        CT_IP=${CT_IP_VAR}
        CT_GW=${CT_GW_VAR}
        CTID=${CTID_VAR}
        CT_TAG=${CT_TAG_VAR}
        CT_DISK_SIZE=${CT_DISK_SIZE_VAR}
        CT_RAM=${CT_RAM_VAR}
        CT_DNS_SERVER=${CT_DNS_SERVER_VAR}
        if [ ${SSH_ENABLE} = 0 ]; then
          SSH_PORT=${SSH_PORT_VAR}
        fi
        cp pvesm_input_list_default_var01 pvesm_input_list
        ES_AUTO=0
        info "'${CT_HOSTNAME_VAR^}' CT build is set to use Easy Script defaults."
        echo
        break
        ;;
      [Nn]*)
        rm pvesm_input_list_default_var01
        ES_AUTO=1
        info "Proceeding with standard installation."
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
else
  ES_AUTO=1
fi


#---- Non-Auto VAR Setting
# Set PVE CT Hostname Function
if [ $ES_AUTO = 1 ]; then
  msg "Setting ${CT_HOSTNAME_VAR^} CT hostname..."
  while true; do
    read -p "Enter a CT hostname: " -e -i ${CT_HOSTNAME_VAR} CT_HOSTNAME
    CT_HOSTNAME=${CT_HOSTNAME,,}
    if [ $(pct_list | grep -w ${CT_HOSTNAME} > /dev/null; echo $?) == 0 ]; then
      warn "There are problems with your input:
      
      1. The CT hostname '${CT_HOSTNAME}' already exists.
      
      Try again..."
      echo
    elif [ $(pct_list | grep -w ${CT_HOSTNAME} > /dev/null; echo $?) == 1 ] && [ ${CT_HOSTNAME}  = "${CT_HOSTNAME_VAR}" ]; then
      info "${CT_HOSTNAME_VAR^} CT hostname is set: ${YELLOW}${CT_HOSTNAME}${NC}"
      echo
      break  
    elif [ $(pct_list | grep -w ${CT_HOSTNAME} > /dev/null; echo $?) == 1 ] && [ "${CT_HOSTNAME}" != "${CT_HOSTNAME_VAR}" ]; then
      warn "There maybe issues with your input:
      
      1. The CT hostname '${CT_HOSTNAME}' is suitable and available, BUT
      2. We recommend you adhere to our naming convention and use the default hostname '${CT_HOSTNAME_VAR}'. Your hostname '${CT_HOSTNAME}' can be used but is irregular.
      
      Proceed with caution - you have been advised."
      while true; do
        read -p "Accept your non-standard CT hostname '${CT_HOSTNAME}' [y/n]?: " -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            info "CT hostname is set: ${YELLOW}${CT_HOSTNAME}${NC} (non-standard)"
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
    fi
  done


  # Set PVE CT IP Function
  msg "Setting ${CT_HOSTNAME^} CT IPv4 address..."
  while true; do
    read -p "Enter a CT IPv4 address: " -e -i ${CT_IP_VAR} CT_IP
    msg "Performing checks on your input (be patient, may take a while)..."
    if [ $(valid_ip ${CT_IP} > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 "${CT_IP}" > /dev/null; echo $?) != 0 ] && [ $(grep -R 'net[0-9]*' /etc/pve/lxc/ | grep -oP '(?<=ip=).+?(?=,)' | sed 's/\/.*//' | grep "${CT_IP}"  > /dev/null; echo $?) != 0 ] && [ "$(echo "${CT_IP}" | sed  's/\/.*//g' | awk -F"." '{print $3}')" = "${CT_TAG_VAR}" ]; then
      while true; do
        read -p "Is your LAN network VLAN ready ( L2/L3 switches ) [y/n]?: " -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            info "'${CT_HOSTNAME^}' CT IPv4 address is set: ${YELLOW}${CT_IP}${NC}"
            CT_TAG=${CT_TAG_VAR}
            VLAN_READY=0
            echo
            break 2
            ;;
          [Nn]*)
            msg "Then use a VLAN1 IPv4 address ( i.e 192.168.${GREEN}1${NC}.XXX ). Try again..."
            VLAN_READY=1
            echo
            break
            ;;
          *)
            warn "Error! Entry must be 'y' or 'n'. Try again..."
            echo
            ;;
        esac
      done
    elif [ $(valid_ip ${CT_IP} > /dev/null; echo $?) != 0 ]; then
      warn "There are problems with your input:
      
      1. The IP address is incorrectly formatted. It must be in the IPv4 format, quad-dotted octet format (i.e xxx.xxx.xxx.xxx ).
      
      Try again..."
      echo
    elif [ $(valid_ip ${CT_IP} > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 ${CT_IP} > /dev/null; echo $?) == 0 ] && [ $(grep -R 'net[0-9]*' /etc/pve/lxc/ | grep -oP '(?<=ip=).+?(?=,)' | sed 's/\/.*//' | grep "${CT_IP}"  > /dev/null; echo $?) = 1 ]; then
      warn "There are problems with your input:
      
      1. The IP address meets the IPv4 standard,
      2. The IP is not assigned to another PVE CT, BUT
      3. The IP address $(echo "${CT_IP}" | sed  's/\/.*//g') is already in-use by another device on your your LAN.
      
      Try again..."
      echo
    elif [ $(valid_ip ${CT_IP} > /dev/null; echo $?) == 0 ] && [ $(grep -R 'net[0-9]*' /etc/pve/lxc/ | grep -oP '(?<=ip=).+?(?=,)' | sed 's/\/.*//' | grep "${CT_IP}"  > /dev/null; echo $?) = 0 ]; then
      warn "There are problems with your input:
      
      1. The IP address meets the IPv4 standard, BUT
      2. The IP is already assigned to another PVE CT.
      
      Try again..."
      echo
    elif [ $(valid_ip ${CT_IP} > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 ${CT_IP} > /dev/null; echo $?) != 0 ] && [ $(echo "${CT_IP}" | awk -F'.' '{print $3}') == 1 ] && [ $(grep -R 'net[0-9]*' /etc/pve/lxc/ | grep -oP '(?<=ip=).+?(?=,)' | sed 's/\/.*//' | grep "${CT_IP}"  > /dev/null; echo $?) = 1 ]; then
      warn "There maybe issues with your input:
      
      1. The IP address meets the IPv4 standard,
      2. The IP is not assigned to another PVE CT,
      3. The IP address $(echo "${CT_IP}" | sed  's/\/.*//g') is not in use (available), BUT
      4. We recommended VLAN${CT_TAG_VAR} for your new CT with a IPv4 address of ${CT_IP_VAR}. Your change to VLAN$(echo ${CT_IP} | sed  's/\/.*//g' | awk -F"." '{print $3}') and IP ${CT_IP} is still workable. This should work if your LAN network is not VLAN ready (no VLAN support).
      
      Proceed with caution - you have been advised."
      echo
      while true; do
        read -p "Accept your IPv4 address '${CT_IP}' [y/n]?: " -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            info "${CT_HOSTNAME^} CT IPv4 address is set: ${YELLOW}${CT_IP}${NC} (no VLAN)"
            CT_TAG=1
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
    elif [ $(valid_ip ${CT_IP} > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 ${CT_IP} > /dev/null; echo $?) != 0 ] && [ $(grep -R 'net[0-9]*' /etc/pve/lxc/ | grep -oP '(?<=ip=).+?(?=,)' | sed 's/\/.*//' | grep "${CT_IP}"  > /dev/null; echo $?) = 1 ] && [ $(echo ${CT_IP} | awk -F'.' '{print $3}') != "${CT_TAG_VAR}" ] || [ $(echo ${CT_IP} | awk -F'.' '{print $3}') != 1 ]; then
      warn "There are serious issues with your input:
      
      1. The IP address meets the IPv4 standard,
      2. The IP address $(echo "${CT_IP}" | sed  's/\/.*//g') is not in use (available),
      3. The IP is not assigned to another PVE CT, BUT
      4. We recommended VLAN${CT_TAG_VAR} for your new CT with a IPv4 address of ${CT_IP_VAR}. Changing to a non-standard VLAN$(echo ${CT_IP} | sed  's/\/.*//g' | awk -F"." '{print $3}') may cause network connectivity issues between your PVE CTs.
      
      Proceed with caution - you have been advised."
      echo
      while true; do
        read -p "Is your LAN network VLAN ready ( L2/L3 switches ) [y/n]?: " -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            while true; do
              read -p "Accept your non-standard IPv4 address '${CT_IP}' [y/n]?: " -n 1 -r YN
              echo
              case $YN in
                [Yy]*)
                  info "${CT_HOSTNAME^} CT IPv4 address is set: ${YELLOW}${CT_IP}${NC} (non-standard)"
                  if [ $(echo ${CT_IP} | sed  's/\/.*//g' | awk -F"." '{print $3}') -gt 1 ]; then
                    CT_TAG=$(echo ${CT_IP} | sed  's/\/.*//g' | awk -F"." '{print $3}')
                  else
                    CT_TAG=1
                  fi
                  echo
                  break 3
                  ;;
                [Nn]*)
                  msg "Try again..."
                  echo
                  break 2
                  ;;
                *)
                  warn "Error! Entry must be 'y' or 'n'. Try again..."
                  echo
                  ;;
              esac
            done
            ;;
          [Nn]*)
            msg "Without knowing your network topology it may best to use a VLAN1 IPv4 address. Try again..."
            echo
            break
            ;;
          *)
            warn "Error! Entry must be 'y' or 'n'. Try again..."
            echo
            ;;
        esac
      done
    fi
  done


  # Set PVE CT Gateway IPv4 Address
  msg "Setting ${CT_HOSTNAME^} CT Gateway IPv4 address..."
  while true; do
    if [ ${CT_IP} = ${CT_IP_VAR} ] && [ $(ping -s 1 -c 2 ${CT_GW_VAR} > /dev/null; echo $?) = 0 ]; then
      CT_GW=${CT_GW_VAR}
      info "${CT_HOSTNAME^} CT Gateway IP is set: ${YELLOW}${CT_GW}${NC}"
      echo
      break
    elif [ $(echo ${CT_IP} | awk -F'.' -v OFS="." '{print $1,$2,$3}') =  $(ip route show | grep default | awk '{print $3}' | awk -F'.' -v OFS="." '{print $1,$2,$3}') ] && [ $(ping -s 1 -c 2 $(ip route show | grep default | awk '{print $3}') > /dev/null; echo $?) = 0 ]; then
      CT_GW=$(ip route show | grep default | awk '{print $3}')
      info "${CT_HOSTNAME^} CT Gateway IP is set: ${YELLOW}${CT_GW}${NC}"
      echo
      break
    elif [ ${CT_IP} != ${CT_IP_VAR} ] || [ $(echo ${CT_IP} | awk -F'.' -v OFS="." '{print $1,$2,$3}') != $(ip route show | grep default | awk '{print $3}' | awk -F'.' -v OFS="." '{print $1,$2,$3}') ]; then
      msg "Because you have chosen to use a non-standard ${CT_HOSTNAME^} CT IP ${WHITE}${CT_IP}${NC} and VLAN setting we cannot determine your Gateway IP address for this CT. You must manually input a working Gateway IPv4 address."
      echo
      read -p "Enter a working Gateway IPv4 address for this CT: " -e -i $(echo ${CT_IP} | awk -F'.' -v OFS="." '{print $1,$2,$3,"xxx"}') CT_GW
      msg "Performing checks on your input (be patient, may take a while)..."
      if [ $(valid_ip ${CT_GW} > /dev/null; echo $?) == 1 ]; then
        warn "There are problems with your input:
        
        1. Your IP address is incorrectly formatted. It must be in the IPv4 format, quad-dotted octet format (i.e xxx.xxx.xxx.xxx ).
        
        Try again..."
        echo
      elif [ $(valid_ip ${CT_GW} > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 ${CT_GW} > /dev/null; echo $?) == 0 ]; then
        info "${CT_HOSTNAME^} Gateway IP is set: ${YELLOW}${CT_GW}${NC}"
        echo
        break
      elif [ $(valid_ip ${CT_GW} > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 ${CT_GW} > /dev/null; echo $?) = 1 ] && [ $(echo ${CT_GW} | cut -d . -f 3) = 30 ] || [ $(echo ${CT_GW} | cut -d . -f 3) = 40 ] && [ $CT_TAG = 30 ] || [ $CT_TAG = 40 ]; then
        info "Your VLAN is set to $CT_TAG which is our default OpenVPN Gateway VLAN.\nWe cannot ping ${CT_GW} which is normal on our OpenVPN Gateway VLANs. So you must\nmanually confirm whether ${CT_GW} is a valid and working network gateway.\n\nProceed with caution - you have been advised."
        echo
        while true; do
          read -p "Confirm '${CT_GW}' is a valid Gateway IP address for ${CT_HOSTNAME^} [y/n]?: " -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              info "${CT_HOSTNAME^} Gateway IP is set: ${YELLOW}${CT_GW}${NC}"
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
      elif [ $(valid_ip ${CT_GW} > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 ${CT_GW} > /dev/null; echo $?) = 1 ]; then
        warn "There are problems with your input:
        
        1. The IP address meets the IPv4 standard, BUT
        2. The IP address ${CT_GW} is NOT reachable (cannot ping).
        
        Try again..."
        echo
      fi
    fi
  done

  # Set DNS Server
  msg "Setting ${CT_HOSTNAME^} DNS Server IPv4 address..."
  while true; do
    if [ ${CT_IP} = ${CT_IP_VAR} ] && [ $(ping -s 1 -c 2 ${CT_DNS_SERVER_VAR} > /dev/null; echo $?) = 0 ]; then
      CT_DNS_SERVER=${CT_DNS_SERVER_VAR}
      info "${CT_HOSTNAME^} CT DNS IP is set: ${YELLOW}${CT_DNS_SERVER}${NC}"
      echo
      break
    elif [ $(echo ${CT_IP} | awk -F'.' -v OFS="." '{print $1,$2,$3}') =  $(ip route show | grep default | awk '{print $3}' | awk -F'.' -v OFS="." '{print $1,$2,$3}') ] && [ $(ping -s 1 -c 2 $(ip route show | grep default | awk '{print $3}') > /dev/null; echo $?) = 0 ]; then
      CT_DNS_SERVER=$(ip route show | grep default | awk '{print $3}')
      info "${CT_HOSTNAME^} CT DNS IP is set: ${YELLOW}${CT_DNS_SERVER}${NC}"
      echo
      break
    elif [ ${CT_IP} != ${CT_IP_VAR} ] || [ $(echo ${CT_IP} | awk -F'.' -v OFS="." '{print $1,$2,$3}') != $(ip route show | grep default | awk '{print $3}' | awk -F'.' -v OFS="." '{print $1,$2,$3}') ]; then
      msg "Because you have chosen to use a non-standard ${CT_HOSTNAME^} CT IP '${CT_IP}' and VLAN setting we cannot determine your DNS IP address for this CT. You must manually input a working DNS IPv4 address."
      echo
      read -p "Enter a working DNS IPv4 address for this CT: " -e -i $(echo ${CT_IP} | awk -F'.' -v OFS="." '{print $1,$2,$3,"xxx"}') CT_DNS_SERVER
      msg "Performing checks on your input (be patient, may take a while)..."
      if [ $(valid_ip ${CT_DNS_SERVER} > /dev/null; echo $?) == 1 ]; then
        warn "There are problems with your input:
        
        1. Your IP address is incorrectly formatted. It must be in the IPv4 format, quad-dotted octet format (i.e xxx.xxx.xxx.xxx ).
        
        Try again..."
        echo
      elif [ $(valid_ip ${CT_DNS_SERVER} > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 ${CT_DNS_SERVER} > /dev/null; echo $?) == 0 ]; then
        info "${CT_HOSTNAME^} DNS IP is set: ${YELLOW}${CT_DNS_SERVER}${NC}"
        echo
        break
      elif [ $(valid_ip ${CT_DNS_SERVER} > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 ${CT_DNS_SERVER} > /dev/null; echo $?) = 1 ] && [ $(echo ${CT_DNS_SERVER} | cut -d . -f 3) = 30 ] || [ $(echo ${CT_DNS_SERVER} | cut -d . -f 3) = 40 ] && [ $CT_TAG = 30 ] || [ $CT_TAG = 40 ]; then
        info "Your VLAN is set to $CT_TAG which is our default OpenVPN Gateway VLAN.\nWe cannot ping ${CT_DNS_SERVER} which is normal on our OpenVPN Gateway VLANs. So you must\nmanually confirm whether ${CT_DNS_SERVER} is a valid and working network DNS.\n\nProceed with caution - you have been advised."
        echo
        while true; do
          read -p "Confirm ${CT_DNS_SERVER} is the DNS IP address for '${CT_HOSTNAME^}' [y/n]?: " -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              info "${CT_HOSTNAME^} DNS IP is set: ${YELLOW}${CT_DNS_SERVER}${NC}"
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
      elif [ $(valid_ip ${CT_DNS_SERVER} > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 ${CT_DNS_SERVER} > /dev/null; echo $?) = 1 ]; then
        warn "There are problems with your input:\n1. The IP address meets the IPv4 standard, BUT\n2. The IP address ${CT_DNS_SERVER} is NOT reachable (cannot ping).\n\nTry again..."
        echo
      fi
    fi
  done

  # Set PVE CT ID
  msg "Setting ${CT_HOSTNAME^} CT container CTID..."
  while true; do
    if [ $(echo ${CT_IP} | awk -F'.' '{print $4}') -ge 100 ]; then
      CTID_VAR=$(echo ${CT_IP} | awk -F'.' '{print $4}')
      msg "Proxmox CTID numeric IDs must be greater than 100. Our PVE CTID numeric ID system uses the last octet or host section value of your ${CT_HOSTNAME_VAR^} CT IPv4 address to calculate a valid CTID."
      if [ "$(pct_list | grep -w ${CTID_VAR} > /dev/null; echo $?)" != 0 ]; then
        CTID=${CTID_VAR}
        info "${CT_HOSTNAME^} CTID is set: ${YELLOW}${CTID}${NC}"
        echo
        break
      else
        warn "There are problems with your input:
        
        1. PVE CTID numeric ID ${CTID_VAR} is in use by another CT labelled \"$(pct_list | grep -w ${CTID_VAR} | awk -F',' '{print $4}')\".
        
        PVE will auto-generate a valid CTID (press ENTER to accept)."
        read -p "Accept the PVE generated CTID or type a new CTID numeric ID: " -e -i "$(pvesh get /cluster/nextid)" CTID_VAR
        if [ "$(pct_list | grep -w ${CTID_VAR} > /dev/null; echo $?)" != 0 ]; then
          CTID=${CTID_VAR}
          info "${CT_HOSTNAME^} CTID is set: ${YELLOW}${CTID}${NC}"
          echo
          break
        else
          warn " There are problems with your input:
          1. PVE CTID numeric ID ${CTID_VAR} is also in use by another CT labelled '$(pct_list | grep -w ${CTID_VAR} | awk -F',' '{print $4}')'.
          
          Try again..."
          echo
        fi
      fi
    elif [ $(echo ${CT_IP} | awk -F'.' '{print $4}') -lt 100 ]; then
      CTID_VAR="$(( $(echo ${CT_IP} | awk -F'.' '{print $4}') + 100 ))"
      msg "Proxmox CTID numeric IDs must be greater than 100. Our PVE CTID numeric ID system uses the last octet or host section value of your CT IPv4 address to calculate a valid CTID. Because your CT IP last octet value $(echo "${CT_IP}" | awk  -F'.' -v OFS="." '{print $1, $2, $3, "\033[1;37m"$4"\033[0m"}') is outside the PVE range, 100 units will be added to the value ($(( $(echo ${CT_IP} | awk -F'.' '{print $4}') + 100 )))."
      echo
      msg "Performing PVE PCT check on CTID ${CTID_VAR}..."
      if [ "$(pct_list | grep -w ${CTID_VAR} > /dev/null; echo $?)" != 0 ]; then
        CTID=${CTID_VAR}
        info "${CT_HOSTNAME^} CTID is set: ${YELLOW}${CTID}${NC}"
        echo
        break
      else
        warn "There are problems with your input:
        
        1. PVE CTID numeric ID ${CTID_VAR} is in use by another CT labelled \"$(pct_list | grep -w ${CTID_VAR} | awk -F',' '{print $4}')\".
        
        PVE will auto-generate a valid CTID (press ENTER to accept)."
        read -p "Accept the PVE generated CTID or type a new CTID numeric ID: " -e -i "$(pvesh get /cluster/nextid)" CTID_VAR
        if [ "$(pct_list | grep -w ${CTID_VAR} > /dev/null; echo $?)" != 0 ] && [[ ${CTID_VAR} =~ ${R_NUM} ]] && [ ${CTID_VAR} -gt 100 ]; then
          CTID=${CTID_VAR}
          info "${CT_HOSTNAME^} CTID is set: ${YELLOW}${CTID}${NC}"
          echo
          break
        elif [ "$(pct_list | grep -w ${CTID_VAR} > /dev/null; echo $?)" = 0 ] && [[ ${CTID_VAR} =~ ${R_NUM} ]] && [ ${CTID_VAR} -gt 100 ]; then
          warn "There are problems with your input:
          
          1. Your input is not valid.
          2. PVE CTID numeric ID ${CTID_VAR} is also in use by another CT labelled \"$(pct_list | grep -w ${CTID_VAR} | awk -F',' '{print $4}')\".
          
          Try again..."
          echo
        elif [ "$(pct_list | grep -w ${CTID_VAR} > /dev/null; echo $?)" != 0 ] && ! [[ ${CTID_VAR} =~ ${R_NUM} ]] && [ ${CTID_VAR} -gt 100 ]; then
          warn "There are problems with your input:
          
          1. Your input is not valid.
          2. PVE CTID must contain only numerals (numbers).
          
          Try again..."
          echo
        elif [ "$(pct_list | grep -w ${CTID_VAR} > /dev/null; echo $?)" != 0 ] && [[ ${CTID_VAR} =~ ${R_NUM} ]] && [ ${CTID_VAR} -le 100 ]; then
          warn "There are problems with your input:
          
          1. Your input is not valid.
          2. PVE CTID is outside the PVE range.
          3. PVE CTID must be of value above 100.
          
          Try again..."
          echo
        fi
      fi     
    fi
  done

  # Set CT Disk Size
  while true; do
    read -p "Enter CT Disk Size (GiB): " -e -i ${CT_DISK_SIZE_VAR} CT_DISK_SIZE
    if [[ ${CT_DISK_SIZE} =~ ${R_NUM} ]] ; then
      info "CT virtual disk is set: ${YELLOW}${CT_DISK_SIZE} GiB${NC}."
      echo
      break
    else
      warn "There are problems with your input:\n    1. Your input is not valid. Input only numerals (numbers).\n\n    Try again..."
      echo
    fi
  done

  # Set CT Memory (RAM)
  while true; do
    read -p "Enter CT RAM memory to be allocated (MiB): " -e -i ${CT_RAM_VAR} CT_RAM
    if [[ ${CT_RAM} =~ ${R_NUM} ]] ; then
      info "CT virtual disk is set: ${YELLOW}${CT_RAM} MiB${NC}."
      echo
      break
    else
      warn "There are problems with your input:\n    1. Your input is not valid. Input only numerals (numbers).\n\n    Try again..."
      echo
    fi
  done

  # Set CT SSHd Port
  if [ ${SSH_ENABLE} = 0 ]; then
    while true; do
      read -p "Enter a CT SSHd Port number: " -e -i ${SSH_PORT_VAR} SSH_PORT
      if [[ ${SSH_PORT} =~ ${R_NUM} ]] ; then
        info "CT SSHd port is set: ${YELLOW}${SSH_PORT}${NC}."
        echo
        break
      else
        warn "There are problems with your input:\n    1. Your input is not valid. Input only numerals (numbers).\n\n    Try again..."
        echo
      fi
    done
  fi

  # Set PVE CT Bind Mount Function
  # PVE default scan
  touch pvesm_input_list # create a empty input file 
  if [ $(cat pvesm_required_list | awk -F'|' '{print $1}' | grep -v 'none' | wc -l) -ge 1 ]; then
    cat pvesm_required_list | awk -F'|' '{print $1}' | grep -v 'none' > pvesm_required_list_input
    if [ -f pvesm_input_list_default_var01 ]; then rm pvesm_input_list_default_var01; fi
    while read -r line; do
        if [[ $(pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-$line") ]]; then
          pvesm status | grep -v 'local' | grep -wEi "^${FUNC_NAS_HOSTNAME}\-[0-9]+\-$line" | awk '{print $1}' | sed "s/$/ \/mnt\/$line/" >> pvesm_input_list_default_var01
        fi
    done < pvesm_required_list_input
    if [[ ! $(comm -23 <(sort -u <<< $(cat pvesm_required_list | grep -vi 'none' | awk -F'|' '{print $1}')) <(sort -u <<< $(cat pvesm_input_list_default_var01 | awk '{print $2}' | sed 's/\/mnt\///'))) ]]; then
      msg "Performing PVE host storage mount scan..."
      PVESM_INPUT=0
      cp pvesm_input_list_default_var01 pvesm_input_list
      msg "Easy Script has detected a default set of PVE storage folders. Proceeding with the following CT bind mounts:"
      echo
      i=1
      while read -r var1 var2; do
        msg "    $i) Auto assigned and set: $var1 ${WHITE}--->${NC} $var2"
        ((i=i+1))
      done < pvesm_input_list_default_var01
      echo
    else
      PVESM_INPUT=1
    fi
    if [ ${PVESM_INPUT} = 1 ]; then
      # PVE host scan
      msg "Performing PVE host storage mount scan..."
      msg "Easy Script is scanning your PVE host. Your PVE storage mounts are listed below:"
      echo
      i=1
      while read -r line; do
        if [[ $(pvesm status | grep -v 'local' | grep -wEi "^.*\-.*\-$line") ]]; then
          msg "    $i) Auto assigned and set: $(pvesm status | grep -v 'local' | grep -wE "^.*\-.*\-$line" | awk '{print $1}') ${WHITE}--->${NC} /mnt/$line"
          pvesm status | grep -v 'local' | grep -wEi "^.*\-.*\-$line" | awk '{print $1}' | sed "s/$/ \/mnt\/$line/" >> pvesm_input_list_var01
        else
          msg "    $i) PVE storage mount '$line' is: ${RED}missing${NC}"
        fi
        ((i=i+1))
      done < pvesm_required_list_input
      echo
      if [[ ! $(comm -23 <(sort -u < pvesm_required_list_input) <(sort -u <<< $(cat pvesm_input_list_var01 | awk '{print $2}' | sed 's/\/mnt\///'))) ]]; then
        while true; do
          read -p "Confirm the PVE storage mount assignments are correct [y/n]?: " -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              cp pvesm_input_list_var01 pvesm_input_list
              PVESM_MANUAL_ASSIGN=1
              info "${CT_HOSTNAME^} CT storage mount points status: ${YELLOW}set${NC}"
              echo
              break
              ;;
            [Nn]*)
              PVESM_MANUAL_ASSIGN=0
              echo
              break
              ;;
            *)
              warn "Error! Entry must be 'y' or 'n'. Try again..."
              echo
              ;;
          esac
        done
      fi
      if [[ $(comm -23 <(sort -u < pvesm_required_list_input) <(sort -u <<< $(cat pvesm_input_list_var01 | awk '{print $2}' | sed 's/\/mnt\///'))) ]] || [ ${PVESM_MANUAL_ASSIGN} = 0 ]; then
        msg "We cannot match and assign all of the required PVE storage mounts. You have two options:\n\n1)  Proceed and manually assign a media type for each available PVESM storage mount. This works when your PVE host storage mounts exist but they have non-standard label names causing Easy Script to fail. Note - you MUST have all $(cat pvesm_required_list | wc -l)x media types available $(cat pvesm_required_list_input | tr '\n' ',' | sed 's/,$//' | sed -e 's/^/(/g' -e 's/$/)/g') on your PVE host to create a $SECTION_HEAD CT.\n\n2)  Abort this installation by entering 'n' at the next prompt.\n\nIf you choose to abort then use the PVE Web Management interface storage manager setup tool to create any missing PVE storage mounts: ${WHITE}https://$(hostname -i):8006${NC}"
        echo
        while true; do
          read -p "Manually assign a media type to your PVE storage mounts [y/n]?: " -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              # Manual Assign PVE host storage mounts
              mapfile -t options <<< $(cat pvesm_required_list | grep -v 'none' | sed -e '1i\'"${PVESM_NONE}"'' | sed -e '$a\'"${PVESM_EXIT}"'' | awk -F'|' '{print "\033[1;33m"toupper($1)"\033[0m","-",$2}')
              while IFS= read -r line
              do
                PS3="Select the media type for PVE storage mount ${WHITE}$line${NC} (entering numeric) : "
                select media_type in "${options[@]}"; do
                echo
                if [[ "$(echo $media_type| awk '{print $1}' | tr [:upper:] [:lower:])" == *"$(echo ${PVESM_EXIT} | awk -F'|' '{print $1}' | tr [:upper:] [:lower:])"* ]]; then
                  info "You have chosen to finish and exit this task. No more mount points to add."
                  while true; do
                    read -p "Are you sure [y/n]?: " -n 1 -r YN
                    echo
                    case $YN in
                      [Yy]*)
                        echo
                        break 3
                        ;;
                      [Nn]*)
                        echo
                        break
                        ;;
                      *)
                        warn "Error! Entry must be 'y' or 'n'. Try again..."
                        echo
                        ;;
                    esac
                  done
                else
                  msg "You have assigned and set: '$line' ${WHITE}--->${NC} '$(echo ${media_type,,} | awk -F' - ' '{print $1}' | sed 's/\x1b\[[^\x1b]*m//g')'"
                fi
                while true; do
                  read -p "Confirm your setting is correct [y/n]?: " -n 1 -r YN
                  echo
                  case $YN in
                    [Yy]*)
                      echo $line /mnt/$(echo ${media_type,,} | awk '{print $1}' | sed "s/\x1B\[\([0-9]\{1,2\}\(;[0-9]\{1,2\}\)\?\)\?[mGK]//g") >> pvesm_input_list_var02
                      echo
                      break 2
                      ;;
                    [Nn]*)
                      msg "No problem. Try again..."
                      echo
                      break
                      ;;
                    *)
                      warn "Error! Entry must be 'y' or 'n'. Try again..."
                      echo
                      ;;
                  esac
                done
                done < /dev/tty
                if [[ "$(echo $media_type | awk '{print $1}' | tr [:upper:] [:lower:])" == *"$(echo ${PVESM_EXIT} | awk -F'|' '{print $1}' | tr [:upper:] [:lower:])"* ]]; then
                  break 2
                fi
              done <<< $(pvesm status | grep -v 'local' | awk 'NR>1 {print $1}')
              # Remove none
              sed -i "/$(echo ${PVESM_NONE} | awk -F'|' '{print $1}')/d" pvesm_input_list_var02
              # Check if manual inputs are correct
              if [[ $(comm -23 <(sort -u < pvesm_required_list_input) <(sort -u <<< $(cat pvesm_input_list_var02 | awk '{print $2}' | sed 's/\/mnt\///'))) ]]; then
                # List missing PVE Storage mounts
                msg "There are problems with your input:"
                echo
                i=1
                while IFS= read -r line; do
                  msg "     $i) PVE storage mount '$line' is: ${RED}missing${NC}"
                  ((i=i+1))
                done <<< $(comm -23 <(sort -u < pvesm_required_list_input) <(sort -u <<< $(cat pvesm_input_list_var02 | awk '{print $2}' | sed 's/\/mnt\///')))
                echo
                msg "The PVE host is missing some required storage mounts. We cannot continue. Go to your Proxmox Web Management interface storage manager ( ${WHITE}https://$(hostname -i):8006${NC} ) and create all of the following PVE storage mounts ( be smart, label them exactly as shown below - replacing NAS appliance identifier, nas-0X, with for example nas-01 ):"
                echo
                i=1
                while IFS= read -r line; do
                  msg "    $i) 'nas-0X-$(echo $line | awk -F'|' '{print $1}')' <---  $(echo $line | awk -F'|' '{print $2}')"
                  ((i=i+1))
                done < pvesm_required_list_input
                echo
                msg "After you have created the above PVE storage mounts run this Easy Script installation again. Aborting in 2 seconds..."
                echo
                sleep 1
                trap cleanup EXIT
              else
                cp pvesm_input_list_var02 pvesm_input_list
                msg "Proceeding with the following CT bind mounts:"
                echo
                i=1
                while read -r var1 var2; do
                  msg "    $i) Assigned and set: $var1 ${WHITE}--->${NC} $var2"
                  ((i=i+1))
                done < pvesm_input_list
                echo
              fi
              break
              ;;
            [Nn]*)
              msg "Good choice. Fix the issue and try again..."
              echo
              sleep 1
              trap cleanup EXIT
              break
              ;;
            *)
              warn "Error! Entry must be 'y' or 'n'. Try again..."
              echo
              ;;
          esac
        done
      fi
    fi
  fi
fi