#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_vm_diskpassthru.sh
# Description:  Source script for creating disk or PCIe pass-through to VM
#               Requires 'nas_identify_storagedisks.sh' (i.e "${storLIST[@]}").
#               Run after VM is created to set scsi[0-9] disks for pass-through
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Requires arg 'usb' or 'onboard' to be set in source command
# Sets the validation input type: pvesource_vm_diskpassthru.sh "onboard"
if [ -z "$1" ]
then
  input_tran=""
  input_tran_arg=""
elif [[ "$1" =~ 'usb' ]]
then
  input_tran='(usb)'
  input_tran_arg='usb'
elif [[ "$1" =~ 'onboard' ]]
then
  input_tran='(sata|ata|scsi|nvme)'
  input_tran_arg='onboard'
fi

#---- Static Variables -------------------------------------------------------------

# Basic storage disk label
basic_disklabel='(.*_hba|.*_usb|.*_onboard)$'

# USB Disk Storage minimum size (GB)
stor_min='30'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

#---- Select storage disk pass-through or HBA
msg_box "#### PLEASE READ CAREFULLY ####\n
You must choose your OMV NAS disk access method. Please read and select carefully. 

Your options are:

1)  Physical Disk Passthrough (individual disks)
Each selected disk is passed through to OMV VM (not the disk controller) as a SCSI device. You can select any amount of SAS/SATA/NVMe unassigned disks.
All storage frontend is fully managed by OMV NAS. The selected disks will no longer be available to the host.

2)  PCIe HBA card pass-thru
PCI passthrough allows you to use a physical mainboard PCI SATA or HBA device inside a PVE VM (KVM virtualization only).

The PVE host must be installed with a 'dedicated' PCIe HBA SAS/SATA/NVMe Card. All NAS disks (including any Cache SSds) must be connected to this PCIe HBA Card. You cannot co-mingle any OMV NAS disks with mainboard SATA/NVMe devices. All storage, both backend and fronted is fully managed by OMV NAS. You also have the option of configuring SSD cache using SSD drives inside OMV NAS. SSD cache will provide High Speed disk I/O.

If you 'PCI passthrough' a device, the device and connected disks are not available to the host anymore."
echo

# Select your disk attachment option
msg "Select the NAS disk access you want..."
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Physical disk pass-through - select physical disks individually" \
"PCIe HBA card pass-through - dedicated PCIe HBA card only" \
"None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

# Set disk access type
if [ "$RESULTS" = TYPE01 ]
then
  VM_DISK_PT=1
elif [ "$RESULTS" = TYPE02 ]
then
  VM_DISK_PT=2
  msg "PCIe card passthrough must be manually configured using the Proxmox web management frontend. Perform after this VM is created."
  echo
  return
elif [ "$RESULTS" = TYPE00 ]
then
  VM_DISK_PT=0
  msg "You have chosen not to proceed. Aborting this task. Bye..."
  echo
  return
fi

#---- PCIe HBA Card pass-through ---------------------------------------------------

# PCIe card passthrough is manually configured using the Proxmox web management frontend. Perform after the VM is created.

#---- Physical disk pass-through to VM ---------------------------------------------

#---- Identify available storage disks for pass-through
if [ "$VM_DISK_PT" = 1 ]
then
  # Create stor_LIST
  source $COMMON_DIR/nas/src/nas_bash_utility.sh

  # Wakeup USB disks
  wake_usb

  # Create storage list array
  storage_list

  # Create a working list array
  stor_LIST

  # Create raw disk list
  pt_disk_LIST=()
  pt_disk_LIST=( "$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v basic_disklabel="$basic_disklabel" \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  # Pass-thru raw storage disks
  {if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) print "Physical raw disk", $5, $1, $8, $6, $7}')" )

  if [ ! "${#pt_disk_LIST[@]}" = 0 ]
  then
    # Display msg
    display_msg1=$(printf '%s\n' "${pt_disk_LIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { print $1, $2, $3, $5, $4 }' | column -s ":" -t -N "DESCRIPTION,TYPE,DEVICE,,MODEL,CAPACITY (GB)" | indent2)

    msg_box "#### PLEASE READ CAREFULLY ####\n\nSelect the disks for physical disk pass-through to your PVE VM. You can select any number of disk. We recommend you crosscheck the model and device ID to make sure its not in use by your Proxmox host or another PVE CT or VM.\n\n$(echo "$display_msg1")\n\nAny missing disks may have been wrongly identified as 'system drives' if they contain Linux system or OS partitions. To fix this issue, manually format the missing disk erasing all data before running this installation again. You can exit this installer at the next prompt. Go to Proxmox web management interface 'PVE Host' > 'Disks' > 'Select disk' > 'Wipe Disk' and use the inbuilt function. All disks must have a data capacity greater than ${stor_min}G to be detected."

    # Select pass-through option
    msg "Select the option you want..."
    OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE00" )
    OPTIONS_LABELS_INPUT=( "Yes - I want to select disks for pass-through to my VM" \
    "No - I do not want to pass-through any disks to my VM" \
    "None. Exit this installer (i.e disks are missing)" )
    makeselect_input2
    singleselect SELECTED "$OPTIONS_STRING"

    if [ "$RESULTS" = TYPE01 ]
    then
      VM_DISK_PT=1
    elif [ "$RESULTS" = TYPE02 ]
    then
      VM_DISK_PT=0
      info "No physical disks will be configured for pass-through to your VM"
      echo
      return
    elif [ "$RESULTS" = TYPE00 ]
    then
      VM_DISK_PT=0
      msg "You have chosen not to proceed. Aborting this task. Bye..."
      echo
      return
    fi
  else
    msg_box "#### PLEASE READ CAREFULLY ####\n\nThe installer cannot detect any available storage disks for pass-through. Any missing disks (including new disks) may have been wrongly identified as 'system drives' if they contain Linux system or partitions.\n\nTo fix this issue, manually format the missing disk erasing all data before running this installation again. You can exit this installer at the next prompt. Go to Proxmox web management interface 'PVE Host' > 'Disks' > 'Select disk' > 'Wipe Disk' and use the inbuilt function. All disks must have a data capacity greater than ${stor_min}G to be detected."
    echo
    return
  fi
fi

#---- Set physical disk scsi pass-through
if [ "$VM_DISK_PT" = 1 ]
then
  # Select disks for pass-through
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${pt_disk_LIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { print $2, $3, $6 }' | sed -e '$aTYPE00')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${pt_disk_LIST[@]}" | awk -F':' '{ print $3, $5, $4, "("$2" device)" }' | sed -e '$aNone. Exit this installer')
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  multiselect SELECTED "$OPTIONS_STRING"
  if [[ "${RESULTS[*]}" =~ 'TYPE00' ]]
  then
    VM_DISK_PT=0
    msg "You have chosen not to proceed. Aborting. Bye..."
    sleep 1
    echo
    return
  else
    pt_disk_LIST=()
    pt_disk_LIST+=( $(printf '%s\n' "${RESULTS[@]}") )
  fi

  # qm set scsi drive
  if [ ! "${#pt_disk_LIST[@]}" = 0 ]
  then
    msg "Creating SCSI pass-through disk(s) conf..."
    # Check VMID scsi disk id
    while IFS=':' read -r dev args
    do
      i=$(echo "$dev" | sed 's/[a-z]//g')
      ((i=i+1))
    done < <( grep ^scsi[0-9]\:.*$ /etc/pve/qemu-server/$VMID.conf | sort )

    # Create qm set scsi[0-9] conf entry
    j='1' # Set cnt
    while IFS=':' read -r tran dev serial
    do
      # Remove the "/dev/" prefix from the device name
      dev_name=$(echo "$dev" | sed 's/\/dev\///g')
      # Get the by-id name for the specified device
      by_id_name="$(ls -l /dev/disk/by-id | grep -v "wwn-" | grep "$dev_name" | awk '{print $9}')"
      
      # Create scsi[0-9] disk entry if new only
      if [[ ! $(grep -w "/dev/disk/by-id/$by_id_name" /etc/pve/qemu-server/$VMID.conf) ]]
      then
        qm set $VMID -scsi${i} /dev/disk/by-id/$by_id_name
        info "\t${j}. SCSI${i} disk pass-through created: $dev ($tran) ---> ${YELLOW}SCSI${i}${NC}"
        ((i=i+1))
      else
        info "\t${j}. SCSI $dev ($tran) disk pass-through already exists: ${WHITE}skipped${NC}"
      fi

      # Add to cnt
      ((j=j+1))
    done < <( printf '%s\n' "${pt_disk_LIST[@]}" )
    echo
  fi
fi
#-----------------------------------------------------------------------------------