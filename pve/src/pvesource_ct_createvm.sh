#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_createvm.sh
# Description:  Source script for creating PVE CT containers
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Requires variable 'PRESET_VAR_SRC' - src path & filename of preset file.

#---- Static Variables -------------------------------------------------------------

# Set OS version
OSVERSION="$CT_OSVERSION"
OSTYPE="$CT_OSTYPE"

# Regex for Ipv4 and IPv6
ip4_regex='^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
ip6_regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Read variable file list
printsection() {
  # Example: $(printSection SECTION_NAME | sed -n 's/^name//p/' < /etc/applications.conf)
  section="$1"
  found=false

  # Run function
  while read line
  do
    [[ $found == false && "$line" != "#----[${section}]" ]] && continue
    [[ $found == true && "${line:0:6}" == '#----[' ]] && break
    found=true
    echo "$line" | sed '/^#/d' | sed -r '/^\s*$/d'
  done
}


#---- Body -------------------------------------------------------------------------

#---- Prerequisites
section "PVE CT Prerequisites"

# Update PVE CT OS template list
pveam update >/dev/null

# Check on latest CT OS version release template file
unset os_LIST
mapfile -t os_LIST < <(pveam available -section system | sed -n "s/.*\($OSTYPE-$OSVERSION.*\)/\1/p" | sort -t - -k 2 -V)
OS_TMPL="${os_LIST[-1]}"

# Set OS template storage location
unset tmpl_dir_LIST
tmpl_dir_LIST+=( "$(pvesm status -content vztmpl -enabled | awk 'NR>1 {print $1}')" )
if [ ${#tmpl_dir_LIST[@]} -eq '0' ]
then
  warn "A problem has occurred:\n  - Cannot determine PVE host CT template storage location (i.e vztmpl content ).\n  - Cannot proceed until the User creates a template location.\nAborting installation in 3 seconds..."
  echo
  exit 0
elif [ ${#tmpl_dir_LIST[@]} -eq '1' ]
then
  OS_TMPL_DIR=${tmpl_dir_LIST[0]}
elif [ ${#tmpl_dir_LIST[@]} -gt '1' ]
then
  msg "More than one PVE template location has been detected.\n\n$(pvesm status -content vztmpl -enabled | awk 'BEGIN { FIELDWIDTHS="$fieldwidths"; OFS=":" } { $6 = $6 / 1048576 } { if(NR>1) print $1, $2, $3, int($6) }' | column -s ":" -t -N "LOCATION,TYPE,STATUS,CAPACITY (GB)" | indent2)\n\nThe User must make a selection..."
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${tmpl_dir_LIST[@]}")
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${tmpl_dir_LIST[@]}")
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  OS_TMPL_DIR=${RESULTS}
  echo
fi

# Download CT template
if [ ! -f "/var/lib/vz/template/cache/${OS_TMPL}" ] || [ ! -f "/var/lib/pve/${OS_TMPL_DIR}/template/cache/${OS_TMPL}" ]
then
  msg "Downloading latest release of '${OSTYPE^} ${OSVERSION}' CT/LXC OS template ( be patient, might take a while )..."
  pveam download ${OS_TMPL_DIR} ${OS_TMPL} 2>&1
  if [ $? -ne 0 ]
  then
    warn "A problem occurred while downloading the CT/LXC OS version: ${OSTYPE}-${OSVERSION}\nCheck your internet connection and try again. Aborting installation in 3 seconds..."
    sleep 2
    exit 0
  fi
fi

# CT Install dir location
rootdir_LIST=( $(pvesm status -content rootdir -enabled | awk 'NR>1 {print $1}') )
if [ ${#rootdir_LIST[@]} -eq '0' ]
then
  warn "A problem has occurred:\n  - To create a new '${OSTYPE^} ${OSVERSION}' CT/LXC PVE requires a\n    valid storage location for a CT/LXC root volume.\n  - Cannot proceed until the User creates a storage location (i.e local-zfs).\nAborting installation in 3 seconds..."
  echo
  exit 0
elif [ ${#rootdir_LIST[@]} -eq '1' ]
then
  VOLUME="${rootdir_LIST[0]}"
elif [ ${#rootdir_LIST[@]} -gt '1' ]
then
  msg "More than one PVE storage location has been detected to use as a CT/LXC root volume.\n\n$(pvesm status -content rootdir -enabled | awk 'BEGIN { FIELDWIDTHS="$fieldwidths"; OFS=":" } { $6 = $6 / 1048576 } { if(NR>1) print $1, $2, $3, int($6) }' | column -s ":" -t -N "LOCATION,TYPE,STATUS,CAPACITY (GB)" | indent2)\n\nThe User must make a selection."
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${rootdir_LIST[@]}")
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${rootdir_LIST[@]}")
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  VOLUME=${RESULTS}
  info "CT root volume is set: ${YELLOW}${VOLUME}${NC}"
  echo
fi


#---- Validate & set architecture dependent variables
ARCH=$(dpkg --print-architecture)
OS_TEMPLATE="${OS_TMPL_DIR}:vztmpl/${OS_TMPL}"


#---- Create CT input arrays
# general_LIST array
general_LIST=()
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]
  then
    # Wrap Description var in quotes
    if [ "$var" = 'DESCRIPTION' ]
    then
      i=\"${i}\"
    fi
    general_LIST+=( "$(echo "--${var,,} ${i}")" )
  fi
done <<< $(printsection COMMON_GENERAL_OPTIONS < ${PRESET_VAR_SRC})
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]
  then
    general_LIST+=( "$(echo "--${var,,} ${i,,}")" )
  fi
done <<< $(printsection COMMON_NET_DNS_OPTIONS < ${PRESET_VAR_SRC})
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]
  then
    j=$(echo "$var" | sed 's/^CT_//')
    general_LIST+=( "$(echo "--${j,,} ${i}")" )
  fi
done <<< $(printsection CT_GENERAL_OPTIONS < ${PRESET_VAR_SRC})

# rootfs_LIST
rootfs_LIST=()
rootfs_LIST+=$(echo "--rootfs")
rootfs_LIST+=( "$(echo "${VOLUME}:${CT_SIZE}")" )
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]
  then
    j=$(echo ${var} | sed 's/^CT_//')
    rootfs_LIST+=( "$(echo "${j,,}=${i}")" )
  fi
done <<< $(printsection CT_ROOTFS_OPTIONS < ${PRESET_VAR_SRC} | grep -v '^CT_SIZE.*')

# net_LIST
net_LIST=()
net_LIST+=$(echo "--net0")
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]
  then
    # Ignore of tag=(0|1)
    if [ "$var" = TAG ] && [[ ${i} =~ ^(0|1)$ ]]
    then 
      continue
    fi
    net_LIST+=( "$(echo "${var,,}=${i}")" )
  fi
done <<< $(printsection COMMON_NET_OPTIONS < ${PRESET_VAR_SRC})
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]
  then
    j=$(echo ${var} | sed 's/^CT_//')
    net_LIST+=( "$(echo "${j,,}=${i}")" )
  fi
done <<< $(printsection CT_NET_OPTIONS < ${PRESET_VAR_SRC})
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]; then
    # Add CIDR value to IP/IP6
    if [ "$var" == 'IP' ] && [[ "$i" =~ ${ip4_regex} ]]
    then
      i=$(echo ${i} | sed "s/$/\/${CIDR}/")
    elif [ "$var" = 'IP' ] || [ "$var" = 'IP6' ] && [[ "$i" =~ 'dhcp' ]]
    then
      i=$(echo ${i})
    elif [ "$var" = 'IP6' ] && [[ $i =~ ${ip6_regex} ]]
    then
      i=$(echo ${i} | sed "s/$/\/${CIDR6}/")
    fi
    net_LIST+=( "$(echo "${var,,}=${i}")" )
  fi
done <<< $(printsection COMMON_NET_STATIC_OPTIONS < ${PRESET_VAR_SRC})

# features_LIST
features_LIST=()
features_LIST+=$(echo "--features")
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]
  then
    j=$(echo ${var} | sed 's/^CT_//')
    features_LIST+=( "$(echo "${j,,}=${i}")" )
  fi
done <<< $(printsection CT_FEATURES_OPTIONS < ${PRESET_VAR_SRC})

# startup_LIST
startup_LIST=()
startup_LIST+=$(echo "--startup")
while IFS== read var value
do
  eval i='$'$var
  if [ -n "${i}" ]
  then
    j=$(echo ${var} | sed 's/^CT_//')
    startup_LIST+=( "$(echo "${j,,}=${i}")" )
  fi
done <<< $(printsection CT_STARTUP_OPTIONS < ${PRESET_VAR_SRC})


#---- Create CT
# Create CT variables
pct_create_LIST=()
# OS installer template
pct_create_LIST+=( "$(echo "${CTID} ${OS_TEMPLATE}")" )
# general_LIST vars
if [ ${#general_LIST[@]} -ge 1 ]
then
  pct_create_LIST+=( "$(printf '%s\n' "${general_LIST[@]}" | sed 's/$//')" )
fi
# rootfs_LIST vars
pct_create_LIST+=( "$(printf '%s\n' "${rootfs_LIST[@]}" | xargs | sed 's/ /,/2g')" )
# net_LIST vars
pct_create_LIST+=( "$(printf '%s\n' "${net_LIST[@]}" | xargs | sed 's/ /,/2g')" )
# features_LIST vars
if [ ${#features_LIST[@]} -ge 2 ]
then
  pct_create_LIST+=( "$(printf '%s\n' "${features_LIST[@]}" | xargs | sed 's/ /,/2g')" )
fi
# startup_LIST vars
if [ ${#startup_LIST[@]} -ge 2 ]
then
  pct_create_LIST+=( "$(printf '%s\n' "${startup_LIST[@]}" | xargs | sed 's/ /,/2g')" )
fi

# Create CT
msg "Creating ${HOSTNAME^} CT..."
pct create $(printf '%s ' "${pct_create_LIST[@]}" | sed 's/$//')
echo

# Check CT Status
sleep 2
if [ "$(pct list | grep -w "^$CTID" > /dev/null; echo $?)" = 0 ]
then
    info "${HOSTNAME^} CT has been created. Current status: ${YELLOW}$(pct status $CTID | awk '{print $2}')${NC}"
    echo
elif [ ! "$(pct list | grep -w "^$CTID" > /dev/null; echo $?)" = 0 ]
then
  warn "Something went wrong. ${HOSTNAME^} CT has NOT been created. Aborting this installation."
  echo
  trap cleanup EXIT
fi
#-----------------------------------------------------------------------------------