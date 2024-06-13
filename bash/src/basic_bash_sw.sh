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

#--- Install wGet
if [[ ! $(dpkg -s wget 2> /dev/null) ]]; then
  apt-get install wget -y
fi

#--- Install jq
if [[ ! $(dpkg -s jq 2> /dev/null) ]]; then
  apt-get install jq -y
fi

#--- Check for linux ascii boxes
if command -v boxes > /dev/null; then
  current_ver=$(boxes -v | awk '{print $3}')  # Get the current version of boxes
else
  current_ver=0 # Set version to null
fi

# Fetch the latest release JSON from GitHub API
response=$(curl -s https://api.github.com/repos/ascii-boxes/boxes/releases/latest)

# Extract the latest version using jq
latest_ver_tag=$(echo "$response" | jq -r '.tag_name')
latest_ver=$(echo "$response" | jq -r '.tag_name' | sed 's/v//')

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
  apt-get install -y build-essential diffutils flex bison libunistring-dev libpcre2-dev libcmocka-dev libncurses-dev git terminfo vim-common 2> /dev/null

  # Download the latest version from GitHub releases
  wget -P "/tmp" "https://github.com/ascii-boxes/boxes/archive/$latest_ver_tag.tar.gz"

  # Install boxes
  work_dir="$(pwd)"
  tar -zxvf "/tmp/$latest_ver_tag.tar.gz" -C /tmp
  cd "/tmp/boxes-$latest_ver"
  make
  make utest
  make test

  cp -f "/tmp/boxes-$latest_ver/doc/boxes.1" /usr/share/man/man1
  cp -f "/tmp/boxes-$latest_ver/boxes-config" /usr/share/boxes
  cp -f "/tmp/boxes-$latest_ver/out/boxes" /usr/bin

  # Cleanup
  cd "$work_dir"
  rm -rf /tmp/"boxes-$latest_ver" "/tmp/$latest_ver.tar.gz"
  echo "Ascii Boxes install and update complete..."
fi
#-----------------------------------------------------------------------------------