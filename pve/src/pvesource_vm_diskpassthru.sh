#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_vm_diskpassthru.sh
# Description:  Source script for creating disk or PCIe pass-through to VM
#               Requires 'nas_identify_storagedisks.sh' (i.e "${storLIST[@]}").
#               Run after VM is created to set scsi[0-9] disks for pass-through
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

#---- Select storage disk pass-through or HBA
msg_box "#### PLEASE READ CAREFULLY ####\n
You must choose your OMV NAS disk access method. Please read and select carefully. 

Your options are:

1)  PCIe HBA card pass-thru
PCI passthrough allows you to use a physical mainboard PCI SATA or HBA device inside a PVE VM (KVM virtualization only).

The PVE host must be installed with a 'dedicated' PCIe HBA SAS/SATA/NVMe Card. All NAS disks (including any Cache SSds) must be connected to this PCIe HBA Card. You cannot co-mingle any OMV NAS disks with mainboard SATA/NVMe devices. All storage, both backend and fronted is fully managed by OMV NAS. You also have the option of configuring SSD cache using SSD drives inside OMV NAS. SSD cache will provide High Speed disk I/O.

If you 'PCI passthrough' a device, the device and connected disks are not available to the host anymore.

2)  Physical Disk Passthrough (individual disks)
Each selected disk is passed through to OMV VM (not the disk controller) as a SCSI device. You can select any amount of SAS/SATA/NVMe unassigned disks.
All storage frontend is fully managed by OMV NAS. The selected disks will no longer be available to the host."
echo
msg "Select the NAS disk access you want..."
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE00" )
OPTIONS_LABELS_INPUT=( "PCIe HBA card pass-through - dedicated PCIe HBA card only" \
"Physical disk pass-through - select physical disks individually" \
"None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

# Set disk access type
if [ ${RESULTS} == 'TYPE01' ]; then
  VM_DISK_PT='1'
  msg "PCIe card passthrough is manually configured using the Proxmox web management frontend. Perform after the VM is created."
  echo
if [ ${RESULTS} == 'TYPE02' ]; then
  VM_DISK_PT='2'
elif [ ${RESULTS} == 'TYPE00' ]; then
  VM_DISK_PT='0'
  msg "You have chosen not to proceed. Aborting this task. Bye..."
  echo
  return
fi


#---- PCIe HBA Card pass-through ---------------------------------------------------

# PCIe card passthrough is manually configured using the Proxmox web management frontend. Perform after the VM is created.

#---- Physical disk pass-through to VM ---------------------------------------------

#---- Identify available storage disks for pass-through
if [ "${VM_DISK_PT}" == '2' ]; then
  # Create stor_LIST
  source ${COMMON_DIR}/nas/src/nas_identify_storagedisks.sh

  # Basic storage disk label
  BASIC_DISKLABEL='(.*_hba|.*_usb|.*_onboard)$'

  # Create raw disk list
  pt_disk_options=()
  pt_disk_options=( "$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  # Pass-thru raw storage disks
  {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "Physical raw disk", $5, $1, $8, $6, $7}')" )


  if [ ! ${#pt_disk_options[@]} == '0' ]; then
    msg_box "#### PLEASE READ CAREFULLY ####\n\nSelect all the disks for physical disk pass-through to your OMV NAS. You can select more than one disk. We recommend you should always crosscheck the model and device ID to make sure its not in use by your Proxmox host or another PVE CT or VM.\n\n$(printf '%s\n' "${pt_disk_options[@]}" | awk -F':' 'BEGIN{OFS=FS} { print $1, $2, $3, $5, $4 }' | column -s ":" -t -N "DESCRIPTION,TYPE,DEVICE,,MODEL,CAPACITY (GB)" | indent2)\n\n$(if [ ! "${#existing_pt_LIST[@]}" == '0' ]; then echo "The following disks are in-use by other VMs (excluded):\n" && printf '%s\n' "${existing_pt_LIST[@]}" | column -s ":" -t -N "VMID,TYPE,DEVICE,MODEL,CAPACITY (GB)" | indent2; fi)\n\nNew disk(s) might have been wrongly identified as 'system drives' if they contain Linux system or OS partitions and are not available. To fix this issue, manually format the missing disk erasing all data before running this installation again. You can exit this installer at the next prompt. Go to Proxmox web management interface 'PVE Host' > 'Disks' > 'Select disk' > 'Wipe Disk' and use the inbuilt function. All disks must have a data capacity greater than ${STOR_MIN}G to be detected."

    # Select pass-through option
    msg "Select the option you want..."
    OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE00" )
    OPTIONS_LABELS_INPUT=( "Yes - I want to select disks for pass-through to my VM" \
    "No - I do not want to pass-through any disks to my VM" \
    "Disks are missing. I want to fix the issue. Exit this installer now" )
    makeselect_input2
    singleselect SELECTED "$OPTIONS_STRING"

    if [ ${RESULTS} =~ 'TYPE01' ]; then
      VM_DISK_PT=2
    elif [ ${RESULTS} =~ 'TYPE02' ]; then
      VM_DISK_PT=0
      info "No physical disks will be configured for pass-through to your VM"
      echo
    elif [ ${RESULTS} == 'TYPE00' ]; then
      VM_DISK_PT=0
      msg "You have chosen not to proceed. Aborting this task. Bye..."
      echo
      return
    fi
  else
    msg_box "#### PLEASE READ CAREFULLY ####\n\nThe installer cannot detect any available storage disks for pass-through. New disk(s) might have been wrongly identified as 'system drives' if they contain Linux system or OS partitions and are not available.\n\n$(if [ ! "${#existing_pt_LIST[@]}" == '0' ]; then echo "Also the following disks are not available because they are in-use by other VMs (excluded):\n" && printf '%s\n' "${existing_pt_LIST[@]}" | column -s ":" -t -N "VMID,TYPE,DEVICE,MODEL,CAPACITY (GB)" | indent2; fi)\n\nTo fix this issue, manually format the missing disk erasing all data before running this installation again. You can exit this installer at the next prompt. Go to Proxmox web management interface 'PVE Host' > 'Disks' > 'Select disk' > 'Wipe Disk' and use the inbuilt function. All disks must have a data capacity greater than ${STOR_MIN}G to be detected."

    # Select pass-through option
    msg "Select the option you want..."
    OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE00" )
    OPTIONS_LABELS_INPUT=( "Proceed without any disk pass-through to my VM" \
    "Disks are missing. I want to fix the issue. Exit this installer now" )
    makeselect_input2
    singleselect SELECTED "$OPTIONS_STRING"

    if [ ${RESULTS} =~ 'TYPE01' ]; then
      VM_DISK_PT=0
    elif [ ${RESULTS} == 'TYPE00' ]; then
      VM_DISK_PT=0
      msg "You have chosen not to proceed. Aborting this task. Bye..."
      echo
      return
    fi
  fi
fi

# Set physical disk scsi pass-through
if [ "${VM_DISK_PT}" == '2' ]; then
  # Select disks for pass-through
  while true; do
    OPTIONS_VALUES_INPUT=$(printf '%s\n' "${pt_disk_options[@]}" | awk -F':' 'BEGIN{OFS=FS} { print $2, $3, $6 }' | sed -e '$aTYPE00')
    OPTIONS_LABELS_INPUT=$(printf '%s\n' "${pt_disk_options[@]}" | awk -F':' '{ print $3, $5, $4, "("$2" device)" }' | sed -e '$aNone. Exit this installer')
    makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
    multiselect SELECTED "$OPTIONS_STRING"
    if [[ "${RESULTS[*]}" =~ 'TYPE00' ]]; then
      VM_DISK_PT=0
      msg "You have chosen not to proceed. Aborting. Bye..."
      sleep 3
      echo
      return
    else
      pt_disk_LIST=( "$(printf '%s\n' "${RESULTS[@]}")" )
      break
    fi
  done

  # qm set scsi drive
  if [ ${#pt_disk_LIST[@]} -ge '1' ]; then
    msg "Creating SCSI pass-through disk(s) conf..."
    # Check VMID scsi disk id
    while IFS=':' read -r dev args; do
      i=$(echo $dev | sed 's/[a-z]//g')
      ((i=i+1))
    done <<< $(grep ^scsi[0-9]\:.*$ /etc/pve/qemu-server/${VMID}.conf | sort)

    # Create qm set scsi[0-9] conf entry
    j='1' # Set cnt
    while IFS=':' read -r tran dev serial; do
      BY_ID=$(ls -l /dev/disk/by-id | grep -E "${tran}" | grep -w "$(echo ${dev} | sed 's|^.*/||')" | awk '{ print $9 }')
      # Create scsi[0-9] disk entry if new only
      if [[ ! $(grep -w "/dev/disk/by-id/${BY_ID}" /etc/pve/qemu-server/${VMID}.conf) ]]; then
        qm set ${VMID} -scsi${i} /dev/disk/by-id/${BY_ID},backup=0
        info "\t${j}. SCSI${i} disk pass-through created: $dev ($tran) ---> ${YELLOW}SCSI${i}${NC}"
        ((i=i+1))
      else
        info "\t${j}. SCSI $dev ($tran) disk pass-through already exists: ${WHITE}skipped${NC}"
      fi
      # Add to cnt
      ((j=j+1))
    done <<< $(printf '%s\n' "${pvesm_input_LIST[@]}")
    echo
fi
#-----------------------------------------------------------------------------------