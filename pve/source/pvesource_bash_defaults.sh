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
  rm -rf $TEMP_DIR &> /dev/null
  unset TEMP_DIR
  # rm -R /tmp/*
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
  apt-get install -y libcrack2 > /dev/null
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

# PCT start and wait loop command
function pct_start_waitloop() {
  if [ "$(pct status ${CTID})" == "status: stopped" ]; then
    msg "Starting CT ${CTID}..."
    pct start ${CTID}
    msg "Waiting to hear from CT ${CTID}..."
    while ! [[ "$(pct status ${CTID})" == "status: running" ]]; do
      echo -n .
    done
    sleep 2
    info "CT ${CTID} status: ${GREEN}running${NC}"
    echo
  fi
}

# PCT stop and wait loop command
function pct_stop_waitloop() {
  if [ "$(pct status ${CTID})" == "status: running" ]; then
    msg "Stopping CT ${CTID}..."
    pct stop ${CTID}
    msg "Waiting to hear from CT ${CTID}..."
    while ! [[ "$(pct status ${CTID})" == "status: stopped" ]]; do
      echo -n .
    done
    sleep 2
    info "CT ${CTID} status: ${GREEN}stopped${NC}"
    echo
  fi
}

# PCT list
function pct_list() {
  pct list | perl -lne '
  if ($. == 1) {
      @head = ( /(\S+\s*)/g );
      pop @head;
      $patt = "^";
      $patt .= "(.{" . length($_) . "})" for @head;
      $patt .= "(.*)\$";
  }
  print join ",", map {s/"/""/g; s/\s+$//; qq($_)} (/$patt/o);'
}

#---- Folder name functions
# Make a folder name with validation
function input_dirname_val() {
  while true; do
    read -p "Enter a new folder name : " DIR_NAME
    DIR_NAME=${DIR_NAME,,}
    if [[ "${DIR_NAME}" =~ ^([a-z])([_]?[a-z\d]){3,15}$ ]]; then
      info "Your user name is set : ${YELLOW}${DIR_NAME}${NC}"
      echo
      break
    else
      msg "The folder name ${WHITE}'${DIR_NAME}'${NC} is not valid. A folder name is considered valid when all of the following constraints are satisfied:\n\n  --  it contains only lowercase characters\n  --  it contains at least 3 characters and at most is 12 characters long\n  --  it may include underscores\n  --  it doesn't start or end with a underscore\n  --  it doesn't contain any numerics or special characters [!#$&%*+-]\n  --  it doesn't contain any white space\n\nTry again..."
    fi
  done
}

#---- Menu item select functions
function makeselect_input1 () {
  # Example:
  # Use with two input cmd vars: makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  # "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT" are two lists of input variables of equal number of lines.
  # "$OPTIONS_VALUES_INPUT" is the actual source vars ( OPTIONS_VALUES_INPUT=$(cat usb_disklist) )
  # "$OPTIONS_LABELS_INPUT" is a readable label input seen by the User ( OPTIONS_VALUES_INPUT=$(cat usb_disklist | awk -F':' '{ print "Disk ID:", $1, "Disk Size:"", $2 })' )
  # Works with Functions 'multiselect' and 'singleselect' and 'multiselect_confirm'
  mapfile -t OPTIONS_VALUES <<< "$1"
  mapfile -t OPTIONS_LABELS <<< "$2"
  unset OPTIONS_STRING
  unset RESULTS && unset results
  for i in "${!OPTIONS_VALUES[@]}"; do
    OPTIONS_STRING+="${OPTIONS_LABELS[$i]};"
  done
}
function makeselect_input2 () {
    # Example:
    # OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" )
    # OPTIONS_LABELS_INPUT=( "Destroy & Rebuild" "Use Existing" "None. Try again" )
    # Both input must be a array string
    # Use cmd: makeselect_input2
    unset OPTIONS_STRING
    unset RESULTS && unset results
    unset OPTIONS_VALUES
    unset OPTIONS_LABELS
    OPTIONS_VALUES+=("${OPTIONS_VALUES_INPUT[@]}")
    OPTIONS_LABELS+=("${OPTIONS_LABELS_INPUT[@]}")
    for i in "${!OPTIONS_VALUES[@]}"; do
        OPTIONS_STRING+="${OPTIONS_LABELS[$i]};"
    done
}
# Multiple item selection
function multiselect () {
  # Modded version of this persons work: https://stackoverflow.com/a/54261882/317605 (by https://stackoverflow.com/users/8207842/dols3m)
  # To run: multiselect SELECTED "$OPTIONS_STRING"
  # To get output results: printf '%s\n' "${RESULTS[@]}"
  echo -e "Select menu items (multiple) with 'arrow keys \U2191\U2193', 'space bar' to select or deselect, and confirm/done with 'Enter key'. You can select multiple menu items. Your options are:" | fmt -s -w 80
  ESC=$( printf "\033")
  cursor_blink_on()   { printf "$ESC[?25h"; }
  cursor_blink_off()  { printf "$ESC[?25l"; }
  cursor_to()         { printf "$ESC[$1;${2:-1}H"; }
  print_inactive()    { printf "  $2  $1 "; }
  print_active()      { printf "  $2 $ESC[7m $1 $ESC[27m"; }
  get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
  key_input()         {
    local key
    IFS= read -rsn1 key 2>/dev/null >&2
    if [[ $key = ""      ]]; then echo enter; fi;
    if [[ $key = $'\x20' ]]; then echo space; fi;
    if [[ $key = $'\x1b' ]]; then
      read -rsn2 key
      if [[ $key = [A ]]; then echo up;    fi;
      if [[ $key = [B ]]; then echo down;  fi;
    fi 
  }
  toggle_option()    {
    local arr_name=$1
    eval "local arr=(\"\${${arr_name}[@]}\")"
    local option=$2
    if [[ ${arr[option]} == true ]]; then
      arr[option]=
    else
      arr[option]=true
    fi
    eval $arr_name='("${arr[@]}")'
  }

  local retval=$1
  local options
  local defaults

  IFS=';' read -r -a options <<< "$2"
  if [[ -z ${3:-default} ]]; then
    defaults=()
  else
    IFS=';' read -r -a defaults <<< "${3:-default}"
  fi
  local selected=()

  for ((i=0; i<${#options[@]}; i++)); do
    selected+=("${defaults[i]:-false}")
    printf "\n"
  done

  # determine current screen position for overwriting the options
  local lastrow=`get_cursor_row`
  local startrow=$(($lastrow - ${#options[@]}))

  # ensure cursor and input echoing back on upon a ctrl+c during read -s
  trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
  cursor_blink_off

  local active=0
  while true; do
      set +ue
      trap - ERR
      # print options by overwriting the last lines
      local idx=0
      for option in "${options[@]}"; do
          local prefix="$(($idx + 1)). [ ]"
          if [[ ${selected[idx]} == true ]]; then
            prefix="$(($idx + 1)). [x]"
          fi

          cursor_to $(($startrow + $idx))
          if [ $idx -eq $active ]; then
              print_active "$option" "$prefix"
          else
              print_inactive "$option" "$prefix"
          fi
          ((idx++))
      done

      # user key control
      case `key_input` in
          space)  toggle_option selected $active;;
          enter)  break;;
          up)     ((active--));
                  if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
          down)   ((active++));
                  if [ $active -ge ${#options[@]} ]; then active=0; fi;;
      esac
      set -ue
      trap die ERR
  done

  # cursor position back to normal
  cursor_to $lastrow
  printf "\n"
  cursor_blink_on

  eval $retval='("${selected[@]}")'

  # output
  unset PRINT_RESULTS
  unset results
  unset RESULTS
  for i in "${!selected[@]}"; do
    if [ "${selected[$i]}" == "true" ]; then
      results+=("${OPTIONS_VALUES[$i]}")
      RESULTS+=("${OPTIONS_VALUES[$i]}")
      PRINT_RESULTS+=("${OPTIONS_LABELS[$i]}")
    fi
  done
  echo "User has selected:"
  printf '    %s\n' ${YELLOW}"${PRINT_RESULTS[@]}"${NC}
  echo
}
# Multiple item selection with confirmation loop
function multiselect_confirm () {
  # Modded version of this persons work: https://stackoverflow.com/a/54261882/317605 (by https://stackoverflow.com/users/8207842/dols3m)
  # To run: multiselect_confirm SELECTED "$OPTIONS_STRING"
  # To get output results: printf '%s\n' "${RESULTS[@]}"
  while true; do
    multiselect "$1" "$2"
    read -p "User accepts the final selection: [y/n]?" -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        info "Selection status: ${YELLOW}accepted${NC}"
        echo
        break
        ;;
      [Nn]*)
        info "No problem. Try again..."
        echo
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
}
# Single item selection only
function singleselect () {
  # Modded version of this persons work: https://stackoverflow.com/a/54261882/317605 (by https://stackoverflow.com/users/8207842/dols3m)
  # To run: singleselect SELECTED "$OPTIONS_STRING"
  # To get output results: printf '%s\n' "${RESULTS[@]}"
  unset RESULTS && unset results
  echo -e "Select menu item with 'arrow keys \U2191\U2193' and confirm/done with 'Enter key'. Your options are:" | fmt -s -w 80
  ESC=$( printf "\033")
  cursor_blink_on()   { printf "$ESC[?25h"; }
  cursor_blink_off()  { printf "$ESC[?25l"; }
  cursor_to()         { printf "$ESC[$1;${2:-1}H"; }
  print_inactive()    { printf "  $2  $1 "; }
  print_active()      { printf "  $2 $ESC[7m $1 $ESC[27m"; }
  get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
  key_input()         {
    local key
    IFS= read -rsn1 key 2>/dev/null >&2
    if [[ $key = ""      ]]; then echo enter; fi;
    # if [[ $key = $'\x20' ]]; then echo space; fi;
    if [[ $key = $'\x1b' ]]; then
      read -rsn2 key
      if [[ $key = [A ]]; then echo up;    fi;
      if [[ $key = [B ]]; then echo down;  fi;
    fi 
  }

  toggle_option()  {
    local arr_name=$1
    eval "local arr=(\"\${${arr_name}[@]}\")"
    local option=$2
    if [[ ${arr[option]} == true ]]; then
      arr[option]=
    else
      arr[option]=true
    fi
    eval $arr_name='("${arr[@]}")'
  }

  local retval=$1
  local options
  local defaults

  IFS=';' read -r -a options <<< "$2"
  if [[ -z ${3:-default} ]]; then
    defaults=()
  else
    IFS=';' read -r -a defaults <<< "${3:-default}"
  fi
  local selected=()

  for ((i=0; i<${#options[@]}; i++)); do
    selected+=("${defaults[i]:-false}")
    printf "\n"
  done

  # determine current screen position for overwriting the options
  local lastrow=`get_cursor_row`
  local startrow=$(($lastrow - ${#options[@]}))

  # ensure cursor and input echoing back on upon a ctrl+c during read -s
  trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
  cursor_blink_off

  local active=0
  while true; do
      set +ue
      trap - ERR
      # print options by overwriting the last lines
      local idx=0
      for option in "${options[@]}"; do
          local prefix="$(($idx + 1)). [ ]"
          if [[ $idx -eq $active ]]; then
            prefix="$(($idx + 1)). [x]"
          fi

          cursor_to $(($startrow + $idx))
          if [ $idx -eq $active ]; then
              print_active "${option}" "$prefix"
          else
              print_inactive "$option" "$prefix"
          fi
          ((idx++))
      done

      # user key control
      case `key_input` in
          enter)  toggle_option selected $active; break;;
          up)     ((active--));
                  if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
          down)   ((active++));
                  if [ $active -ge ${#options[@]} ]; then active=0; fi;;
      esac
      set -ue
      trap die ERR
  done

  # cursor position back to normal
  cursor_to $lastrow
  printf "\n"
  cursor_blink_on

  eval $retval='("${selected[@]}")'

  # output
  unset PRINT_RESULTS
  unset results
  unset RESULTS
  for i in "${!selected[@]}"; do
    if [ "${selected[$i]}" == "true" ]; then
      results+=("${OPTIONS_VALUES[$i]}")
      RESULTS+=("${OPTIONS_VALUES[$i]}")
      PRINT_RESULTS+=("${OPTIONS_LABELS[$i]}")
    fi
  done
  echo "User has selected:"
  printf '    %s\n' ${YELLOW}"${PRINT_RESULTS[@]}"${NC}
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
  echo -e "$1" | fmt -w 80 -s | boxes -d stone -p a1l3 -s 84
}
function indent() {
    eval "$@" |& sed "s/^/\t/"
    return "$PIPESTATUS"
}
function indent2() { sed 's/^/  /'; } # Use with pipe echo 'sample' | indent2

#----  Detect modules and automatically load at boot
#load_module aufs
#load_module overlay

#---- Terminal settings
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'
UNDERLINE=$'\033[4m'
printf '\033[8;40;120t'

#---- Set Bash Temp Folder
if [ -z "${TEMP_DIR+x}" ]; then
    TEMP_DIR=$(mktemp -d)
    pushd $TEMP_DIR > /dev/null
else
    if [ $(pwd -P) != $TEMP_DIR ]; then
    cd $TEMP_DIR > /dev/null
    fi
fi