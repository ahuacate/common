#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_bash_defaults.sh
# Description:  Source script bash defaults
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

set -Eeuo pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
trap cleanup EXIT

function error_exit() {
  trap - ERR
  local DEFAULT='Unknown failure occurred.'
  local REASON="\e[97m${1:-$DEFAULT}\e[39m"
  local FLAG="\e[91m[ERROR] \e[93m$EXIT@$LINE"
  msg "$FLAG $REASON"
  [ ! -z ${CTID-} ] && cleanup_failed
  exit $EXIT
}
function cleanup_failed () {
  if [ ! -z ${MOUNT+x} ]; then
    pct unmount $CTID
  fi
  if $(pct status $CTID &> /dev/null); then
    if [ "$(pct status $CTID | awk '{print $2}')" == "running" ]; then
      pct stop $CTID
    fi
    pct destroy $CTID
  elif [ "$(pvesm list $STORAGE --vmid $CTID)" != "" ]; then
    pvesm free $ROOTFS
  fi
}
function pushd () {
  command pushd "$@" &> /dev/null
}
function popd () {
  command popd "$@" &> /dev/null
}
function cleanup() {
  popd
  rm -rf $TEMP_DIR
  unset TEMP_DIR
}
function load_module() {
  if ! $(lsmod | grep -Fq $1); then
    modprobe $1 &> /dev/null || \
      die "Failed to load '$1' module."
  fi
  MODULES_PATH=/etc/modules
  if ! $(grep -Fxq "$1" $MODULES_PATH); then
    echo "$1" >> $MODULES_PATH || \
      die "Failed to add '$1' module to load at boot."
  fi
}

#---- User and Password Functions
# Make a USERNAME with validation
function input_username_val() {
  while true
  do
    read -p "Enter a new user name : " USERNAME
    if [ ${#USERNAME} -gt 18 ];then
    msg "User name ${WHITE}'${USERNAME}'${NC} is not valid. A user name is considered valid when all of the following constraints are satisfied:\n\n  --  it contains only lowercase characters\n  --  it begins with 3 alphabet characters\n  --  it contains at least 5 characters and at most is 18 characters long\n  --  it may include numerics and underscores\n  --  it doesn't contain any hyphens, periods or special characters [!#$&%*+-]\n  --  it doesn't contain any white space\n\nTry again...\n"
    elif [[ ${USERNAME} =~ ^([a-z]{3})([_]?[a-z\d]){2,15}$ ]]; then
      info "Your user name is set : ${YELLOW}${USERNAME}${NC}"
      echo
      break
    else
      msg "User name ${WHITE}'${USERNAME}'${NC} is not valid. A user name is considered valid when all of the following constraints are satisfied:\n\n  --  it contains only lowercase characters\n  --  it begins with 3 alphabet characters\n  --  it contains at least 5 characters and at most is 18 characters long\n  --  it may include numerics and underscores\n  --  it doesn't contain any hyphens, periods or special characters [!#$&%*+-]\n  --  it doesn't contain any white space\n\nTry again...\n"
    fi
  done
}


# Input a USER_PWD with validation. Requires libcrack2
function input_userpwd_val() {
  # Install libcrack2
  if [ $(dpkg -s libcrack2 >/dev/null 2>&1; echo $?) != 0 ]; then
  a pt-get install -y libcrack2 > /dev/null
  fi
  while true
  do
    read -p "Enter a password for ${USERNAME}: " USER_PWD
    msg "Testing password strength..."
    result="$(cracklib-check <<<"$USER_PWD")"
    # okay awk is  bad choice but this is a demo 
    okay="$(awk -F': ' '{ print $2}' <<<"$result")"
    if [[ "$okay" == "OK" ]]
    then
      info "Your password is set : ${YELLOW}${USER_PWD}${NC}"
      echo
      break
    else
      warn "Your password was rejected - $result. Try again..."
      echo
    fi
  done
}

# Make a USER_PWD. Requires makepasswd
function make_userpwd() {
  # Install makepasswd
  if [ $(dpkg -s makepasswd >/dev/null 2>&1; echo $?) != 0 ]; then
    apt-get install -y makepasswd > /dev/null
  fi
  msg "Creating a 13 character password..."
  USER_PWD=$(makepasswd --chars 13)
  info "If you have configured Postfix your credentials will be emailed to\nyour administrator. Your password is set : ${YELLOW}${USER_PWD}${NC}"
  echo
}

#---- Bash Messaging Functions
if [ $(dpkg -s boxes > /dev/null 2>&1; echo $?) = 1 ]; then
  apt-get install -y boxes > /dev/null
fi
function msg() {
  local TEXT="$1"
  echo -e "$TEXT" | fmt -s -w 80 
}
function msg_nofmt() {
  local TEXT="$1"
  echo -e "$TEXT"
}
function warn() {
  local REASON="${WHITE}$1${NC}"
  local FLAG="${RED}[WARNING]${NC}"
  msg "$FLAG"
  msg "$REASON"
}
function info() {
  local REASON="$1"
  local FLAG="\e[36m[INFO]\e[39m"
  msg_nofmt "$FLAG $REASON"
}
function section() {
  local REASON="\e[97m$1\e[37m"
  printf -- '-%.0s' {1..84}; echo ""
  msg "  $SECTION_HEAD - $REASON"
  printf -- '-%.0s' {1..84}; echo ""
  echo
}
function msg_box () {
  echo -e "$1" | fmt -w 80 | boxes -d stone -p a1l3 -s 84
}
function indent() {
    eval "$@" |& sed "s/^/\t/"
    return "$PIPESTATUS"
}

#### Detect modules and automatically load at boot
load_module aufs
load_module overlay

#### Terminal
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'
printf '\033[8;40;120t'

#### Set Bash Temp Folder
if [ -z "${TEMP_DIR+x}" ]; then
    TEMP_DIR=$(mktemp -d)
    pushd $TEMP_DIR > /dev/null
else
    if [ $(pwd -P) != $TEMP_DIR ]; then
    cd $TEMP_DIR > /dev/null
    fi
fi