#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_autoupdater_installer.sh
# Description:  Systemd updater for CT OS and installed applications
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Check for CT updater script
if [ ! -f "${SRC_DIR}/${APP_DIR}/update-ct.sh" ]; then
  return
fi

#---- Introduction
section "Install Application & OS auto-updater"
msg_box "#### PLEASE READ CAREFULLY ####

You have the option to install our Application & OS 'auto-updater' service. The 'auto-updater' will perform the following tasks weekly:

\t-- Update & Upgrade CT OS
\t-- Update & Upgrade all installed software

The tasks will be performed on calendar Sundays after 0300hr at randomized intervals. The 'auto-updater' uses a systemd timer unit."
sleep 1

echo
while true; do
  read -p "Install 'auto-updater' (Recommended) [y/n]? " -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      info "Configured for 'auto-updater'."
      echo
      break
      ;;
    [Nn]*)
      info "You have chosen to skip this step."
      echo
      return
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done

#---- Create 'auto-dater' service
# Push updater script to CT
pct push $CTID ${SRC_DIR}/${APP_DIR}/update-ct.sh /usr/local/sbin/update-ct.sh
pct exec $CTID -- bash -c 'sudo chmod a+x /usr/local/sbin/update-ct.sh'

# Create a systemd service for the updater
cat << 'EOF' > ${DIR}/update-ct.service 
[Unit]
Description=Update OS & Applications
After=network-online.target
  
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/update-ct.sh
EOF
pct push $CTID ${DIR}/update-ct.service /etc/systemd/system/update-ct.service

# Create a systemd timer
# Default time is Monday 03:00
cat << 'EOF' > ${DIR}/update-ct.timer 
[Unit]
Description=Timer for updating OS & Applications
Wants=network-online.target
  
[Timer]
OnBootSec=
OnCalendar=Sun *-*-* 03:00:00
RandomizedDelaySec=300
AccuracySec=1us
Persistent=true
 
[Install]
WantedBy=timers.target
EOF
pct push $CTID ${DIR}/update-ct.timer /etc/systemd/system/update-ct.timer

# Enable systemd timer
pct exec $CTID -- bash -c 'sudo systemctl --quiet daemon-reload'
pct exec $CTID -- bash -c 'sudo systemctl --quiet enable --now update-ct.timer'
#-----------------------------------------------------------------------------------