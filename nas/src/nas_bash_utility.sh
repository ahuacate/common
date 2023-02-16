#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_bash_utility.sh
# Description:  Basic bash functions and args for NAS installer
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Install PVE USB auto mount
function install_usbautomount() {
  # Get PVE version
  pve_vers=$(pveversion -v | grep 'proxmox-ve:*' | awk '{ print $2 }' | sed 's/\..*$//')
  # Get Debian version
  version=$(cat /etc/debian_version)
  if [[ "$version" =~ 11(.[0-9]+)? ]]
  then
    deb_ver_codename="bullseye"
  elif [[ "$version" =~ 10(.[0-9]+)? ]]
  then
    deb_ver_codename="buster"
  elif [[ "$version" =~ 9(.[0-9]+)? ]]
  then
    deb_ver_codename="stretch"
  fi

  # Remove old version
  if [[ $(dpkg -l pve[0-9]-usb-automount 2>/dev/null) ]] && [[ ! $(dpkg -s pve${pve_vers}-usb-automount) ]]
  then
    apt-get remove --purge pve[0-9]-usb-automount -y > /dev/null
    rm /etc/apt/sources.list.d/iteas.list
  fi

  # Install new version
  if [[ ! $(dpkg -s pve${pve_vers}-usb-automount) ]]
  then
    # Add iteas key
    gpg -k && gpg --no-default-keyring --keyring /usr/share/keyrings/iteas-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 23CAE45582EB0928
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/iteas-keyring.gpg] https://apt.iteas.at/iteas $deb_ver_codename main" > /etc/apt/sources.list.d/iteas.list
    apt-get update
    # Install USB automount
    msg "Installing PVE USB automount..."
    apt-get install pve${pve_vers}-usb-automount -y
  fi
}

# Storage Array List
function reset_usb() {
  msg "Resetting USB devices..."
  # USB 3.1 Only
  for port in $(lspci | grep xHCI | cut -d' ' -f1)
  do
    echo -n "0000:$port"| tee /sys/bus/pci/drivers/xhci_hcd/unbind > /dev/null
    sleep 5
    echo -n "0000:$port" | tee /sys/bus/pci/drivers/xhci_hcd/bind > /dev/null
    sleep 5
  done
  # All USB
  for port in $(lspci | grep USB | cut -d' ' -f1); do
    echo -n "0000:$port"| tee /sys/bus/pci/drivers/xhci_hcd/unbind > /dev/null
    sleep 5
    echo -n "0000:$port" | tee /sys/bus/pci/drivers/xhci_hcd/bind > /dev/null
    sleep 5
  done
  echo
}


function storage_list() {
  # 1=PATH:2=KNAME:3=PKNAME (or part cnt.):4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM
  # PVE All Disk array

  #---- Prerequisites

  # Deny system device list (i.e system devices, pools, partitions etc)
  system_dev_tmp_LIST=()
  # System devices by pools
  if [[ $(df -hT | grep /$ | grep -w '^rpool/.*') ]]
  then
    while read -r pool
    do
      if ! [ -b "/dev/disk/by-id/$pool" ]
      then
        continue
      fi
      # Add device to list
      system_dev_tmp_LIST+=( $(readlink -f /dev/disk/by-id/$pool) )
    done < <( zpool status rpool 2> /dev/null | grep -Po "\S*(?=\s*ONLINE|\s*DEGRADED)" )
  fi
  # System devices by /dev/
  if [[ $(df -hT | grep /$ | grep -w '^/dev/.*') ]]
  then
    # Add device to list
    system_dev_tmp_LIST+=( $(df -hT | grep /$ | awk '{print $1}') )
  fi
  # System devices by "df -x tmpfs -x devtmpfs -x debugfs -x fusectl"
  system_dev_tmp_LIST+=( $(df -x tmpfs -x devtmpfs -x debugfs -x fusectl | grep -v -E '(/media/.*|/mnt/.*?)' | awk 'NR>1 {print $1}' | egrep ^/dev/.*) )
  # System devices by PVE mapper
  system_dev_tmp_LIST+=( "/dev/mapper/pve-root" "/dev/mapper/pve-(data|data|vm|lxc|ct|vm|swap).*" )
  # Remove duplicates, create raw devices & make regex
  system_dev_LIST=()
  while read system_dev
  do
    if [[ "$system_dev" =~ ^/dev/sd[a-z]([0-9])?$ ]]
    then
      system_dev_LIST+=( "${system_dev%[0-9]}([0-9])?" )
    elif [[ "$system_dev" =~ ^/dev/nvme[0-9]n[0-9](p[0-9])?$ ]]
    then
      system_dev_LIST+=( "${system_dev%p[0-9]}(p[0-9])?" )
    else
      system_dev_LIST+=( "$system_dev" )
    fi
  done < <( printf '%s\n' "${system_dev_tmp_LIST[@]}" | sort -u )

  # Create all storage list (output file)
  allSTORAGE=()

  # Suppress warnings
  export LVM_SUPPRESS_FD_WARNINGS=1

  #---- Create storage list
  while read -r line
  do
    #---- Set dev
    dev=$(echo "$line" | awk -F':' '{ print $1 }')

    #---- Check physical disk (inc. part parent disks) exists in VM pass-through
    if [[ "$dev" =~ ^/dev/(sd[a-z]|nvme[0-9]n[0-9]) ]]
    then
      # If dev is a part
      if [[ "$dev" =~ ^/dev/(sd[a-z][0-9]$|nvme[0-9]n[0-9]p[0-9]$) ]]
      then
        chk_dev="/dev/$(lsblk $dev -nbr -o PKNAME)"
        tran=$(lsblk $chk_dev -nbr -o TRAN 2> /dev/null)
        by_id=$(ls -l /dev/disk/by-id | grep -E "$tran" | grep -w "$(echo "$chk_dev "| sed 's|^.*/||')" | awk '{ print $9 }')
      else
        chk_dev="$dev"
        tran=$(echo "$line" | awk -F':' '{ print $5 }')
        by_id=$(ls -l /dev/disk/by-id | grep -E "$tran" | grep -w "$(echo "$chk_dev" | sed 's|^.*/||')" | awk '{ print $9 }')
      fi
      # Check for existing disk VM pass-through
      while read -r chk_vmid
      do
        if [[ $(grep -w "/dev/disk/by-id/$by_id" /etc/pve/qemu-server/${chk_vmid}.conf) ]]
        then
          # Create existing VM disk pass-through list (skipped)
          size=$(lsblk -nbrd -o SIZE $chk_dev | awk '{ $1=sprintf("%.0f",$1/(1024^3))"G" } {print $0}')
          model=$(lsblk -nbrd -o MODEL $chk_dev)
          existing_pt_LIST+=( "${chk_vmid}:${tran}:${chk_dev}:${model}:${size}" )
          continue 2
        fi
      done < <( qm list | awk 'BEGIN { FIELDWIDTHS="$fieldwidths"; OFS=":" } { if(NR>1) print $1 }' )
    fi


    #---- Set variables
    # Partition Cnt (Col 3)
    if ! [[ $(echo "$line" | awk -F':' '{ print $3 }') ]] && [[ "$(echo "$line" | awk -F':' '{ if ($1 ~ /^\/dev\/sd[a-z]$/ || $1 ~ /^\/dev\/nvme[0-9]n[0-9]$/) { print "0" } }')" ]]
    then
      # var3=$(partx -g ${dev} | wc -l)
      if [[ $(lsblk $dev | grep part) ]]
      then
        var3=$(lsblk $dev | grep part | wc -l)
      else
        var3=0
      fi
    else
      var3=$(echo "$line" | awk -F':' '{ print $3 }')
    fi

    #---- ZFS_Members (Col 4)
    if ! [[ $(echo $line | awk -F':' '{ print $4 }') ]] && [ "$(lsblk -nbr -o FSTYPE $dev)" = "zfs_member" ] || [ "$(blkid -o value -s TYPE $dev)" = 'zfs_member' ]
    then
      var4='zfs_member'
    else
      var4=$(echo "$line" | awk -F':' '{ print $4 }')
    fi

    # Tran (Col 5)
    if ! [[ $(echo "$line" | awk -F':' '{ print $5 }') ]] && [[ "$dev" =~ ^/dev/(sd[a-z]|nvme[0-9]n[0-9]) ]]
    then
      var5="$(lsblk -nbr -o TRAN /dev/"$(lsblk -nbr -o PKNAME $dev | grep 'sd[a-z]$\|nvme[0-9]n[0-9]$' | uniq | sed '/^$/d')" 2> /dev/null | uniq | sed '/^$/d')"
    elif [[ "$dev" =~ ^/dev/mapper ]] && [ $(lvs $dev &> /dev/null; echo $?) = 0 ]
    then
      vg_var="$(lvs $dev --noheadings -o vg_name | sed 's/ //g')"
      device_var="$(pvs --noheadings -o pv_name,vg_name | sed  's/^[t ]*//g' | grep "$vg_var" | awk '{ print $1 }')"
      if [[ "$device_var" =~ ^/dev/(sd[a-z]$|nvme[0-9]n[0-9]$) ]]
      then
        device=$device_var
      else
        device="/dev/$(lsblk -nbr -o PKNAME $device_var 2> /dev/null | grep 'sd[a-z]$\|nvme[0-9]n[0-9]$' | sed '/^$/d' | uniq)"
      fi
      var5=$(lsblk -nbr -o TRAN $device 2> /dev/null | sed '/^$/d')
    else
      var5=$(echo "$line" | awk -F':' '{ print $5 }')
    fi

    # Size (Col 8)
    var8=$(lsblk -nbrd -o SIZE $dev | awk '{ $1=sprintf("%.0f",$1/(1024^3))"G" } {print $0}')

    # Rota (Col 10)
    if [[ $(hdparm -I $dev 2> /dev/null | awk -F':' '/Nominal Media Rotation Rate/ { print $2 }' | sed 's/ //g') == 'SolidStateDevice' ]]
    then
      var10=0
    else
      var10=1
    fi

    #---- Zpool/LVM VG Name or Cnt (Col 14)
    if [[ $(lsblk $dev -dnbr -o TYPE) == 'disk' ]] && [ ! "$(blkid -o value -s TYPE $dev)" = 'LVM2_member' ]
    then
      cnt=0
      var14=0
      while read -r dev_line
      do
        if [ ! "$(blkid -o value -s TYPE $dev_line)" = 'zfs_member' ] && [ ! "$(blkid -o value -s TYPE $dev_line)" = 'LVM2_member' ]
        then
          continue
        fi
        cnt=$((cnt+1))
        var14=$cnt
      done < <(lsblk -nbr $dev -o PATH)
    elif [ "$(lsblk $dev -dnbr -o TYPE)" = 'part' ] && [ "$(blkid -o value -s TYPE $dev)" = 'zfs_member' ]
    then
      var14=$(blkid -o value -s LABEL $dev)
    elif [[ "$(lsblk $dev -dnbr -o TYPE)" =~ (disk|part) ]] && [ "$(blkid -o value -s TYPE $dev)" = 'LVM2_member' ]
    then
      var14=$(pvs --noheadings -o pv_name,vg_name | sed "s/^[ \t]*//" | grep $dev | awk '{ print $2 }')
    elif [[ "$dev" =~ ^/dev/mapper ]] && [[ ! ${dev} =~ ^/dev/mapper/pve- ]] && [ $(lvs $dev &> /dev/null; echo $?) = 0 ]
    then
      var14=$(lvs $dev --noheadings -a -o vg_name | sed 's/ //g')
    elif [[ "$dev" =~ ^/dev/mapper/pve- ]]; then
      var14=$(echo "$dev" | awk -F'/' '{print $NF}' | sed 's/\-.*$//')
    else
      var14='0'
    fi

    #---- System (Col 15)
    # Create root dev list
    # Set Col 15 var ('1' means root device, '0' is default not root device)
    chk1=0
    chk2=0
    chk3=0
    var15=0
    # Check 1
    if [[ $(fdisk -l $dev 2>/dev/null | grep -Ei '(BIOS boot|EFI System|Linux swap|Linux LVM)' | awk '{ print $1 }') ]]
    then
      chk1=1
    fi
    # Check 2
    for element in "${system_dev_LIST[@]}"
    do
      if [[ "$dev" =~ $element ]]
      then
        chk2=1
      fi
    done
    # Check 3
    if [ "$var14" = 'pve' ]
    then
      chk3=1
    fi
    # Set col15 if any chk are '1'
    if [[ $chk1 -eq 1 || $chk2 -eq 1 || $chk3 -eq 1 ]]
    then
      # Set var (system)
      var15=1
    fi

    #---- Finished Output
    allSTORAGE+=( "$(echo "$line" | awk -F':' -v var3=${var3} -v var4=${var4} -v var5=${var5} -v var8=${var8} -v var10=${var10} -v var14=${var14} -v var15=${var15} 'BEGIN {OFS = FS}{ $3 = var3 } { $4 = var4 } {if ($5 == "") {$5 = var5;}} { $8 = var8 } { $10 = var10 } { $14 = var14 } { $15 = var15 } { print $0 }')" )

  done < <( lsblk -nbr -o PATH,KNAME,PKNAME,FSTYPE,TRAN,MODEL,SERIAL,SIZE,TYPE,ROTA,UUID,RM,LABEL | sed 's/ /:/g' | sed 's/$/:/' | sed 's/$/:0/' | sed '/^$/d' | awk '!a[$0]++' 2> /dev/null )
}


# Working output Storage Array List
function stor_LIST() {
  unset storLIST
  for i in "${allSTORAGE[@]}"
  do
    storLIST+=( $(echo $i) )
  done
}

# Wake USB disk
# function wake_usb() {
#   while IFS= read -r line
#   do
#     dd if=$line of=/dev/null count=512 status=none
#   done < <( lsblk -nbr -o PATH,TRAN | awk '{if ($2 == "usb") print $1 }' )
# }
function wake_usb() {
  udevadm trigger --subsystem-match=usb --action=add
  sleep 2
}


# LVM VG name create
function create_lvm_vgname_val(){
  local option="$1"

  # Sets the validation input type: input_lvm_vgname_val usb
  if [ -z "$option" ]
  then
    vgname_var='_'
  elif [[ ${option,,} =~ 'usb' ]]
  then
    vgname_var='_usb_'
  fi
  # Hostname mod (change any '-' to '_')
  hostname_var=$(echo $(hostname -s) | sed 's/-/_/g')
  # Set new name
  VG_NAME="vg${vgname_var}${hostname_var}"
  if [ "$(vgs ${VG_NAME} &>/dev/null; echo $?)" = 0 ]
  then
    i=1
    while [ "$(vgs ${VG_NAME}_${i} &>/dev/null; echo $?)" = 0 ]
    do
      i=$(( $i + 1 ))
    done
    VG_NAME=${VG_NAME}_${i}
  fi
}

# ZFS file system name validate
function input_zfs_name_val(){
  INPUT_NAME_VAR="$1" # Sets the validation input type: input_zfs_name_val POOL. Types: 'POOL' for ZPool name or 'ZFS_NAME' for ZFS File System name.
  INPUT_NAME_VAR=${INPUT_NAME_VAR^^}
  # Set msg_box text output variable
  if [ "$INPUT_NAME_VAR" = POOL ]
  then
    msg_box "#### PLEASE READ CAREFULLY - SET A ZPOOL NAME ####\n\nWe could not detect a preset name for the new ZPool. A recommended ZPool name would be 'tank' ( use 'usbtank' for USB connected disks ). You can input any name so long as it meets some basic Linux ZFS component constraints."
  elif [ "$INPUT_NAME_VAR" = ZFS_NAME ]
  then
    msg_box "#### PLEASE READ CAREFULLY - SET A ZFS FILE SYSTEM NAME ####\n\nWe could not detect a preset name for the new ZFS File System: /ZPool/?. A recommended ZFS file system name for a PVE CT NAS server would be the NAS hostname ( i.e /Zpool/'nas-01' or /ZPool/'nas-02'). You can input any name so long as it meets some basic Linux ZFS component constraints.$(zfs list -r -H | awk '{ print $1 }' | grep -v "^rpool.*" | grep '.*/.*' | awk '{print "\n\n\tExisting ZFS Storage Systems\n\t--  "$0 }'; echo)"
  fi
  # Set new name
  while true
  do
    read -p "Enter a ZFS component name : " NAME
    NAME=${NAME,,} # Force to lowercase
    if [[ "$NAME" = [Rr][Pp][Oo][Oo][Ll] ]]
    then
      warn "The name '$NAME' is your default root ZFS Storage Pool.\nYou cannot use this. Try again..."
      echo
    elif [ "$(zpool list | grep -w "^$NAME$" >/dev/null; echo $?)" = 0 ]
    then
      warn "The name '${NAME}' is an existing ZPool.\nYou cannot use this name. Try again..."
      echo
    elif [ "$(zfs list | grep -w ".*/${NAME}.*" >/dev/null; echo $?)" = 0 ]
    then
      if [ "$INPUT_NAME_VAR" = POOL ]
      then
        info "The name '$NAME' is an existing ZFS file system.\nYou cannot use this name. Try again..."
        echo
      elif [ "$INPUT_NAME_VAR" = ZFS_NAME ]
      then
        while true
        do
          info "The name '$NAME' is an existing ZFS file system dataset..."
          read -p "Are you sure you want to use '$NAME' datasets: [y/n]?" -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              ZFS_NAME="$NAME"
              info "ZFS Storage System name is set : ${YELLOW}$NAME${NC}"
              echo
              break 2
              ;;
            [Nn]*)
              echo
              msg "You have chosen not to proceed with '$NAME'.\nTry again..."
              sleep 2
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
    elif [[ ! "$NAME" =~ ^([a-z]{1})([^%])([_]?[-]?[:]?[.]?[a-z0-9]){1,14}$ ]] || [[ $(echo "$NAME" | egrep '^c[0-9]$|^log$|^spare$|^root$|^rpool$|^mirror$|^raidz[0-9]?') ]]
    then
      msg "The ZFS component name is not valid. A valid name is when all of the following constraints are satisfied:
        --  it contains only lowercase characters
        --  it begins with at least 1 alphabet character
        --  it contains at least 2 characters and at most is 10 characters long
        --  it may include numerics, underscore (_), hyphen (-), colon (:), period but not start or end with them
        --  it doesn't contain any other special characters [!#$&%*+]
        --  it doesn't contain any white space
        --  beginning sequence 'c[0-9]' is not allowed
        --  a name that begins with root, rpool, log, mirror, raid, raidz, raidz(0-9) or spare is not allowed because these names are reserved.

      Try again..."
      echo
    elif [[ "$NAME" =~ ^([a-z]{1})([^%])([_]?[-]?[:]?[.]?[a-z0-9]){1,14}$ ]] && [[ $(echo "$NAME" | egrep -v '^c[0-9]$|^log$|^spare$|^root$|^rpool$|^mirror$|^raidz[0-9]?') ]]; then
      if [ "$INPUT_NAME_VAR" = POOL ]
      then
        POOL=$NAME
        info "ZPool name is set : ${YELLOW}$NAME${NC}"
        echo
      elif [ "$INPUT_NAME_VAR" = ZFS_NAME ]
      then
        ZFS_NAME="$NAME"
        info "ZFS Storage System name is set : ${YELLOW}$NAME${NC}"
        echo
      fi
      break
    fi
  done
}
#-----------------------------------------------------------------------------------