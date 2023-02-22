#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_repo_loader.sh
# Description:  Repo loader for PVE installer
# ----------------------------------------------------------------------------------

#---- Dependencies -----------------------------------------------------------------

# Check host is PVE
if [[ ! $(command -v pveversion) ]]
then
  echo "This application is for Proxmox IS only. This host OS not supported.\nBye..."
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
  rm -R "$repo_temp/$GIT_REPO" &> /dev/null
  rm "$repo_temp/${GIT_REPO}.tar.gz" &> /dev/null
}

#---- Body -------------------------------------------------------------------------

#---- Clean old copies
installer_cleanup

#---- Local repo (developer)
# if [ -f /mnt/pve/nas-*[0-9]-git/${GIT_USER}/developer_settings.git ]; then
#   cp -R /mnt/pve/nas-*[0-9]-git/${GIT_USER}/${GIT_REPO} ${repo_temp}
#   tar --exclude=".*" -czf ${repo_temp}/${GIT_REPO}.tar.gz -C ${repo_temp} ${GIT_REPO}/ &> /dev/null
#   # Create tmp dir
#   mkdir -p ${repo_temp}/${GIT_REPO}/tmp
# fi
if [ -d "$repo_path/$GIT_REPO" ]
then
  cp -R "$repo_path/$GIT_REPO" $repo_temp
  tar --exclude=".*" -czf $repo_temp/${GIT_REPO}.tar.gz -C $repo_temp $GIT_REPO/ &> /dev/null
  # Create tmp dir
  mkdir -p "$repo_temp/$GIT_REPO/tmp"
fi



#---- Download Github repo

if [ ! -d "$repo_path/$GIT_REPO" ]
then
  # Git clone
  git clone --recurse-submodules https://github.com/$GIT_USER/${GIT_REPO}.git
  # # Download Repo packages
  # wget -qL - ${GIT_SERVER}/${GIT_USER}/${GIT_REPO}/archive/${GIT_BRANCH}.tar.gz -O ${repo_temp}/${GIT_REPO}.tar.gz
  # tar -zxf ${repo_temp}/${GIT_REPO}.tar.gz -C ${repo_temp}
  # mv ${repo_temp}/${GIT_REPO}-${GIT_BRANCH} ${repo_temp}/${GIT_REPO}
  # chmod -R 777 ${repo_temp}/${GIT_REPO}
  # # Download Common packages
  # wget -qL - ${GIT_SERVER}/${GIT_USER}/common/archive/${GIT_BRANCH}.tar.gz -O ${repo_temp}/common.tar.gz
  # tar -zxf ${repo_temp}/common.tar.gz -C ${repo_temp}
  # mv ${repo_temp}/common-${GIT_BRANCH}/ ${repo_temp}/common
  # mv ${repo_temp}/common/ ${repo_temp}/${GIT_REPO}
  # chmod -R 777 ${repo_temp}/${GIT_REPO}/common
  # Create new tar files
  # rm ${repo_temp}/${GIT_REPO}.tar.gz
  chmod -R 777 "$repo_temp/$GIT_REPO"
  tar --exclude=".*" -czf $repo_temp/${GIT_REPO}.tar.gz -C $repo_temp $GIT_REPO/
  # Create tmp dir
  mkdir -p "$repo_temp/$GIT_REPO/tmp"
fi
#-----------------------------------------------------------------------------------