#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_repo_loader.sh
# Description:  Repo loader for PVE installer
# ----------------------------------------------------------------------------------

#---- Dependencies -----------------------------------------------------------------

# Check host is PVE
if [[ ! $(command -v pveversion) ]]
then
  echo "This application is for Proxmox only. This host OS is not supported.\nBye..."
  exit 0
fi

# Check for Git SW
if [[ ! $(dpkg -s git 2> /dev/null) ]]
then
  apt-get install git -yqq
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