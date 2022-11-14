#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_ubuntu_installssmtp.sh
# Description:  Source script for installing SSMTP Email Service
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SOURCE="${DIR}"


#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source ${DIR}/pvesource_bash_defaults.sh

ipvalid() {
  # Set up local variables
  local ip=${1:-1.2.3.4}
  local IFS=.; local -a a=($ip)
  # Start with a regex format test
  [[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
  # Test values of quads
  local quad
  for quad in {0..3}; do
    [[ "${a[$quad]}" -gt 255 ]] && return 1
  done
  return 0
}

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='SSMTP Email'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------


#---- Install and Configure SSMTP Email Alerts

msg_box "#### PLEASE READ CAREFULLY - SSMTP & EMAIL ALERTS ####\n
Send email alerts about your machine to your designated System Administrator. Be alerted about unwarranted login attempts and other system critical alerts. If you do not have a Postfix, SendMail or Proxmox Mail Gateway server on your network then the 'simple smtp' (ssmtp) package is well suited for sending critical alerts to your administrator.

SSMTP is a simple Mail Transfer Agent (MTA). SSMTP is not a mail server. While easy to setup it requires the following prerequisites:

  --  SMTP SERVER
      You require a SMTP server that can receive the emails from your machine and send them to your designated administrator. If you use GMail SMTP server its best to enable 'App Passwords'. An 'App Password' is a 16-digit GMail passcode that gives an app or device permission to access your GMail Account. Or you can use a mailgun.com flex account relay server (Recommended).
      
  --  REQUIRED SMTP SERVER CREDENTIALS ( In order of input )
      1. SMTP server address
         (i.e smtp.gmail.com or smtp.mailgun.org)
      2. SMTP server port
         (i.e gmail port is 587 and mailgun port is 587)
      3. Designated administrator email address
         (i.e your working admin email address)
      4. SMTP server username
         (i.e MyEmailAddress@gmail.com or postmaster@sandboxa6ac6.mailgun.org)
      5. SMTP server default password
        (i.e your Gmail App Password or MailGun SMTP password)
      
If you choose to proceed have your smtp server credentials available."
echo
while true; do
  read -p "Install and configure Postfix SSMTP [y/n]?: " -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      msg "Installing SSMTP..."
      echo
      INSTALL_SSMTP=0 >/dev/null
      break
      ;;
    [Nn]*)
      INSTALL_SSMTP=1 >/dev/null
      msg "You have chosen not to proceed. Moving on..."
      echo
      break
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done

#---- Installing SSMTP
if [ ${INSTALL_SSMTP} = 0 ]; then
#---- Checking Prerequisites
section "Checking Prerequisites."

msg "Checking SSMTP status..."
if [ $(dpkg -s ssmtp >/dev/null 2>&1; echo $?) = 0 ]; then
  info "SSMTP status: ${GREEN}active (running).${NC}"
else
  msg "Installing SSMTP (be patient, might take a long, long time)..."
  apt-get install ssmtp -y >/dev/null
  apt-get install sharutils -y >/dev/null
  sleep 1
  if [ $(dpkg -s ssmtp >/dev/null 2>&1; echo $?) = 0 ]; then
    info "SSMTP status: ${GREEN}active (running).${NC}"
  else
    warn "SSMTP status: ${RED}inactive or cannot install (dead).${NC}.\nUser intervention is required.\nExiting installation script in 3 seconds..."
    sleep 2
    exit 0
  fi
fi
echo


#---- Setting Variables
section "Set SSMTP variables."

msg "The User needs to input some variables. Variables are used to create and setup the SSMTP service. The next steps requires User input. To accept our default values press 'ENTER' on the keyboard. To overwrite and change a value simply type in a new value and press ENTER to accept/continue."
echo

while true; do
# Set SSMTP server address
while true; do
read -p "Enter SSMTP server address: " -e SSMTP_ADDRESS
read -p "Enter SSMTP server port number: " -e -i 587 SSMTP_PORT
ip=$SSMTP_ADDRESS
if ipvalid "$ip"; then
  msg "Validating IPv4 address..."
  if [ $(ping -s 1 -c 2 "$(echo "$SSMTP_ADDRESS")" >/dev/null; echo $?) = 0 ] || [ $(nc -z -w 5 $SSMTP_ADDRESS $SSMTP_PORT 2>/dev/null; echo $?) = 0 ]; then
    info "The SSMTP address is set: ${YELLOW}$SSMTP_ADDRESS${NC}."
    echo
    break
  elif [ $(ping -s 1 -c 2 "$(echo "$SSMTP_ADDRESS")" >/dev/null; echo $?) != 0 ] || [ $(nc -z -w 5 $SSMTP_ADDRESS $SSMTP_PORT 2>/dev/null; echo $?) != 0 ]; then
    warn "There are problems with your input:\n1. Your IP address meets the IPv4 standard, BUT\n2. Your IP address $(echo "$SSMTP_ADDRESS") is not reachable.\nCheck your SSMTP server IP address, port number and firewall settings.\nTry again..."
    echo
  fi
else
  msg "Validating url address..."
  if [ $(ping -s 1 -c 2 "$(echo "$SSMTP_ADDRESS")" >/dev/null; echo $?) = 0 ] || [ $(nc -z -w 5 $SSMTP_ADDRESS $SSMTP_PORT 2>/dev/null; echo $?) = 0 ]; then
    info "The SSMTP address is set: ${YELLOW}$SSMTP_ADDRESS${NC}."
    echo
    break
  elif [ $(ping -s 1 -c 2 "$(echo "$SSMTP_ADDRESS")" >/dev/null; echo $?) != 0 ] || [ $(nc -z -w 5 $SSMTP_ADDRESS $SSMTP_PORT 2>/dev/null; echo $?) != 0 ]; then
    warn "There are problems with your input:\n1. The URL $(echo "$SSMTP_ADDRESS") is not reachable.\nCheck your SSMTP server URL address, port number and firewall settings.\nTry again..."
    echo
  fi
fi
done

# Set root address
msg "Enter the System Administrators email address who receives all critical system and server alerts."
while true; do
  read -p "Enter the System Administrators email address: " SSMTP_EMAIL
  echo
  if [[ "$SSMTP_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]] && ! [[ ${SSMTP_EMAIL} =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.mailgun.org$ ]]; then
    msg "Email address $SSMTP_EMAIL is valid."
    info "System Administrator email is set: ${YELLOW}$SSMTP_EMAIL${NC}."
    echo
    break
  else
    msg "Email address $SSMTP_EMAIL is invalid."
    warn "There are problems with your input:\n1. Email address $(echo "$SSMTP_EMAIL") does not pass the validity check.\nTry again..."
    echo
  fi
done


# Notification about SMTP server settings
msg "In the next steps the User must enter the ( $SSMTP_ADDRESS ) server authorised username and password credentials."
if [[ ${SSMTP_ADDRESS,,} == *"gmail"* ]]; then
  msg "Required actions when using GMail SMTP servers:

    1. Open your Google Account.
    2. In the Security section, select 2-Step Verification. You might need to sign in. Select 'Turn off'.
    3. A pop-up window will appear to confirm that you want to turn off 2-Step Verification. Select 'Turn off'.
    4. Allow Less secure app access. If you do not use 2-Step Verification, you might need to allow less secure apps to access your account."
  echo
elif [[ ${SSMTP_ADDRESS,,} == *"mailgun"* ]]; then
  msg "Required actions when using MailGun SMTP servers:

    1. Do NOT use your MailGun account username and passwords.
    2. Go to Mailgun.com website and login.
    3. In the Sending section, select Overview tab.
        --  Select SMTP > Select to grab your SMTP credentials.
        --  Note and copy your username. Usually a long username.
            ( i.e Username: postmaster@sandbox3bchjsdf7fsfcsfac6.mailgun.org )
        --  Note and copy your Password. Usually a long password.
            ( i.e Default password: 89kf548sbsfjsdfb8551030-f9kl3b107-7099346 )
        --  You must add your $SSMTP_EMAIL to mailgun Authorized Recipients list.
            This input is on the same page as smtp Username and Password.
            Sending > Overview. Add $SSMTP_EMAIL and click Save."
  echo
fi

# SMTP server authorised username
read -p "Enter SMTP server authorised username: " SSMTP_AUTHUSER
info "SMTP authorised user is set: ${YELLOW}$SSMTP_AUTHUSER${NC}."
echo

# SMTP server authorised password
while true; do
  read -p "Enter SMTP server password: " SSMTP_AUTHPASS
  echo
  read -p "Confirmation. Retype SMTP server password (again): " SSMTP_AUTHPASS_CHECK
  msg "Validating your SMTP server password..."
  if [ "$SSMTP_AUTHPASS" = "$SSMTP_AUTHPASS_CHECK" ];then
    info "SMTP server password is set: ${YELLOW}$SSMTP_AUTHPASS${NC}."
    break
  elif [ "$SSMTP_AUTHPASS" != "$SSMTP_AUTHPASS_CHECK" ]; then
    warn "Your inputs ${RED}$SSMTP_AUTHPASS${NC} and ${RED}$SSMTP_AUTHPASS_CHECK${NC} do NOT match.\nTry again..."
  fi
done
echo

# Configuring your ssmtp server
msg "Configuring /etc/ssmtp/ssmtp.conf..."
cat <<-EOF > /etc/ssmtp/ssmtp.conf
#
# Config file for sSMTP sendmail
#
# The person who gets all mail for userids < 1000
# Make this empty to disable rewriting.
#root=postmaster
root=$SSMTP_EMAIL

# The place where the mail goes. The actual machine name is required no
# MX records are consulted. Commonly mailhosts are named mail.domain.com
#mailhub=mail
mailhub=$SSMTP_ADDRESS:$SSMTP_PORT

# Where will the mail seem to come from?
#rewriteDomain=
rewritedomain=$HOSTNAME.localdomain

# The full hostname
hostname=$HOSTNAME.localdomain

# Are users allowed to set their own From: address?
# YES - Allow the user to specify their own From: address
# NO - Use the system generated From: address
#FromLineOverride=YES
FromLineOverride=YES

# Use SSL/TLS before starting negotiation
UseTLS=Yes
UseSTARTTLS=Yes

# Username/Password
AuthUser=$SSMTP_AUTHUSER
AuthPass=$SSMTP_AUTHPASS

# AuthMethod
# The authorization method to use. If unset, plain text is used.
# May also be set to LOGIN (? for gmail) and
# cram-md5, DIGEST-MD5 etc
#AuthMethod=LOGIN

#### VERY IMPORTANT !!! If other people have access to this computer
# Your GMAIL Password is left unencrypted in this file
# so make sure you have a strong root password, and make sure
# you change the permissions of this file to be 640:
# chown root:mail /etc/ssmtp/ssmtp.conf
# chmod 640 /etc/ssmtp/ssmtp.conf

EOF
msg "Configuring /etc/ssmtp/revaliases..."
if [ $(grep -q "root:$SSMTP_EMAIL:$SSMTP_ADDRESS:$SSMTP_PORT" /etc/ssmtp/revaliases; echo $?) -eq 1 ]; then
  echo "root:$SSMTP_EMAIL:$SSMTP_ADDRESS:$SSMTP_PORT" >> /etc/ssmtp/revaliases
fi

# Modify /etc/ssmtp/ssmtp.conf for gmail smtp servers
if [[ ${SSMTP_ADDRESS,,} == *"gmail"* ]]; then
  msg "Modifying /etc/ssmtp/ssmtp.conf for GMail servers..."
  sed -i 's|rewritedomain.*|rewriteDomain=gmail.com|g' /etc/ssmtp/ssmtp.conf
  sed -i 's|#AuthMethod.*|AuthMethod=LOGIN|g' /etc/ssmtp/ssmtp.conf
fi
# Modify /etc/ssmtp/ssmtp.conf for amazonaws smtp servers
if [[ ${SSMTP_ADDRESS,,} == *"amazon"* ]]; then
  msg "Modifying /etc/ssmtp/ssmtp.conf for AmazonAWS servers..."
  sed -i 's|UseSTARTTLS.*|#UseSTARTTLS=yes|g' /etc/ssmtp/ssmtp.conf
fi
# Modify /etc/ssmtp/ssmtp.conf for godaddy smtp servers
if [[ ${SSMTP_ADDRESS,,} == *"secureserver.net"* ]]; then
  msg "Modifying /etc/ssmtp/ssmtp.conf for GoDaddy servers..."
  sed -i 's|UseSTARTTLS.*|#UseSTARTTLS=yes|g' /etc/ssmtp/ssmtp.conf
fi

# Securing credentials in /etc/ssmtp/ssmtp.conf file
msg "Securing password credentials..."
chown root:mail /etc/ssmtp/ssmtp.conf
chmod 640 /etc/ssmtp/ssmtp.conf
info "Permissions set to 0640: ${YELLOW}/etc/ssmtp/ssmtp.conf${NC}"
echo


#---- Test email
section "Testing your SSMTP Configuration"
echo
msg_box "#### PLEASE READ CAREFULLY - SSMTP & EMAIL TESTING ####\n
In the next step we can test your SSMTP settings by sending a test email to your nominated systems designated administrator: $SSMTP_EMAIL. If you cannot find our test email in your inbox always check in your spam folder.

Any $SSMTP_EMAIL email found in your spam folder must be whitelisted as 'safe'. If you do not receive our test email then something is wrong with your configuration inputs. You will have the option to re-enter your credentials and try again.

If you choose NOT to send a test email then: (1) SSMTP settings are configured but not tested; and, (2) Any edits must be done by the system administrator (i.e edit  /etc/ssmtp/ssmtp.conf )."
echo
while true; do
  read -p "Do you want to send a test email to $SSMTP_EMAIL [y/n]?: "  -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      echo
      msg "Sending test email to $SSMTP_EMAIL..."
      echo -e "To: $SSMTP_EMAIL\nFrom: $SSMTP_EMAIL\nSubject: This is a SSMTP test email sent from $HOSTNAME\n\nHello World.\n\nYour SSMTP mail server works.\nCongratulations.\n\n" > test_email.txt
      ssmtp -vvv $SSMTP_EMAIL < test_email.txt
      echo
      msg "Check the administrators mailbox ( $SSMTP_EMAIL ) to ensure the test email was delivered. Note: check the administrators spam folder and whitelist any test email found there."
      echo
      while true; do
        read -p "Confirm receipt of the test email message [y/n]?: " -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            info "Success. Your SSMTP server is configured."
            break 3
            ;;
          [Nn]*)
            while true; do
              read -p "Do you want to re-input your credentials (again) [y/n]?: " -n 1 -r YN
              echo
              case $YN in
                [Yy]*)
                  info "You have chosen to re-input your credentials. Try again..."
                  echo
                  break 3
                  ;;
                [Nn]*)
                  info "You have chosen to accept your inputs despite them not working.\nSkipping the validation step."
                  break 4
                  ;;
                *)
                  warn "Error! Entry must be 'y' or 'n'. Try again..."
                  echo
                  ;;
              esac
            done
            ;;
          *)
            warn "Error! Entry must be 'y' or 'n'. Try again..."
            echo
            ;;
        esac
      done
      ;;
    [Nn]*)
      info "You have chosen not to test your SSMTP email server.\nSkipping the validation step.\nSSMTP settings are configured but not tested."
      break 2
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done
done
echo

#---- Setup Webmin Email Service
# First check if Webmin is installed
if [ $(dpkg -s webmin >/dev/null 2>&1; echo $?) = 0 ]; then
  section "Configure Webmin SendMail"
  echo
  # Configuring Webmin mail send mode
  if [ $(grep -q "send_mode=" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
    msg "Configuring Webmin mail send mode /etc/webmin/mailboxes/config..."
    sed -i "s|send_mode=.*|send_mode=$SSMTP_ADDRESS|g" /etc/webmin/mailboxes/config
    info "Webmin mail send mode status : ${GREEN}Set${NC}"
    echo
  elif [ $(grep -q "send_mode=" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
    msg "Configuring Webmin mail send mode /etc/webmin/mailboxes/config..."
    echo "send_mode=$SSMTP_ADDRESS" >> /etc/webmin/mailboxes/config
    info "Webmin mail send mode status : ${GREEN}Set${NC}"
    echo
  fi
  # Configuring Webmin mail ssl
  if [ $(grep -q "smtp_ssl=1" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
    msg "Configuring Webmin mail ssl /etc/webmin/mailboxes/config..."
    sed -i "s|smtp_ssl=.*|smtp_ssl=1|g" /etc/webmin/mailboxes/config
    info "Webmin mail ssl status : ${GREEN}Enabled${NC}"
    echo
  elif [ $(grep -q "smtp_ssl=1" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
    msg "Configuring Webmin mail ssl /etc/webmin/mailboxes/config..."
    echo "smtp_ssl=1" >> /etc/webmin/mailboxes/config
    info "Webmin mail ssl status : ${GREEN}Enabled${NC}"
    echo
  fi
  # Configuring Webmin mail smtp port
  if [ $(grep -q "smtp_port=465" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
    msg "Configuring Webmin mail smtp port /etc/webmin/mailboxes/config..."
    sed -i "s|smtp_port=.*|smtp_port=465|g" /etc/webmin/mailboxes/config
    info "Webmin mail smtp port : ${GREEN}465${NC}"
    echo
  elif [ $(grep -q "smtp_port=465" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
    msg "Configuring Webmin mail smtp port /etc/webmin/mailboxes/config..."
    echo "smtp_port=465" >> /etc/webmin/mailboxes/config
    info "Webmin mail smtp port : ${GREEN}465${NC}"
    echo
  fi
  # Configuring Webmin smtp username
  if [ $(grep -q "smtp_user=$SSMTP_AUTHUSER" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
    msg "Configuring Webmin smtp username /etc/webmin/mailboxes/config..."
    sed -i "s|smtp_user=.*|smtp_user=$SSMTP_AUTHUSER|g" /etc/webmin/mailboxes/config
    info "Webmin mail smtp username : ${GREEN}Set${NC}"
    echo
  elif [ $(grep -q "smtp_user=$SSMTP_AUTHUSER" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
    msg "Configuring Webmin smtp username /etc/webmin/mailboxes/config..."
    echo "smtp_user=$SSMTP_AUTHUSER" >> /etc/webmin/mailboxes/config
    info "Webmin mail smtp username : ${GREEN}Set${NC}"
    echo
  fi
  # Configuring Webmin smtp authorised password
  if [ $(grep -q "smtp_pass=$SSMTP_AUTHPASS" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
    msg "Configuring Webmin smtp authorised password /etc/webmin/mailboxes/config..."
    sed -i "s|smtp_pass=.*|smtp_pass=$SSMTP_AUTHPASS|g" /etc/webmin/mailboxes/config
    info "Webmin mail smtp authorised password : ${GREEN}Set${NC}"
    echo
  elif [ $(grep -q "smtp_pass=$SSMTP_AUTHPASS" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
    msg "Configuring Webmin smtp authorised password /etc/webmin/mailboxes/config..."
    echo "smtp_pass=$SSMTP_AUTHPASS" >> /etc/webmin/mailboxes/config
    info "Webmin mail smtp authorised password : ${GREEN}Set${NC}"
    echo
  fi
  # Configuring Webmin smtp authentication method
  if [ $(grep -q "smtp_auth=Login" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
    msg "Configuring Webmin smtp authentication method /etc/webmin/mailboxes/config..."
    sed -i "s|smtp_auth=.*|smtp_auth=Login|g" /etc/webmin/mailboxes/config
    info "Webmin mail smtp authentication method : ${GREEN}Login${NC}"
    echo
  elif [ $(grep -q "smtp_auth=Login" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
    msg "Configuring Webmin smtp authentication method /etc/webmin/mailboxes/config..."
    echo "smtp_auth=Login" >> /etc/webmin/mailboxes/config
    info "Webmin mail smtp authentication method : ${GREEN}Login${NC}"
    echo
  fi

  info "Webmin sending email has been configured.\n  --  The from address for email sent by webmin is:\n      ${YELLOW}webmin@${HOSTNAME,,}.localdomain${NC}\n  --  SMTP server is: ${YELLOW}$SSMTP_ADDRESS${NC} port 465\n  --  Changes can be made by the system administrator using the\n      Webmin configuration frontend.\n\n  --  Use the Webmin WebGui to enable and configure your System\n      and server alerts."
  echo
fi
fi

#---- Finish Line ------------------------------------------------------------------
if [ ${INSTALL_SSMTP} == 0 ]; then
  section "Completion Status."

  msg "${WHITE}Success.${NC}"
  echo
fi

if [ -z "${PARENT_EXEC+x}" ]; then
  trap cleanup EXIT
fi