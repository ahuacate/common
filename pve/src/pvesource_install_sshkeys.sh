#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_install_sshkeys.sh
# Description:  Source script for uploading or generating SSK keys
#               Script works with PVE hosts and CTs (LXC)
# ----------------------------------------------------------------------------------
#
# Instructions how to use:
# If you set a CTID variable the script is set for PVE CT users accounts only. If no
# CTID variable is set then the script is set for host machine users only.
# The script should only run after the creation of Linux user accounts - not before.
#
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Check SMTP Status
check_pvesmtp_status

if [ -n "${CTID}" ]; then
  # Install linux libuser
  if [ $(pct exec $CTID -- dpkg -s libuser >/dev/null 2>&1; echo $?) = 0 ]; then
    msg "Checking libuser status..."
    info "libuser status: ${GREEN}installed${NC}"
    echo
  else
    msg "Installing libuser..."
    pct exec $CTID -- apt-get install libuser -y >/dev/null
    if [ $(pct exec $CTID -- dpkg -s libuser >/dev/null 2>&1; echo $?) = 0 ]; then
      info "libuser status: ${GREEN}installed${NC}"
    fi
    echo
  fi
else
  # Install linux libuser
  if [ $(dpkg -s libuser >/dev/null 2>&1; echo $?) = 0 ]; then
    msg "Checking libuser status..."
    info "libuser status: ${GREEN}installed${NC}"
    echo
  else
    msg "Installing libuser..."
    apt-get install -y libuser >/dev/null
    if [ $(dpkg -s libuser >/dev/null 2>&1; echo $?) = 0 ]; then
      info "libuser status: ${GREEN}installed${NC}"
    fi
    echo
  fi
fi

# Install Puttytools
if [ $(dpkg -s putty-tools >/dev/null 2>&1; echo $?) = 0 ]; then
  msg "Putty-Tools status..."
  info "Putty-Tools status: ${GREEN}installed${NC}"
  echo
else
  msg "Installing Putty Tools..."
  apt-get install -y putty-tools >/dev/null
  info "Putty-Tools status: ${GREEN}installed${NC}"
  echo
fi

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# Linux Group check list
unset group_user_check_LIST
group_user_check_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ ^\#.*$ ]] && continue
  group_user_check_LIST+=( "$line" )
done << EOF
# Example
root
users
medialab
homelab
privatelab
EOF

#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Set HOSTNAME VAR
if [ ! -n "$HOSTNAME" ]; then
  HOSTNAME=$(hostname)
fi

#---- Select SSH key type
section "Configuring SSH Authorized Keys"

msg_box "#### ${HOSTNAME^} SSH Keys ####\n
We recommend you harden your security with SSH key access for hostname '${HOSTNAME^}'. Your options are:

  --  add an existing public SSH key
  --  generate a new SSH RSA key pair"

# Select a key method
msg "Select a SSH key method..."
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Existing SSH Key - Append or add an existing SSH Public Key to the host" "Create new SSH Keys - Generate a new set of SSH key pairs" "None. I do not want to configure SSH key access")
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"
if [ ${RESULTS} == TYPE01 ]; then
  SSH_TYPE=TYPE01
elif [ ${RESULTS} == TYPE02 ]; then
  SSH_TYPE=TYPE02
elif [ ${RESULTS} == TYPE00 ]; then
  SSH_TYPE=TYPE00
  msg "You have chosen not to configure SSH key access. Skipping this step..."
  echo
  return
fi


#---- Select Username to apply SSH key access
section "Select usernames to apply SSH key access"

# Create available username list
if [ -n "${CTID}" ]; then
  # Check user list (CT)
  user_check_LIST=()
  while IFS='' read -r grp; do
    if [ $(pct exec $CTID -- getent group ${grp}) ]; then
      user_check_LIST+=( $(pct exec $CTID -- libuser-lid -g ${grp} 2>/dev/null | sed "s/([^)]*)//g" | sed 's/^ //g') )
    fi
  done <<< $(printf '%s\n' "${group_user_check_LIST[@]}")
  # Create User list (CT)
  user_LIST=()
  while IFS='' read -r user; do
    user_LIST+=( ${user},$(pct exec $CTID -- getent passwd | grep ^${user} | cut -d: -f6),ct )
  done <<< $(printf '%s\n' "${user_check_LIST[@]}")
else
  # Check user list (host)
  user_check_LIST=()
  while IFS='' read -r grp; do
    if [ $(getent group ${grp}) ]; then
      user_check_LIST+=( $(libuser-lid -g ${grp} 2>/dev/null | sed "s/([^)]*)//g" | sed 's/^ //g') )
    fi
  done <<< $(printf '%s\n' "${group_user_check_LIST[@]}")
  # Create User list (host)
  user_LIST=()
  while IFS='' read -r user; do
    user_LIST+=( ${user},$(getent passwd | grep ^${user} | cut -d: -f6),ct )
  done <<< $(printf '%s\n' "${user_check_LIST[@]}")
fi


# Make user selection
if [ ${#user_LIST[@]} == 1 ]; then
  # SSH user list (one only)
  ssh_user_LIST=$(printf '%s\n' "${user_LIST[@]}")
  msg "Select the ${HOSTNAME^} user accounts which you want to configure SSH key access..."
  info "Only a single user available: ${Yellow}$(printf '%s\n' "${user_LIST[@]}" | awk -F',' '{ print $1 }')${NC}"
  echo
else
  # SSH user list
  msg "Select ${HOSTNAME^} user accounts which you want to configure SSH key access. All selected user accounts will use the same SSH key pair. If you want private user SSH key pairs then you must configure each user manually. NOW select your user accounts..."
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${user_LIST[@]}" | awk -F',' '{ print $1 }')
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${user_LIST[@]}")
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  multiselect_confirm SELECTED "$OPTIONS_STRING"
  # Create input disk list array
  ssh_user_LIST=()
  for i in "${RESULTS[@]}"; do
    ssh_user_LIST+=( $(echo $i) )
  done
fi


#---- Add/Upload a existing SSH public key
if [ ${SSH_TYPE} = "TYPE01" ]; then
  section "Add an existing SSH Public Key"
  while true; do
    msg "You have chosen to use an existing SSH Public Key for ${HOSTNAME^}. Pay strict attention to the next sequence of steps. First you copy the contents of your ${UNDERLINE}SSH Public Key${NC} file into your computer clipboard. Make sure its your ${UNDERLINE}SSH Public Key${NC}, NOT your private key!

    --  COPY YOUR SSH PUBLIC KEY CONTENTS
          1. Open your SSH Public Key file in a text editor ( such as Notepad++ ).
          2. Highlight the key contents only ( Ctrl + A ).
          3. Copy the highlighted contents to your computer clipboard ( Ctrl + C ).
    --  PASTE YOUR SSH PUBLIC KEY CONTENTS
          1. Mouse Right-Click when you are prompted ( > ).\n"
    sleep 3
    echo
    read -r -p "Paste your SSH Public Key at the prompt then press ENTER: `echo $'\n> '`" INPUTLINE_PUBLIC_KEY
    msg_box "$(printf '%s\n' ${INPUTLINE_PUBLIC_KEY} | fold -s -w 75)"
    while true; do
      read -p "Confirm your input is correct [y/n]?: " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          KEY_FORMAT=$(ssh-keygen -lf /dev/stdin  <<<${INPUTLINE_PUBLIC_KEY} | awk '{print tolower($NF)}' | sed 's/[()]//g')
          echo ${INPUTLINE_PUBLIC_KEY} > id_${HOSTNAME,,}_${KEY_FORMAT}.pub
          info "The SSH Public Key has been accepted."
          echo
          break 2
          ;;
        [Nn]*)
          info "Try again..."
          echo
          break
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  done
fi

#---- Generate a new set of SSH RSA Key pairs
if [ ${SSH_TYPE} = "TYPE02" ]; then
  section "Generate new SSH Key pairs"

  # SSH key format
  msg "Select a SSH key format..."
  OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" )
  OPTIONS_LABELS_INPUT=( "Ed25519 - Cryptographic strength & fast (Recommended)" \
  "RSA 4096 - Wide support, wide compatibility, slow" )
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"
  if [ ${RESULTS} == TYPE01 ]; then
    KEY_FORMAT=ed25519
    KEY_BITS=''
  elif [ ${RESULTS} == TYPE02 ]; then
    KEY_FORMAT=rsa
    KEY_BITS=4096
  fi

  # Set key backup location
  NOW=$(date +"%m-%d-%Y_%H%M%S")
  if [[ $(df -h | awk 'NR>1 { print $1, "mounted on", $NF }' | grep "/mnt/pve/.*backup") ]]; then
    msg "--  BACKUP LOCATION OF SSH PUBLIC KEY FILES
        NAS file location: ${WHITE}$(df -h | awk 'NR>1 { print $1, $NF }' | grep "/mnt/pve/.*backup" | awk '{ print $1}')/${HOSTNAME,,}/${HOSTNAME,,}_${NOW}_ssh_keys.tar.gz${NC}
        PVE file location: ${WHITE}$(df -h | awk 'NR>1 { print $1, $NF }' | grep "/mnt/pve/.*backup" | awk '{ print $NF}')/${HOSTNAME,,}/${HOSTNAME,,}_${NOW}_ssh_keys.tar.gz${NC}"
    echo
    # Backup Location
    SSH_BACKUP_LOCATION=$(df -h | awk 'NR>1 { print $1, $NF }' | grep "/mnt/pve/.*backup" | awk '{ print $NF}')/${HOSTNAME,,}/ssh_keys
    SSH_BACKUP_FILENAME="${HOSTNAME,,}_${NOW}_ssh_keys.tar.gz"
    mkdir -p "${SSH_BACKUP_LOCATION}" > /dev/null
  elif [[ ! $(df -h | awk 'NR>1 { print $1, "mounted on", $NF }' | grep "/mnt/pve/.*backup") ]]; then
    msg "--  BACKUP LOCATION OF SSH PUBLIC KEY FILES
        Cannot locate a NAS NFS/CIFS backup folder mount point on this PVE host. Using PVE host '/tmp' folder instead. The User should immediately move the backup '/tmp/${HOSTNAME,,}_${NOW}_ssh_keys.tar.gz' to a secure storage location off the PVE host.
        Temporary PVE File Location: ${WHITE}/tmp/${HOSTNAME,,}_${NOW}_ssh_keys.tar.gz${NC}"
    echo
    # Backup Location
    SSH_BACKUP_LOCATION=/tmp
    SSH_BACKUP_FILENAME="${HOSTNAME,,}_${NOW}_ssh_keys.tar.gz"
  fi
  echo
  
  # Check SMTP server status
  msg "Checking PVE host SMTP email server status..."
  EMAIL_RECIPIENT=$(pveum user list | awk -F " │ " '$1 ~ /root@pam/' | awk -F " │ " '{ print $3 }')
  if [ ${SMTP_STATUS} = 1 ]; then
    info "SMTP email status: ${YELLOW}enabled${NC}.\nThe Users SSH key pairs will be sent to: ${YELLOW}${EMAIL_RECIPIENT}${NC}"
    echo
  elif [ ${SMTP_STATUS} = 0 ]; then
    SMTP_STATUS=1
    info "The PVE host SMTP is not configured or working.\nNo SSH key pairs will be sent by email."
    echo
  fi

  # uuencode for Postfix (part of package sharutils)
  if [ ${SMTP_STATUS} = 1 ]; then
    msg "Checking SMTP Postfix email server prerequisites..."
    if [ $(dpkg -s sharutils >/dev/null 2>&1; echo $?) = 0 ]; then
      msg "Checking sharutils (uuencode) status..."
      info "sharutils (uuencode) status: ${GREEN}installed.${NC}"
      echo
    else
      msg "Installing sharutils (uuencode)..."
      apt-get install -y sharutils >/dev/null
      if [ $(dpkg -s sharutils >/dev/null 2>&1; echo $?) = 0 ]; then
        info "sharutils (uuencode) status: ${GREEN}installed.${NC}"
      fi
      echo
    fi
  fi

  # Generating SSH Key Pair
  msg "Generating ${KEY_FORMAT} SSH key pair..."
  ssh-keygen -o -q$(if [ -n "${KEY_BITS}" ]; then echo " -b ${KEY_BITS}"; fi) -t ${KEY_FORMAT} -a 100 -f id_${HOSTNAME,,}_${KEY_FORMAT} -N ""
  # Create ppk key for Putty or Filezilla or ProFTPd
  msg "Creating a private PPK key (for Putty)..."
  puttygen id_${HOSTNAME,,}_${KEY_FORMAT} -o id_${HOSTNAME,,}_${KEY_FORMAT}.ppk
  # Create gz backup of SSH keys
  msg "Creating backup ${WHITE}${SSH_BACKUP_FILENAME}${NC} file of SSH key pairs..."
  tar czf ${SSH_BACKUP_FILENAME} id_${HOSTNAME,,}_${KEY_FORMAT} id_${HOSTNAME,,}_${KEY_FORMAT}.pub id_${HOSTNAME,,}_${KEY_FORMAT}.ppk
  cp ${SSH_BACKUP_FILENAME} ${SSH_BACKUP_LOCATION}

  # Email SSH key pairs
  if [ ${SMTP_STATUS} = 1 ]; then
    msg "Emailing SSH key pairs..."
    echo -e "\n==========   SSH KEYS FOR HOST : ${HOSTNAME^^}   ==========\n\nFor SSH access to host '${HOSTNAME,,}' use the attached SSH Private Key file named id_${HOSTNAME,,}_${KEY_FORMAT}.\n\nYour login credentials details are:\n    Username: root username\n    Password: Not Required (SSH Private Key only).\n    SSH Private Key: id_${HOSTNAME,,}_${KEY_FORMAT}\n    Putty SSH Private Key: id_${HOSTNAME,,}_${KEY_FORMAT}.ppk\n    PVE Server LAN IP Address: ${HOSTNAME,,}.$(hostname -d)\n\nA backup linux tar.gz file containing your SSH Key pairs is also attached.\n    Backup filename of SSH Key Pairs: $SSH_BACKUP_FILENAME\n" | (cat - && uuencode id_${HOSTNAME,,}_${KEY_FORMAT} id_${HOSTNAME,,}_${KEY_FORMAT} ; uuencode id_${HOSTNAME,,}_${KEY_FORMAT}.pub id_${HOSTNAME,,}_${KEY_FORMAT}.pub ; uuencode ${SSH_BACKUP_FILENAME} $SSH_BACKUP_FILENAME) | mail -s "SHH key pairs for host $(echo ${SSH_BACKUP_FILENAME} | awk -F'_' '{ print $1}')." -- $EMAIL_RECIPIENT
    info "SSH key pairs to emailed to: ${YELLOW}$EMAIL_RECIPIENT${NC}"
    echo
  fi

  # Closing Message
  if [ ${SMTP_STATUS} = 1 ]; then
    info "Success. Your new SSH Public Key has been added to host ${HOSTNAME,,}\nauthorized_keys file.\n\n==========   SSH KEYS FOR HOST : ${PVE_HOSTNAME^^}   ==========\n\nFor root access to PVE host ${PVE_HOSTNAME,,} use SSH Private Key\nfile named id_${PVE_HOSTNAME,,}_ed25519.\n\nYour login credentials details are:\n    Username: ${YELLOW}root${NC}\n    Password: Not Required (SSH Private Key only).\n    SSH Private Key: ${YELLOW}id_${PVE_HOSTNAME,,}_ed25519${NC}\n    Putty SSH Private Key: ${YELLOW}id_${PVE_HOSTNAME,,}_ed25519.ppk${NC}\n    PVE Server LAN IP Address: ${YELLOW}$(hostname -I)${NC}\n\nA backup linux tar.gz file containing your SSH Key {pairs has also been} created.\n    Backup filename of SSH Key Pairs: ${YELLOW}${SSH_BACKUP_FILENAME}${NC}\n    Backup of SSH Key Pairs emailed to: ${YELLOW}$EMAIL_RECIPIENT${NC}\n    Backup location for SSH Key Pairs: ${YELLOW}${SSH_BACKUP_LOCATION}/${SSH_BACKUP_FILENAME}${NC}"
    echo
  elif [ ${SMTP_STATUS} = 0 ]; then
    info "Success. Your new SSH Public Key has been added to PVE host ${PVE_HOSTNAME,,}\nauthorized_keys file.\n\n==========   SSH KEYS FOR PVE HOST : ${PVE_HOSTNAME^^}   ==========\n\nFor root access to PVE host ${PVE_HOSTNAME,,} use SSH Private Key\nfile named id_${PVE_HOSTNAME,,}_ed25519.\n\nYour login credentials details are:\n    Username: ${YELLOW}root${NC}\n    Password: Not Required (SSH Private Key only).\n    SSH Private Key: ${YELLOW}id_${PVE_HOSTNAME,,}_ed25519${NC}\n    Putty SSH Private Key: ${YELLOW}id_${PVE_HOSTNAME,,}_ed25519.ppk${NC}\n    PVE Server LAN IP Address: ${YELLOW}$(hostname -I)${NC}\n\nA backup linux tar.gz file containing your SSH Key pairs has also been created.\n    Backup filename of SSH Key Pairs: ${YELLOW}${SSH_BACKUP_FILENAME}${NC}\n    Backup location for SSH Key Pairs: ${YELLOW}${SSH_BACKUP_LOCATION}/${SSH_BACKUP_FILENAME}${NC}"
    echo
  fi
fi

#---- Configure host with new SSH key
while IFS=',' read -r ssh_user ssh_home_dir type; do
  msg "Adding SSH Public Key to user '${ssh_user}'..."
  if [ ${type} = host ]; then
    # Check for .ssh folder
    if [ ! -d ${ssh_home_dir}/.ssh ]; then
      sudo mkdir -p ${ssh_home_dir}/.ssh
      sudo chmod 700 ${ssh_home_dir}/.ssh
    fi
    # Check for .ssh/authorized_keys file
    if [ ! -f ${ssh_home_dir}/.ssh/authorized_keys ]; then
      touch ${ssh_home_dir}/.ssh/authorized_keys
      chmod 600 ${ssh_home_dir}/.ssh/authorized_keys
    fi
    # Add new SSH key to host
    cat id_${HOSTNAME,,}_${KEY_FORMAT}.pub >> ${ssh_home_dir}/.ssh/authorized_keys
    # Configure SSH
    sed -i 's/^[#]*\s*PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/^[#]*\s*StrictModes.*/StrictModes yes/g' /etc/ssh/sshd_config
    sed -i 's/^[#]*\s*MaxAuthTries.*/MaxAuthTries 5/g' /etc/ssh/sshd_config
    # sed -i 's/^[#]*\s*PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config
    # sed -i 's/^[#]*\s*PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config
    systemctl restart sshd
  elif [ ${type} = ct ]; then
    # Check for .ssh folder
    if [ $(pct exec $CTID -- bash -c "[[ ! -d "${ssh_home_dir}" ]] && echo 0") ]; then
      pct exec $CTID -- mkdir -p ${ssh_home_dir}/.ssh
      pct exec $CTID -- chmod 700 ${ssh_home_dir}/.ssh
    fi
    # Check for .ssh/authorized_keys file
    if [ $(pct exec $CTID -- bash -c "[[ ! -f "${ssh_home_dir}/.ssh/authorized_keys" ]] && echo 0") ]; then
      pct exec $CTID -- touch ${ssh_home_dir}/.ssh/authorized_keys
      pct exec $CTID -- chmod 600 ${ssh_home_dir}/.ssh/authorized_keys
    fi
    # Add new SSH key to CT
    pct push $CTID id_${HOSTNAME,,}_${KEY_FORMAT}.pub /tmp/id_${HOSTNAME,,}_${KEY_FORMAT}.pub
    pct exec $CTID -- cat /tmp/id_${HOSTNAME,,}_${KEY_FORMAT}.pub >> ${ssh_home_dir}/.ssh/authorized_keys
    # Configure SSH
    pct exec $CTID -- sed -i 's/^[#]*\s*PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    pct exec $CTID -- sed -i 's/^[#]*\s*StrictModes.*/StrictModes yes/g' /etc/ssh/sshd_config
    pct exec $CTID -- sed -i 's/^[#]*\s*MaxAuthTries.*/MaxAuthTries 5/g' /etc/ssh/sshd_config
    pct exec $CTID -- sed -i 's/^[#]*\s*PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config
    pct exec $CTID -- sed -i 's/^[#]*\s*PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config
    pct exec $CTID -- systemctl restart sshd
  fi
done <<< $(printf '%s\n' "${ssh_user_LIST[@]}")

#---- Finish Line ------------------------------------------------------------------