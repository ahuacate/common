#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     bash_basic_sw.sh
# Description:  Basic bash SW for PVE hosts and VMs/LXCs
#               Here will install any additional SW required by scripts on the host
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#--- Install Git SW
if [[ ! $(dpkg -s git 2> /dev/null) ]]; then
  apt-get install git -yqq
fi

#--- Install BC
if [[ ! $(dpkg -s bc 2> /dev/null) ]]; then
  apt-get install bc -y
fi

#--- Install Curl
if [[ ! $(dpkg -s curl 2> /dev/null) ]]; then
  apt-get install curl -y
fi

#--- Check for linux ascii boxes
if command -v boxes > /dev/null; then
  current_ver=$(boxes -v | awk '{print $3}')  # Get the current version of boxes
else
  current_ver=0 # Set version to null
fi

# Get version status
latest_ver_tag=$(curl -s https://api.github.com/repos/ascii-boxes/boxes/releases/latest | grep -oP '"tag_name": "\K(.*?)(?=")')  # Get the latest version from GitHub releases
latest_ver=$(echo "$latest_ver_tag" | sed 's/^v//')  # Remove the leading 'v' from the version number

# Compare Ascii Box versions
if [[ "$current_ver" < "$latest_ver" ]]; then
  echo "Updating ascii boxes to version $latest_ver_tag..."

  # Remove old apt install version
  if [[ $(dpkg -s boxes 2> /dev/null) ]]; then
    apt-get remove -y boxes > /dev/null
  fi

  # Remove old manual install
  if [ -f "/usr/bin/boxes" ]; then
    rm -f "/usr/bin/boxes" 2> /dev/null
    rm -f /usr/share/man/man1/boxes.1 2> /dev/null
    rm -rf /usr/share/boxes 2> /dev/null
  fi

  # Install prerequisites 
  apt-get install -y build-essential diffutils flex bison libunistring-dev libpcre2-dev libcmocka-dev git vim-common 2> /dev/null

  # Download the latest version from GitHub releases
  wget "https://github.com/ascii-boxes/boxes/archive/$latest_ver_tag.tar.gz"

  # Install boxes
  tar -zxvf "$latest_ver_tag.tar.gz"
  cd "boxes-$latest_ver"
  make
  make utest
  make test
  cp -f "/boxes-$latest_ver/doc/boxes.1" /usr/share/man/man1
  cp -f "/boxes-$latest_ver/boxes-config" /usr/share/boxes
  cp -f "/boxes-$latest_ver/out/boxes" /usr/bin

  # Cleanup
  cd /
  rm -rf ~/"boxes-$latest_ver" "$latest_ver.tar.gz"
  echo "Ascii Boxes install and update complete..."
fi
#-----------------------------------------------------------------------------------