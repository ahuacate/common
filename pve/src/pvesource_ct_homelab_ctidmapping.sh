#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_homelab_ctidmapping.sh
# Description:  Source script for CTID container mapping for homelab UID & GUID
#               For Ubuntu CT UID/GIDs only
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Unprivileged container mapping

# CTID UID/GID maps
msg "HomeLab unprivileged PVE CT mapping..."
echo -e "# Video grp map
lxc.idmap: g 0 100000 44
lxc.idmap: g 44 44 1
lxc.idmap: g 45 100045 54
# User grp map
lxc.idmap: g 100 100 1
lxc.idmap: g 101 100101 6
# Render grp map
lxc.idmap: g 108 103 1
lxc.idmap: g 109 100109 65426
# Ahuacate user(s) map
lxc.idmap: u 0 100000 1606
lxc.idmap: u 1606 1606 1
lxc.idmap: u 1607 101607 63929
# Ahuacate grp(s) map - homelab
lxc.idmap: g 65606 65606 1" >> /etc/pve/lxc/$CTID.conf

# /etc/subuid entries
grep -qxF 'root:1606:1' /etc/subuid || echo 'root:1606:1' >> /etc/subuid  # User home

# /etc/subgid entries
grep -qxF 'root:44:1' /etc/subgid || echo 'root:44:1' >> /etc/subgid  # Grp video
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid  # Grp users
grep -qxF 'root:103:1' /etc/subgid || echo 'root:103:1' >> /etc/subgid  # Grp render
grep -qxF 'root:65606:1' /etc/subgid || echo 'root:65606:1' >> /etc/subgid  # Grp homelab

# Display msg
info "${CT_HOSTNAME_VAR^} CT 'unprivileged' UID mapping is set: ${YELLOW}home${NC}"
info "${CT_HOSTNAME_VAR^} CT 'unprivileged' GUID mapping is set: ${YELLOW}homelab${NC}."
echo
#-----------------------------------------------------------------------------------