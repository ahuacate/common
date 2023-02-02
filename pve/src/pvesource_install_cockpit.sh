#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_install_cockpit.sh
# Description:  Source script Cockpit installation
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# 45Drives Repositories
curl -sSL https://repo.45drives.com/setup | sudo bash
apt-get update -y

#---- Cockpit Installation

# Install coockpit
apt-get install cockpit --no-install-recommends -y

# Edit disallowed-users file
if [ -f "/etc/cockpit/disallowed-users" ]
then
  sed '/^root/d' /etc/cockpit/disallowed-users
fi

#---- Add cockpit feature
# Cockpit Identities
apt-get install cockpit-identities -y

# Cockpit Navigator
apt-get install cockpit-navigator -y

# Cockpit-file-sharing
apt-get install cockpit-file-sharing -y
#-----------------------------------------------------------------------------------