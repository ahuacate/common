#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_send_email.sh
# Description:  Source script for "Introduction" body text at opening of VM Script
#
# You can run this script with the following arguments:
#   -t --to
#   -c --cc
#   -b --bcc
#   -s --subject
#   -h --html
#   -a --attach
#   ./pvesource_send_email.sh -t "hello@gmail.com" -c "postmaster"
#
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Function ---------------------------------------------------------------------

# Check PVE host SMTP status
function check_smtp_status() {
  # Host SMTP Option ('0' is inactive, '1' is active)
  var='picasso566_smtp'
  file='/etc/postfix/main.cf'
  if [ -f $file ] && [ "$(systemctl is-active --quiet postfix; echo $?)" = 0 ]
  then
    SMTP_STATUS=$(grep --color=never -Po "^${var}=\K.*" "${file}" || true)
  else
    # Set SMTP inactive
    SMTP_STATUS=0
fi
}

#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Check PVE host SMTP status
# '0' inactive, '1' enabled.
check_smtp_status
if [ "$SMTP_STATUS" = 0 ]
then
  # Options if SMTP is inactive
  display_msg='Unfortunately we cannot send this email. The SMTP server in your network is not known. Your PVE hosts should be configured to support SMTP email services. Our PVE Host SMTP Server installer is available in our PVE Host Toolbox located at GitHub:\n\n    --  https://github.com/picasso566/pve-host'

  msg_box "#### PLEASE READ CAREFULLY ####\n\n$(echo ${display_msg})"
  sleep 3
  return
fi

#---- Body
 
# Parse the command line arguments
while getopts ":t:c:b:s:h:a:" opt
do
  case $opt in
    t|--to) to=$OPTARG;;
    c|--cc) cc=$OPTARG;;
    b|--bcc) bcc=$OPTARG;;
    s|--subject) subject=$OPTARG;;
    h|--html) html_file=$OPTARG;;
    a|--attach) attachments+=("$OPTARG");;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1;;
  esac
done

# Check if the required arguments were supplied
if [[ -z $to || -z $subject || -z $html_file ]]
then
    echo "Usage: $0 -t TO -c CC -b BCC -s SUBJECT -h HTML_FILE -a ATTACHMENT_FILE..."
    exit 1
fi

# Set boundary id
boundary="unique-boundary-$RANDOM"

# Begin constructing the message
message=$(cat <<EOF
To: $to
Cc: $cc
Bcc: $bcc
Subject: $subject
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=$boundary

EOF
)

# Add the HTML body to the message
message=$message$(cat <<EOF

--$boundary
Content-Type: text/html; charset=UTF-8
Content-Disposition: inline
$(cat $html_file)
--$boundary
EOF
)


# If there are attachments, add them to the message
if [ ${#attachments[@]} -gt 0 ]
then
  # Add the attachments to the message
  for attachment in "${attachments[@]}"; do
      # Encode the attachment as base64
      encoded_attachment=$(base64 "$attachment" | tr -d '\n')
      attachment_name=$(basename "$attachment")

      message=$message$(cat <<EOF

--$boundary
Content-Type: application/octet-stream; name="$attachment_name"
Content-Disposition: attachment; filename="$attachment_name"
Content-Transfer-Encoding: base64

$encoded_attachment
EOF
)
  done

  # Add a boundary to the attachment message
  message=$message$(cat <<EOF

--$boundary
EOF
)
fi

# Add the closing boundary to the message
message=$message$(cat <<EOF

--$boundary--
EOF
)

# Send the email using sendmail
echo "$message" | sendmail -t

# Unset variables & arrays
unset encoded_attachment to cc bcc subject html attach
attachments=()
#-----------------------------------------------------------------------------------