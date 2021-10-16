#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_repo_loader.sh
# Description:  Repo loader for PVE installer
# ----------------------------------------------------------------------------------

#---- Clean old copies
rm -R ${REPO_TEMP}/common &> /dev/null
rm -R ${REPO_TEMP}/${GIT_REPO} &> /dev/null
rm ${REPO_TEMP}/common.tar.gz &> /dev/null
rm ${REPO_TEMP}/${GIT_REPO}.tar.gz &> /dev/null

#---- Developer Options
if [ -f /mnt/pve/nas-*[0-9]-git/${GIT_USER}/developer_settings.git ]; then
  cp -R /mnt/pve/nas-*[0-9]-git/${GIT_USER}/${GIT_REPO} ${REPO_TEMP}
  tar --exclude=".*" -czf ${REPO_TEMP}/${GIT_REPO}.tar.gz -C ${REPO_TEMP} ${GIT_REPO}/ &> /dev/null
  # Copy Git common
  if [ ${GIT_COMMON} = 0 ]; then
    cp -R /mnt/pve/nas-*[0-9]-git/${GIT_USER}/common ${REPO_TEMP}
    tar --exclude=".*" -czf ${REPO_TEMP}/common.tar.gz -C ${REPO_TEMP} common/ &> /dev/null
  fi
fi

#---- Download Github repo
if [ ! -f /mnt/pve/nas-*[0-9]-git/${GIT_USER}/developer_settings.git ]; then
  # Download packages
  wget -qL - ${GIT_SERVER}/${GIT_USER}/${GIT_REPO}/archive/${GIT_BRANCH}.tar.gz -O ${REPO_TEMP}/${GIT_REPO}.tar.gz
  tar -zxf ${REPO_TEMP}/${GIT_REPO}.tar.gz -C ${REPO_TEMP}
  mv ${REPO_TEMP}/${GIT_REPO}-${GIT_BRANCH} ${REPO_TEMP}/${GIT_REPO}
  chmod -R 777 ${REPO_TEMP}/${GIT_REPO}
  # Download Git common
  if [ ${GIT_COMMON} = 0 ]; then
    wget -qL - ${GIT_SERVER}/${GIT_USER}/common/archive/${GIT_BRANCH}.tar.gz -O ${REPO_TEMP}/common.tar.gz
    tar -zxf ${REPO_TEMP}/common.tar.gz -C ${REPO_TEMP}
    mv ${REPO_TEMP}/common-master ${REPO_TEMP}/common
    chmod -R 777 ${REPO_TEMP}/common
  fi
  # Create new tar files
  rm ${REPO_TEMP}/${GIT_REPO}.tar.gz
  tar --exclude=".*" -czf ${REPO_TEMP}/${GIT_REPO}.tar.gz -C ${REPO_TEMP} ${GIT_REPO}/
  tar --exclude=".*" -czf ${REPO_TEMP}/common.tar.gz -C ${REPO_TEMP} common/
fi
