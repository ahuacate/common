#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_ubuntu_installproftp.sh
# Description:  Source script for installing ProFTP
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SOURCE="${DIR}"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source ${DIR}/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='ProFTPd Server'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

section "Install and configure ProFTPd Server."

msg_box "#### PLEASE READ CAREFULLY - PROFTPD INSTALLATION ####\n
ProFTPd is a highly feature rich FTP server, exposing a large amount of configuration options to the user. This software allows you to create a FTP connection between a remote or local computer and a your PVE NAS.

ProFTPd management can be done using the Webmin management frontend. ProFTPd is installed by default."
echo
while true; do
  read -p "Install ProFTPd [y/n]?: " -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      msg "Installing ProFTPd..."
      echo
      INSTALL_PROFTPD=0 >/dev/null
      break
      ;;
    [Nn]*)
      INSTALL_PROFTPD=1 >/dev/null
      msg "You have chosen not to proceed. Moving on..."
      echo
      break
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done

#---- Install ProFTP Prerequisites
if [ ${INSTALL_PROFTPD} == 0 ]; then
  msg "Checking ProFTPd status..."
  if [ $(dpkg -s proftpd-core >/dev/null 2>&1; echo $?) = 0 ]; then
    info "ProFTPd status: ${GREEN}installed.${NC} ( $(proftpd --version) )"
    echo
  else
    msg "Installing ProFTPd..."
    apt-get -y update >/dev/null 2>&1
    apt-get install -y proftpd-core openssl proftpd-mod-crypto >/dev/null
    sleep 1
    if [ $(dpkg -s proftpd-core >/dev/null 2>&1; echo $?) = 0 ]; then
      info "ProFTPd status: ${GREEN}installed${NC} ( $(proftpd --version) )"
      echo
    else
      warn "ProFTPd status: ${RED}inactive or cannot install (dead).${NC}.\nYour intervention is required.\nExiting installation script in 2 second."
      echo
      sleep 2
      exit 0
    fi
  fi

  # ProFTPd enable
  systemctl enable proftpd 2> /dev/null

  # Starting ProFTPd service 
  msg "Checking ProFTP status..."
  if [ "$(systemctl is-active proftpd)" == "inactive" ]; then
    msg "Starting ProFTPd..."
    systemctl start proftpd
    msg "Waiting to hear from ProFTPd..."
    while ! [[ "$(systemctl is-active proftpd)" == "active" ]]; do
      echo -n .
    done
    info "ProFTPd status: ${GREEN}running${NC}"
    echo
  else
    info "ProFTPd status: ${GREEN}running${NC}"
    echo
  fi
fi

#---- Finish Line ------------------------------------------------------------------
if [ ! ${INSTALL_PROFTPD} == 1 ]; then
  section "Completion Status."

  info "${WHITE}Success.${NC} ProFTPd has been installed and configured."
  echo
fi

# Cleanup
if [ -z "${PARENT_EXEC+x}" ]; then
  trap cleanup EXIT
fi