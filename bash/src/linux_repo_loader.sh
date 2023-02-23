#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     linux_repo_loader.sh
# Description:  Repo loader for PVE installer
#               For Linux and non-PVE hosts only
# ----------------------------------------------------------------------------------

#---- Dependencies -----------------------------------------------------------------

#---- Check OS & Packages

if [[ $(uname -a | grep -i '.*synology.*') ]]
then
  #--- Synology OS
  # Check for GIT pkg
  if [[ ! $(git --version 2>/dev/null | grep -i "git version") ]]
  then
    echo -e "There are issues with this Synology.\nYou must install Git. Using the Synology WebGUI management interface:\n  1. Install the SynoCommunity package source\n  2. Install 'git' using the package manager\n  3. Re-run this installer from the CLI while root SSHed into your Synology.\n\nExiting script. Fix the issue and try again..."
    sleep 1
    exit 0
  fi
elif [[ $(dpkg -l | grep -i "openmediavault") ]]
then
  #--- Openmediavault (OMV)
  # Check for GIT pkg
  if [[ ! $(dpkg -s git 2> /dev/null) ]]
  then
    apt-get install git -y
  fi
elif [[ $(uname -a | grep -i 'Linux') ]]
then
  #---- Other Linux dist
  # Check for GIT pkg
  if [[ ! $(dpkg -s git 2> /dev/null) ]]
  then
  apt-get install git -y
  fi
fi


#---- Functions --------------------------------------------------------------------

# Installer cleanup
function installer_cleanup () {
  rm -R "$REPO_TEMP/$GIT_REPO" &> /dev/null
  rm "$REPO_TEMP/${GIT_REPO}.tar.gz" &> /dev/null
}

#---- Body -------------------------------------------------------------------------

#---- Clean old copies

# Run function
installer_cleanup


#---- Local repo (developer)

# Download Local loader (developer)
if [ -d "$REPO_PATH/$GIT_REPO" ]
then
  # Copy local repo to host
  cp -R "$REPO_PATH/$GIT_REPO" $REPO_TEMP
  # Create tar file of repo
  tar --exclude=".*" -czf $REPO_TEMP/${GIT_REPO}.tar.gz -C $REPO_TEMP $GIT_REPO/ &> /dev/null
  # Create tmp dir
  mkdir -p "$REPO_TEMP/$GIT_REPO/tmp"
fi


#---- Download Github repo

# Download Github loader
if [ ! -d "$REPO_PATH/$GIT_REPO" ]
then
  # Git clone
  git clone --recurse-submodules https://github.com/$GIT_USER/${GIT_REPO}.git
  chmod -R 777 "$REPO_TEMP/$GIT_REPO"
  # Create tar file of repo
  tar --exclude=".*" -czf $REPO_TEMP/${GIT_REPO}.tar.gz -C $REPO_TEMP $GIT_REPO/
  # Create tmp dir
  mkdir -p "$REPO_TEMP/$GIT_REPO/tmp"
fi
#-----------------------------------------------------------------------------------