#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_repo_loader.sh
# Description:  Repo loader for PVE installer
# ----------------------------------------------------------------------------------

#---- Set Package Installer Temp Folder
cd /tmp

#---- Clean old copies
echo "${REPO_TEMP} ...................................."
exit 0
#rm -R /tmp/common &> /dev/null
#rm -R /tmp/${GIT_REPO} &> /dev/null
#rm /tmp/common.tar.gz &> /dev/null
#rm /tmp/${GIT_REPO}.tar.gz &> /dev/null

#---- Developer Options
if [ -f /mnt/pve/nas-*[0-9]-git/${GIT_USER}/developer_settings.git ]; then
  cp -R /mnt/pve/nas-*[0-9]-git/${GIT_USER}/${GIT_REPO} /tmp
  tar --exclude=".*" -czf /tmp/${GIT_REPO}.tar.gz -C /tmp ${GIT_REPO}/ &> /dev/null
  # Copy Git common
  if [ ${GIT_COMMON} = 0 ]; then
    cp -R /mnt/pve/nas-*[0-9]-git/${GIT_USER}/common /tmp
    tar --exclude=".*" -czf /tmp/common.tar.gz -C /tmp common/ &> /dev/null
  fi
fi

#---- Download Github repo
if [ ! -f /mnt/pve/nas-*[0-9]-git/${GIT_USER}/developer_settings.git ]; then
  # Download packages
  wget -qL ${GIT_SERVER}/${GIT_USER}/${GIT_REPO}/archive/${GIT_BRANCH}.tar.gz -O /tmp/${GIT_REPO}.tar.gz
  tar -zxf /tmp/${GIT_REPO}.tar.gz -C /tmp
  mv /tmp/${GIT_REPO}-${GIT_BRANCH} /tmp/${GIT_REPO}
  # Download Git common
  if [ ${GIT_COMMON} = 0 ]; then
    wget -qL ${GIT_SERVER}/${GIT_USER}/common/archive/${GIT_BRANCH}.tar.gz -O /tmp/common.tar.gz
    tar -zxf /tmp/common.tar.gz -C /tmp
    mv /tmp/common-master /tmp/common
  fi
  # Create new tar files
  rm /tmp/${GIT_REPO}.tar.gz
  tar --exclude=".*" -czf /tmp/${GIT_REPO}.tar.gz -C /tmp ${GIT_REPO}/
  tar --exclude=".*" -czf /tmp/common.tar.gz -C /tmp common/
fi
