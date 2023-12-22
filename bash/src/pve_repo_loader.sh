#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_repo_loader.sh
# Description:  Repo loader for PVE installer
# ----------------------------------------------------------------------------------

#---- Dependencies -----------------------------------------------------------------

# Check host is PVE
if [[ ! $(command -v pveversion) ]]; then
  echo "This application is for Proxmox only. This host OS is not supported.\nBye..."
  exit 0
fi

# Check for Git SW
if [[ ! $(dpkg -s git 2> /dev/null) ]]; then
  apt-get install git -yqq
fi

#---- Functions --------------------------------------------------------------------

# Installer cleanup
function installer_cleanup () {
  rm -R "$REPO_TEMP/$GIT_REPO" &> /dev/null
  rm "$REPO_TEMP/${GIT_REPO}.tar.gz" &> /dev/null
}

#--- Check Proxmox and kernel version

# Get PVE version status
function pve_version_status() {
    # Function retrieves Proxmox and Kernel versions
    # and informs the user if a upgrade is recommended.
    # Function requires linux boxes.
    # This func does not require prerequisite 'pvesource_bash_defaults.sh

    local pve_vers=$(pveversion -v | grep 'proxmox-ve:*' | awk '{ print $2 }' | sed 's/\..*$//')
    local kernel_vers=$(uname -r | cut -d'.' -f1,2)
    local pve7_kernel_min=5.19  # Recommended min Kernel version
    local pve8_kernel_min=6.2  # Recommended min Kernel version
    
    # Run PVE check
    if [ "$pve_vers" -lt 7 ]; then
        # Display msg for less than PVE7
        local msg_body1="#### URGENT: PROXMOX UPGRADE REQUIRED ####\n\nYour Proxmox version (v$pve_vers) is no longer supported. It is strongly recommended to update Proxmox to the latest version before proceeding with our scripts.\n\nIf you choose to continue using the current version, we cannot guarantee the stability or functionality of our scripts."
        echo -e "\e[33m$(echo -e "$msg_body1" | fmt -s -w 80 | boxes -n utf8 -d stone -p a1l3 -s 84)\e[0m"  # Display msg
        echo
        sleep 0.5
    elif [ "$pve_vers" = 7 ] && [ "$(echo "$kernel_vers" | awk -F. '{print $1$2}')" -lt "$(echo "$pve7_kernel_min" | sed 's/\.//g')" ]; then
        # Display msg for PVE7 wrong kernel
        msg_body2="Your Proxmox (v$pve_vers) installation is supported, but it requires an update to the kernel. To enable LXC to use iGPU rendering in Medialab applications, you must upgrade your kernel to at least version v$pve7_kernel_min.\n\nHere are the CLI commands to perform the kernel upgrade:\n\n  -- apt update\n  -- apt install pve-kernel-$pve7_kernel_min\nAlternatively, we recommend updating Proxmox to the latest version for the best overall performance and compatibility."
        echo -e "\e[33m$(echo -e "$msg_body2" | fmt -s -w 80 | boxes -n utf8 -d stone -p a1l3 -s 84)\e[0m"  # Display msg
        echo
        sleep 0.5
    elif [ "$pve_vers" = 8 ] && [ "$(echo "$kernel_vers" | awk -F. '{print $1$2}')" -lt "$(echo "$pve8_kernel_min" | sed 's/\.//g')" ]; then
        # Display msg for PVE8 wrong kernel
        msg_body3="Your Proxmox (v$pve_vers) installation is supported, but it requires an update to the kernel. To enable LXC to use iGPU rendering in Medialab applications, you must upgrade your kernel to at least version v$pve8_kernel_min.\n\nHere are the CLI commands to perform the kernel upgrade:\n\n  -- apt update\n  -- apt install pve-kernel-$pve8_kernel_min\nAlternatively, we recommend updating Proxmox to the latest version for the best overall performance and compatibility."
        echo -e "\e[33m$(echo -e "$msg_body3" | fmt -s -w 80 | boxes -n utf8 -d stone -p a1l3 -s 84)\e[0m"  # Display msg
        echo
        sleep 0.5
    else
        return  # Return to parent script
    fi

    # User read confirmation
    while true; do
        read -p "I have reviewed this information and understand. Proceed with this install [y/n]?: " -n 1 -r YN
        echo
        case $YN in
            [Yy]*)
            msg "You have been warned. Proceeding..."
            echo
            break
            ;;
            [Nn]*)
            info "The User has chosen to not to proceed. Smart decision..."
            echo
            sleep 1
            return 0
            ;;
            *)
            warn "Error! Entry must be 'y' or 'n'. Try again..."
            echo
            ;;
        esac
    done
}

#--- Basic bash sw requirements

function bash_shell_dep() {
  # Function checks for basic bash shell sw.
  # This func does not require prerequisite 'pvesource_bash_defaults.sh

  #--- Install BC
  if [[ ! $(dpkg -s bc 2> /dev/null) ]]; then
    apt-get install -y bc
  fi

  #--- Check for linux ascii boxes
  if command -v boxes > /dev/null; then
    current_ver=$(boxes -v | awk '{print $3}')  # Get the current version of boxes
  else
    current_ver=0
  fi
  latest_ver_tag=$(curl -s https://api.github.com/repos/ascii-boxes/boxes/releases/latest | grep -oP '"tag_name": "\K(.*?)(?=")')  # Get the latest version from GitHub releases
  latest_ver=$(echo "$latest_ver_tag" | sed 's/^v//')  # Remove the leading 'v' from the version number
  # Compare versions
  if [[ "$current_ver" < "$latest_ver" ]]; then
    echo "Updating ascii boxes to version $latest_ver_tag..."

    # Remove old apt install
    if [[ $(boxes -v 2> /dev/null) ]]; then
      apt-get remove -y boxes > /dev/null
    fi

    # Remove old manual install
    if [ -f "/usr/bin/boxes" ]; then
      rm "/usr/bin/boxes"
    fi

    # Install prerequisites 
    apt-get install -y build-essential diffutils flex bison libunistring-dev libpcre2-dev libcmocka-dev git vim-common
    
    # Download the latest version from GitHub releases
    wget "https://github.com/ascii-boxes/boxes/archive/$latest_ver_tag.tar.gz"

    # Install boxes
    tar -zxvf "$latest_ver_tag.tar.gz"
    cd "boxes-$latest_ver"
    make
    make utest
    make test
    cp ~/"boxes-$latest_ver"/boxes /usr/bin

    # Cleanup
    cd /
    rm -rf ~/"boxes-$latest_ver" "$latest_ver.tar.gz"
    echo "Boxes update complete..."
  fi
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Check for Basic bash sw requirements
bash_shell_dep

# Check PVE version status
pve_version_status

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