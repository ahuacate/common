#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_precheck_iommu.sh
# Description:  Source script to verify IOMMU is enabled on the PVE host
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Verify IOMMU status
# Requires variable 'VM_PCI_PT'
FAIL_MSG='This VM installation requires PCIe pass-through. You need to enable IOMMU for PCI pass-through, by editing your Proxmox hosts kernel commandline. Perform the required edits as shown here:

  -- https://pve.proxmox.com/wiki/Pci_passthrough (follow the instructions)
  -- Edit the bootloader command line config to include 'intel_iommu=on'
  -- Add the required modules to file '/etc/modules'
  -- Run CLI 'update-grub'
  -- Reboot your Proxmox host

If you are creating a "PCI pass-through", the device is not available to the host or any other VM anymore.'

# Run check
if [ "$VM_PCI_PT" = 1 ] && [[ ! $(dmesg | grep -e DMAR -e IOMMU) =~ ^.*[IOMMU\ enabled]$ ]]
then
  warn "$FAIL_MSG"
  echo fail
  sleep 1
  exit 0
fi
#-----------------------------------------------------------------------------------