#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_install_webmin.sh
# Description:  Source script Webmin installation
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Install and Configure Webmin
section "Installing and configuring Webmin"

#---- Install Webmin Prerequisites
msg "Installing Webmin prerequisites (be patient, might take a while)..."
if (( $(echo "$(lsb_release -sr) >= 22.04" | bc -l) )); then
  apt-get install -y gnupg2 >/dev/null
  echo "deb https://download.webmin.com/download/repository sarge contrib" | tee /etc/apt/sources.list.d/webmin.list
  wget -qO - http://www.webmin.com/jcameron-key.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/jcameron-key.gpg
  apt-get update >/dev/null
elif (( $(echo "$(lsb_release -sr) < 22.04" | bc -l) )); then
  apt-get install -y gnupg2 >/dev/null
  bash -c 'echo "deb [arch=amd64] http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list' >/dev/null
  wget -qL https://download.webmin.com/jcameron-key.asc
  apt-key add jcameron-key.asc 2>/dev/null
  apt-get update >/dev/null
fi

# Install Webmin
msg "Installing Webmin (be patient, might take a long, long, long while)..."
apt-get install -y webmin >/dev/null
ufw allow 10000 > /dev/null
if [ "$(systemctl is-active --quiet webmin; echo $?)" = 0 ]
then
	info "Webmin Server status: ${GREEN}active${NC}  (running)"
	echo
elif [ "$(systemctl is-active --quiet webmin; echo $?)" = 3 ]
then
	info "Webmin Server status: ${RED}inactive${NC} (Dead. Your intervention is required.)"
	echo
fi
#-----------------------------------------------------------------------------------