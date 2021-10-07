#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_ubuntu_installfail2ban.sh
# Description:  Source script for installing Fail2Ban
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SOURCE="${DIR}"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source ${DIR}/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='Fail2Ban'

# Fail2Ban Retry limit
MAX_RETRY='3'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Install and Configure Fail2Ban
section "Installing and configuring Fail2Ban."

# Install Fail2Ban 
msg "Installing Fail2Ban..."
apt-get install -y fail2ban >/dev/null

# Configuring Fail2Ban
msg "Configuring Fail2Ban..."
systemctl start fail2ban 2>/dev/null
systemctl enable fail2ban 2>/dev/null
cat << EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = $MAX_RETRY
EOF

# Starting Fail2ban service 
msg "Checking Fail2ban status..."
if [ $(systemctl is-active fail2ban.service) != "active" ]; then
  systemctl start fail2ban.service
  while true; do
    if [ $(systemctl is-active fail2ban.service) == "active" ]; then
      info "Fail2ban status: ${GREEN}active${NC} (running)."
      echo
      break
    fi
    sleep 2
  done
fi


#---- Finish Line ------------------------------------------------------------------
section "Completion Status."
msg "${WHITE}Success.${NC} Fail2Ban has been configured.\n  --  Monitored SSH Port: ${YELLOW}$SSH_PORT${NC}\n  --  Maximum retry limit: ${YELLOW}$MAX_RETRY${NC}\n"

# Cleanup
if [ -z "${PARENT_EXEC+x}" ]; then
  trap cleanup EXIT
fi