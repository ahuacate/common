#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_precheck_iommu.sh
# Description:  Source script to verify IOMMU is enabled
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# Verify IOMMU status
FAIL_MSG='This VM installation requires PCI passthrough. You need to enable the IOMMU for PCI passthrough, by editing all PVE hosts kernel commandline. Perform the required PVE hosts shown here:

  -- https://pve.proxmox.com/wiki/Pci_passthrough

If you "PCI passthrough" a device, the device is not available to the host anymore.'

if [[ $(dmesg | grep -e DMAR -e IOMMU) ]] || [[ $(lsmod | grep vfio) ]]; then
  warn "${FAIL_MSG}"
  sleep 2
  exit 0
fi
#-----------------------------------------------------------------------------------