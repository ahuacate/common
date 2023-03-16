#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_precheck_hostsmtp.sh
# Description:  Source script to verify SMTP is configured on the PVE host
#               Requires function 'check_smtp_status'
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Local network
LOCAL_NET=$(hostname -I | awk -F'.' -v OFS="." '{ print $1,$2,"0.0/16" }')

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Check SMTP status

# Check SMTP Status
check_smtp_status

# Set SMTP options manually
if [ "$SMTP_STATUS" = 0 ]
then
  # Options if SMTP is inactive
  file='/etc/postfix/main.cf'

  # Set cnt checker number
  k=0
  chk_min=6

  precheck_msg1=()
  precheck_error_msg1=()
  # Pre-check Postfix
  if [ "$(systemctl is-active --quiet postfix; echo $?)" = 0 ]
  then
    precheck_msg1+=( "Postfix service status:active" )
    # Pre-check cnt
    ((k=k+1))
  else
    precheck_msg1+=( "Postfix service status:inactive" )
    precheck_error_msg1+=( "Postfix service status: fail (inactive)" )
  fi
  # Pre-check aquacate ES SMTP
  if [ "$(grep --color=never -Po "^${var}=\K.*" "${file}" || true)" = 1 ]
  then
    precheck_msg1+=( "aquacate SMTP Easy Script status:pass" )
  else
    precheck_msg1+=( "aquacate SMTP Easy Script status:not installed (not required for manual configs)" )
  fi
  # Check Global (Main) configure Postfix configuration file /etc/postfix/main.cf
  # Pre-check mynetworks
  if [[ $(postconf mynetworks 2> /dev/null | grep '127.0.0.0' | grep "${LOCAL_NET}" || true) ]]
  then
    precheck_msg1+=( "Postfix conf - 'mynetworks':pass" )
    # Pre-check cnt
    ((k=k+1))
  else
    precheck_msg1+=( "Postfix conf - 'mynetworks':fail (requires '127.0.0.0/8, ${LOCAL_NET}')" )
    precheck_error_msg1+=( "Postfix conf - 'mynetworks':fail (requires '127.0.0.0/8, ${LOCAL_NET}')" )
  fi
  # Pre-check inet_interfaces
  if [[ $(postconf inet_interfaces 2> /dev/null | grep 'all' || true) ]]
  then
    precheck_msg1+=( "Postfix conf - 'inet_interfaces':pass" )
    # Pre-check cnt
    ((k=k+1))
  else
    precheck_msg1+=( "Postfix conf - 'inet_interfaces':fail (requires 'all')" )
    precheck_error_msg1+=( "Postfix conf - 'inet_interfaces':fail (requires 'all')" )
  fi
  # Pre-check smtpd_recipient_restrictions
  if [[ $(postconf smtpd_recipient_restrictions 2> /dev/null | grep 'permit_mynetworks' || true) ]]
  then
    precheck_msg1+=( "Postfix conf - 'smtpd_recipient_restrictions':pass" )
    # Pre-check cnt
    ((k=k+1))
  else
    precheck_msg1+=( "Postfix conf - 'smtpd_recipient_restrictions':fail (requires 'permit_mynetworks')" )
    precheck_error_msg1+=( "Postfix conf - 'smtpd_recipient_restrictions':fail (requires 'permit_mynetworks')" )
  fi
  # Pre-check smtpd_client_restrictions
  if [[ $(postconf smtpd_client_restrictions 2> /dev/null | grep 'permit_mynetworks' || true) ]]
  then
    precheck_msg1+=( "Postfix conf - 'smtpd_client_restrictions':pass" )
    # Pre-check cnt
    ((k=k+1))
  else
    precheck_msg1+=( "Postfix conf - 'smtpd_client_restrictions':fail (requires 'permit_mynetworks')" )
    precheck_error_msg1+=( "Postfix conf - 'smtpd_client_restrictions':fail (requires 'permit_mynetworks')" )
  fi
  # Pre-check smtpd_relay_restrictions
  if [[ $(postconf smtpd_relay_restrictions 2> /dev/null | grep 'permit_mynetworks' || true) ]]
  then
    precheck_msg1+=( "Postfix conf - 'smtpd_relay_restrictions':pass" )
    # Pre-check cnt
    ((k=k+1))
  else
    precheck_msg1+=( "Postfix conf - 'smtpd_relay_restrictions':fail ( requires 'permit_mynetworks')" )
    precheck_error_msg1+=( "Postfix conf - 'smtpd_relay_restrictions':fail ( requires 'permit_mynetworks')" )
  fi

  display_msg="A problem exists with your PVE host SMTP Postfix server.\n\n$(printf '%s\n' "${precheck_msg1[@]}" | column -s ":" -t -N "DESCRIPTION,STATUS" | indent2)\n\nBefore proceeding with this installation we recommend you configure all PVE hosts to support SMTP email services (including SMTP client relay). A working SMTP server can email your Proxmox System Administrator all new User login credentials, SSH keys, application specific login credentials and written guidelines. A PVE host SMTP server makes administration much easier. Also be alerted about unwarranted login attempts and other system critical alerts.\n\nA PVE Host SMTP Server installer is available in our PVE Host Toolbox at GitHub:\n\n    --  https://github.com/aquacate/pve-host"


  msg_box "#### PLEASE READ CAREFULLY ####\n\n${display_msg}"
  echo
  msg "Select your options..."
  OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE00" )
  OPTIONS_LABELS_INPUT=( "Stop - Install PVE host Postfix SMTP email support" \
  "Proceed - Postfix SMTP works (my manual setup) & supports client SMTP relay" \
  "Proceed - Without SMTP email support" \
  "None. Exit this installer" )
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"

  if [ "$RESULTS" = 'TYPE01' ]
  then
    # Exit and install SMTP
    msg "Go to our Github repository and run our PVE Host Toolbox selecting our 'SMTP Email Setup' option:\n\n  --  https://github.com/aquacate/pve-host\n\nRe-run this installer after your have configured '$(hostname)' SMTP email support. Bye..."
    echo
    exit 0
  elif [ "$RESULTS" = 'TYPE02' ]
  then
    # Proceed without SMTP email support
    if [ "${k}" -lt "${chk_min}" ]
    then
      display_error_msg="Your Proxmox Postfix SMTP server configuration appears to not meet our requirements. Check your Postfix file '/etc/postfix/main.cf' is configured to support relaying emails from your network VM/CT clients. Reported errors are:\n\n$(printf '%s\n' "${precheck_error_msg1[@]}" | column -s ":" -t -N "DESCRIPTION,STATUS" | indent2)\n\nFix the issues or choose to proceed without VM/CT SMTP email services."
      msg "#### PLEASE READ CAREFULLY ####\n\n${display_error_msg}"

      msg "Select your options..."
      OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE00" )
      OPTIONS_LABELS_INPUT=( "Proceed without VM/CT SMTP working services" \
      "None. Exit this installer" )
      makeselect_input2
      singleselect SELECTED "$OPTIONS_STRING"
      if [ "$RESULTS" = 'TYPE01' ]
      then
        # Proceed without SMTP email support
        msg "You have chosen to proceed without SMTP email support. You can always manually configure Postfix SMTP services at a later stage. We recommend you do so."
        echo
      elif [ "$RESULTS" = 'TYPE00' ]
      then
        msg "You have chosen not to proceed. Aborting. Bye..."
        echo
        exit 0
      fi
    else
      # Adding fix to SMTP checker var
      sed -i \
      -e '/^#\?\(\s*aquacate_smtp\s*=\s*\).*/{s//\11/;:a;n;ba;q}' \
      -e '1i aquacate_smtp=1' /etc/postfix/main.cf
      SMTP_STATUS=1
    fi
    echo
  elif [ "$RESULTS" = 'TYPE03' ]
  then
    # Proceed without SMTP email support
    msg "You have chosen to proceed without SMTP email support. You can always manually configure Postfix SMTP services at a later stage. We recommend you do so."
    echo
  elif [ "$RESULTS" = 'TYPE00' ]
  then
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    exit 0
  fi
fi
#-----------------------------------------------------------------------------------