#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_error_log.sh
# Description:  Source script for displaying errors
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

# PVESM Folder Error
if [ ! ${#display_dir_error_MSG[@]} == '0' ]; then
msg "+----------------------------------------------------------------------------------+
PVESM FOLDER ERROR

This error is critical and halted the installation.

Failed to create CT subfolders on your PVE shared storage (NAS). The cause is often related to PVESM or NAS user and folder share permissions. We recommend the User reads our Github NAS guides ( 'https://github.com/picasso566/nas-hardmetal' and 'https://github.com/picasso566/pve-nas' ) and makes sure the following constraints are satisfied:

  --  Power User & Group Accounts
        Groups: medialab:65605, homelab:65606, privatelab:65607, chrootjail:65608
        Users: media:1605, home:1606, private:1607
        Users media, home and private are for running CT applications
  --  Chrootjail Group for general User accounts (optional).
  --  Ready for all Medialab applications such as Sonarr, Radarr, JellyFin, NZBGet and more.
  --  Full set of base and subfolders ready for all CT applications
  --  Folder and user permissions are set including ACLs
  --  Chattr is applied to folders using a file named '.foo_protect'
  --  NFS 4.1 exports ready for PVE hosts backend storage mounts
  --  SMB 3.0 shares with access permissions set ( by User Group accounts )
  --  Set Local Domain option to set ( i.e .local, .localdomain, .home.arpa, .lan )

Error log:"
msg_box "$(printf '%s\n' "${display_dir_error_MSG[@]}")"
fi

# PVESM Permission Error
if [ ! ${#display_permission_error_MSG[@]} == '0' ]; then
msg "+----------------------------------------------------------------------------------+
PVESM FOLDER PERMISSION ERROR

The error occurred when setting the required CT application subfolders ACL (setfacl) permissions. We recommend the User reads our Github NAS guides ( 'https://github.com/picasso566/nas-hardmetal' and 'https://github.com/picasso566/pve-nas' ) and makes sure the following constraints are satisfied:

  --  Power User & Group Accounts
        Groups: medialab:65605, homelab:65606, privatelab:65607, chrootjail:65608
        Users: media:1605, home:1606, private:1607
        Users media, home and private are for running CT applications
  --  Chrootjail Group for general User accounts (optional).
  --  Ready for all Medialab applications such as Sonarr, Radarr, JellyFin, NZBGet and more.
  --  Full set of base and subfolders ready for all CT applications
  --  Folder and user permissions are set including ACLs
  --  Chattr is applied to folders using a file named '.foo_protect'
  --  NFS 4.1 exports ready for PVE hosts backend storage mounts
  --  SMB 3.0 shares with access permissions set ( by User Group accounts )
  --  Set Local Domain option to set ( i.e .local, .localdomain, .home.arpa, .lan )

Error log:"
msg_box "$(printf '%s\n' "${display_permission_error_MSG[@]}")"
fi

# PVESM Chattr Error
if [ ! ${#display_chattr_error_MSG[@]} == '0' ]; then
msg "+----------------------------------------------------------------------------------+
PVESM FOLDER CHATTR ERROR

The error occurred when creating subfolder file '.foo_protect' for chattr. We recommend the User reads our Github NAS guides ( 'https://github.com/picasso566/nas-hardmetal' and 'https://github.com/picasso566/pve-nas' ) and makes sure the following constraints are satisfied:

  --  Folder and user permissions are set including ACLs
  --  Chattr is applied to subfolders using a file named '.foo_protect'

Error log:"
msg_box "$(printf '%s\n' "${display_chattr_error_MSG[@]}")"
fi