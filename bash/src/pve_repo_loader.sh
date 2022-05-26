#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_repo_loader.sh
# Description:  Repo loader for PVE installer
# ----------------------------------------------------------------------------------

#---- Dependencies -----------------------------------------------------------------

# Check for Git SW
if [ ! $(dpkg -s git >/dev/null 2>&1; echo $?) == 0 ] && ! [[ $(uname -a | grep 'synology') ]]; then; then
  apt-get install git -yqq
fi

# Installer cleanup
function installer_cleanup () {
rm -R ${REPO_TEMP}/${GIT_REPO} &> /dev/null
rm ${REPO_TEMP}/${GIT_REPO}.tar.gz &> /dev/null
}

#---- Body -------------------------------------------------------------------------

#---- Clean old copies
rm -R ${REPO_TEMP}/${GIT_REPO} &> /dev/null
rm ${REPO_TEMP}/${GIT_REPO}.tar.gz &> /dev/null

#---- Developer Options
if [ -f /mnt/pve/nas-*[0-9]-git/${GIT_USER}/developer_settings.git ]; then
  cp -R /mnt/pve/nas-*[0-9]-git/${GIT_USER}/${GIT_REPO} ${REPO_TEMP}
  tar --exclude=".*" -czf ${REPO_TEMP}/${GIT_REPO}.tar.gz -C ${REPO_TEMP} ${GIT_REPO}/ &> /dev/null
  # Create tmp dir
  mkdir -p ${REPO_TEMP}/${GIT_REPO}/tmp
fi

#---- Download Github repo
if [ ! -f /mnt/pve/nas-*[0-9]-git/${GIT_USER}/developer_settings.git ]; then
  # Git clone
  git clone --recurse-submodules https://github.com/${GIT_USER}/${GIT_REPO}.git
  # # Download Repo packages
  # wget -qL - ${GIT_SERVER}/${GIT_USER}/${GIT_REPO}/archive/${GIT_BRANCH}.tar.gz -O ${REPO_TEMP}/${GIT_REPO}.tar.gz
  # tar -zxf ${REPO_TEMP}/${GIT_REPO}.tar.gz -C ${REPO_TEMP}
  # mv ${REPO_TEMP}/${GIT_REPO}-${GIT_BRANCH} ${REPO_TEMP}/${GIT_REPO}
  # chmod -R 777 ${REPO_TEMP}/${GIT_REPO}
  # # Download Common packages
  # wget -qL - ${GIT_SERVER}/${GIT_USER}/common/archive/${GIT_BRANCH}.tar.gz -O ${REPO_TEMP}/common.tar.gz
  # tar -zxf ${REPO_TEMP}/common.tar.gz -C ${REPO_TEMP}
  # mv ${REPO_TEMP}/common-${GIT_BRANCH}/ ${REPO_TEMP}/common
  # mv ${REPO_TEMP}/common/ ${REPO_TEMP}/${GIT_REPO}
  # chmod -R 777 ${REPO_TEMP}/${GIT_REPO}/common
  # Create new tar files
  # rm ${REPO_TEMP}/${GIT_REPO}.tar.gz
  chmod -R 777 ${REPO_TEMP}/${GIT_REPO}
  tar --exclude=".*" -czf ${REPO_TEMP}/${GIT_REPO}.tar.gz -C ${REPO_TEMP} ${GIT_REPO}/
  # Create tmp dir
  mkdir -p ${REPO_TEMP}/${GIT_REPO}/tmp
fi