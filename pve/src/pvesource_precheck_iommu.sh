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
FAIL_MSG='This VM installation requires PCIe pass-through. You need to enable the IOMMU for PCI pass-through, by editing all PVE hosts kernel commandline. Perform the required PVE hosts shown here:

  -- https://pve.proxmox.com/wiki/Pci_passthrough

If you are creating a "PCI pass-through", the device is not available to the host or any other VM anymore.'

if [ ${VM_PCI_PT} == '1' ] && [[ ! $(dmesg | grep -e DMAR -e IOMMU) =~ ^.*[IOMMU\ enabled]$ ]] || [[ ! $(lsmod | grep vfio) ]]; then
  warn "${FAIL_MSG}"
  echo fail
  sleep 1
  exit 0
fi
#-----------------------------------------------------------------------------------