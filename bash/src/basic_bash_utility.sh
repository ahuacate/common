#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     bash_basic_defaults.sh
# Description:  Basic bash defaults for VMs and CTs
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Regex for functions
ip4_regex='^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
ip6_regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'
hostname_regex='^(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$'
domain_regex='^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$'
R_NUM='^[0-9]+$' # Check numerals only

#---- Terminal settings
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'
UNDERLINE=$'\033[4m'
printf '\033[8;40;120t'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Stop System.d Services
function pct_stop_systemctl() {
  # Usage: pct_stop_systemctl "name.service"
  local service_name="$1"
  if [ "$(systemctl is-active $service_name)" = 'active' ]
  then
    # Stop service
    sudo systemctl stop $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'inactive' ]]
    do
      echo -n .
    done
  fi
}

# Start System.d Services
function pct_start_systemctl() {
  # Usage: pct_start_systemctl "jellyfin.service"
  local service_name="$1"
  # Reload systemd manager configuration
  sudo systemctl daemon-reload
  if [ "$(systemctl is-active $service_name)" = 'inactive' ]
  then
    # Start service
    sudo systemctl start $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'active' ]]
    do
      echo -n .
    done
  fi
}

# Start System.d Services
function pct_restart_systemctl() {
  # Usage: pct_start_systemctl "jellyfin.service"
  local service_name="$1"
  # Reload systemd manager configuration
  sudo systemctl daemon-reload
  if [ "$(systemctl is-active $service_name)" = 'inactive' ]
  then
    # Start service
    sudo systemctl start $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'active' ]]
    do
      echo -n .
    done
  elif [ "$(systemctl is-active $service_name)" = 'active' ]
  then
    # Stop service
    sudo systemctl stop $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'inactive' ]]
    do
      echo -n .
    done
    # Start service
    sudo systemctl start $service_name
    # Waiting to hear from service
    while ! [[ "$(systemctl is-active $service_name)" == 'active' ]]
    do
      echo -n .
    done
  fi
}

# Edit json file value
edit_json_value() {
  # Usage: edit_json_value config.json name "Jane"
  # Check for jq SW
  if [[ ! $(dpkg -s jq 2>/dev/null) ]]
  then
    apt-get install jq -yqq
  fi

  local file=$1
  local key=$2
  local value=$3
  tmp_file=$(mktemp)
  jq ".$key = \"$value\"" $file > $tmp_file && mv $tmp_file $file
}

# Get a Variable value
function get_config_value() {
  # Get a key value in a conf/cfg file
  # Example line of conf/cfg file:
  #   pf_enable=0 # This variable sets the 'pf_enable' variable
  #   pf_enable="0"
  #   pf_enable="once upon a time" # This variable sets the 'pf_enable' variable
  # Usage:
  #   get_var "/usr/local/bin/kodirsync/kodirsync.conf" "pf_enable"
  # Output:
  #   get_var=0 or get_var="once upon a time"

  # Check if all mandatory arguments have been provided
  if [ -z "$1" ] || [ -z "$2" ]
  then
    echo "Error: missing mandatory argument(s)"
    exit 1
  fi

  # Function arguments
  local config_file="$1"
  local key="$2"

  unset get_var
  get_var=$(awk -F "=" -v VAR="$key" '
    # Split the line into fields
    { split($0, fields, "=") }
    # Check if the first field matches the variable name
    fields[1] == VAR {
      # Set the value of the variable to the second field
      value = fields[2]
      # Remove any text after the # character
      gsub(/#.*/, "", value)
      # Print the value of the variable
      print value
    }' "${config_file}" | tr -d '"')
  # Check the exit status
  if [ -z "$get_var" ]; then
    # Print a message if the command failed
    echo "No variable found."
  fi
}

# Edit or Add a Conf file key pair
function edit_config_value() {
  # Edit or Add key value pair in a conf/cfg file
  # Matches hashed-out # key-pairs and removes #
  # Usage:
  #   edit_config_value "/path/to/src/file" "key" "value" "comment"
  #   edit_config_value "/usr/local/bin/kodirsync/kodirsync.conf" "pf_enable" "1"
  # Output:
  #   variable="1" # Comment line here (optional)

  # Check if all three mandatory arguments have been provided
  # $4 (Comment) is optional
  if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]
  then
    echo "Error: missing mandatory argument(s)"
    exit 1
  fi

  # Function arguments
  local config_file="$1"
  local key="$2"
  local value="$3"
  local comment="${4:-}"

  # Escape any special characters in the value and comment
  value=$(echo "$value" | sed 's/[\/&]/\\&/g')
  comment=$(echo "$comment" | sed 's/[\/&]/\\&/g')

  # Check if the key exists in the config file
  if egrep -q "^(#)?(\s)?$key(\s)?=" "$config_file"
  then
    # Extract the existing comment line, if it exists
    existing_comment=$(egrep "^(#)?(\s)?$key(\s)?=" "$config_file" | sed -n "s/^\(\s*\)#\{0,1\}\(\s*\)$key\(\s*\)= *\([^#]*\) *#\(.*\)/#\2/p")

    # Replace the value in the config file
    if [ -z "$comment" ]
    then
      # If no comment is provided, use the existing comment line
      sed -i "s/^\(\s*\)#\{0,1\}\(\s*\)$key\(\s*\)=.*/$key=\"$value\" $existing_comment/" "$config_file"
    else
      # If a comment is provided, use the new comment line
      sed -i "s/^\(\s*\)#\{0,1\}\(\s*\)$key\(\s*\)=.*/$key=\"$value\" # $comment/" "$config_file"
    fi
  else
    # Add the key-value pair to the end of the config file
    if [ -z "$comment" ]
    then
      # If no comment is provided, don't include a comment line
      echo "$key=\"$value\"" >> "$config_file"
    else
      # If a comment is provided, include the comment line
      echo "$key=\"$value\" # $comment" >> "$config_file"
    fi
  fi
}


#-----------------------------------------------------------------------------------