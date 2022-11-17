#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_ubuntu_installchroot.sh
# Description:  Source script for configuring Ubuntu chroot jail
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source ${DIR}/pvesource_bash_defaults.sh

# Copy Binary & Dependents
function copy_binary() {
  set +Ee
  for i in $(ldd $* 2> /dev/null | grep -v dynamic | cut -d " " -f 3 | sed 's/://' | sort | uniq); do
    cp --parents $i $CHROOT
    #echo $i
  done
  set -Ee
}

#---- Static Variables -------------------------------------------------------------

if ! [ -z "${PARENT_EXEC_INSTALL_KODI_RSYNC+x}" ]; then
  # Set command library source
  CHROOT_APP_LIST="${DIR}/pvesource_ct_kodirsync_chrootapplist"
  # Chroot Home
  CHROOT='/home/chrootjail'
  # Enable/Disable SSHd
  SSHD_STATUS=0
else
  # Set command library source
  CHROOT_APP_LIST="${DIR}/pvesource_ct_ubuntu_chrootapplist_default"
  # Chroot Home
  CHROOT="/srv/${HOSTNAME}/homes/chrootjail"
  # Enable/Disable SSHd
  SSHD_STATUS=1
fi

#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='Chroot Jail'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Create SSH Chroot jail Environment
section "Create SSH chroot environment"

if [ $(grep -q "^chrootjail:" /etc/group >/dev/null; echo $?) -ne 0 ]; then
  msg "Creating CT default chrootjail group..."
	groupadd -g 65608 chrootjail
  info "Default user group created: ${YELLOW}chrootjail${NC}"
  echo
fi

msg "Creating basic chroot jail environment..."
mkdir -p $CHROOT
# Remove old chroot folders
array1=(
${CHROOT}/dev
${CHROOT}/bin
${CHROOT}/lib
${CHROOT}/lib64
${CHROOT}/etc
${CHROOT}/usr
)
for dir in "${array1[@]}"; do
  [[ -d "$dir" ]] && rm -R "$dir"
done
mkdir -p $CHROOT/{homes,dev,bin,lib,lib/x86_64-linux-gnu,lib64,etc,lib/terminfo/x,usr,usr/bin}
mknod -m 666 $CHROOT/dev/null c 1 3
mknod -m 666 $CHROOT/dev/tty c 5 0
mknod -m 666 $CHROOT/dev/zero c 1 5
mknod -m 666 $CHROOT/dev/random c 1 8
chown root:root $CHROOT
chmod 0755 $CHROOT #Change from 0711
chmod 0755 $CHROOT/homes #Change from 0711
echo "chroot" > $CHROOT/etc/debian_chroot

# Copy command libraries
msg "Copying command libraries for chroot jail..."
apt-get install -y libtinfo5 >/dev/null
cp -f /lib/x86_64-linux-gnu/{libtinfo.so.5,libdl.so.2,libc.so.6} $CHROOT/lib/ >/dev/null
cp -f /lib64/ld-linux-x86-64.so.2 $CHROOT/lib64/ >/dev/null
cp -f /lib/x86_64-linux-gnu/libnsl.so.1 $CHROOT/lib/x86_64-linux-gnu/ >/dev/null
cp -f /lib/x86_64-linux-gnu/libnss_* $CHROOT/lib/x86_64-linux-gnu/ >/dev/null
mkdir -p $CHROOT/usr/lib/locale > /dev/null 2>&1
cp -f -r /usr/lib/locale/* $CHROOT/usr/lib/locale >/dev/null

# Copy binary libraries
APPS="$(cat $CHROOT_APP_LIST | sed 's|$| |' | tr -d '\r\n' | sed 's/ *$//')"
for prog in $APPS;  do
  cp $prog $CHROOT/$prog

  # Obtain a list of related libraries
  ldd $prog > /dev/null
  if [ "$?" = 0 ] ; then
    LIBS=`ldd $prog | awk '{ print $3 }'`
    for l in $LIBS; do
      mkdir -p $CHROOT/`dirname $l` > /dev/null 2>&1
      cp $l $CHROOT/$l
    done
  fi
done
# mapfile -t binary < <(cat $CHROOT_APP_LIST)
# for i in "${binary[@]}"; do
#   copy_binary "$i"
# done

# ARCH amd64
if [ -f /lib64/ld-linux-x86-64.so.2 ]; then
   cp -f --parents /lib64/ld-linux-x86-64.so.2 $CHROOT >/dev/null
fi
# ARCH i386
if [ -f  /lib/ld-linux.so.2 ]; then
   cp -f --parents /lib/ld-linux.so.2 $CHROOT >/dev/null
fi
# Xterm for nano
if [ $(cat $CHROOT_APP_LIST | grep '/bin/nano' > /dev/null; echo $?) = 0 ] && [ -d  /lib/terminfo/x ]; then
   cp -r /lib/terminfo/x/* $CHROOT/lib/terminfo/x/ >/dev/null
fi
info "Chroot jail created.\nCommand libraries for chroot jail have been copied."
echo

#---- Configure SSH Server
section "Setup Chroot SSHd server"

# Stopping SSHd
msg "Configuring sshd default settings..."
if [ "$(systemctl is-active --quiet sshd; echo $?) -eq 0" ]; then
  systemctl stop ssh 2>/dev/null
fi

# Configure ssh settings
msg "Configuring sshd settings for chrootjail..."
sed -i 's/^[#]*\s*PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's|^[#]*\s*AuthorizedKeysFile.*|AuthorizedKeysFile     ~/.ssh/authorized_keys|g' /etc/ssh/sshd_config
sed -i 's|^[#]*\s*PasswordAuthentication.*|PasswordAuthentication no|g' /etc/ssh/sshd_config
sed -i "s/^[#]*\s*Port.*/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
# Configure sshd for chroot jail
sed -i 's|Subsystem.*sftp.*|Subsystem       sftp    internal-sftp|g' /etc/ssh/sshd_config # Sets sftp to use proFTP #Subsystem sftp /usr/libexec/openssh/sftp-server
cat <<EOF >> /etc/ssh/sshd_config

# Settings for chrootjail
Match Group chrootjail
        AuthorizedKeysFile $CHROOT/homes/%u/.ssh/authorized_keys
        ChrootDirectory $CHROOT
        PubkeyAuthentication yes
        PasswordAuthentication no
        AllowTCPForwarding no
        X11Forwarding no
        ForceCommand internal-sftp
EOF
echo

#---- Configure SSH Server
section "Enable SSHd server"

if [ $SSHD_STATUS = 0 ]; then
  # Starting SSHd
  msg "Enabling SSHD server..."
  systemctl stop ssh 2>/dev/null
  sed -i "s/^[#]*\s*Port.*/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
  ufw allow ${SSH_PORT} 2>/dev/null
  systemctl restart ssh 2>/dev/null
  systemctl is-active sshd >/dev/null 2>&1 && info "OpenBSD Secure Shell server: ${GREEN}active (running)${NC} - ${YELLOW}port ${SSH_PORT}${NC}" || info "OpenBSD Secure Shell server: ${RED}inactive (dead).${NC} - port ${SSH_PORT}"
else
  while true; do
    read -p "Enable SSH Server (Recommended) [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        read -p "Confirm SSH Port number: " -e -i ${SSH_PORT} SSH_PORT
        msg "Enabling SSHD server..."
        SSHD_STATUS=0
        systemctl stop ssh 2>/dev/null
        ufw allow ${SSH_PORT} 2>/dev/null
        systemctl enable ssh 2>/dev/null
        systemctl start ssh 2>/dev/null
        systemctl is-active sshd >/dev/null 2>&1 && info "OpenBSD Secure Shell server: ${GREEN}active (running)${NC} - ${YELLOW}port ${SSH_PORT}${NC}" || info "OpenBSD Secure Shell server: ${RED}inactive (dead)${NC} - port ${SSH_PORT}"
        echo
        break
        ;;
      [Nn]*)
        SSHD_STATUS=1
        systemctl stop ssh 2>/dev/null
        systemctl disable ssh 2>/dev/null
        sed -i "s/^[#]*\s*Port.*/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
        msg "Disabling SSHD server..."
        systemctl is-active sshd >/dev/null 2>&1 && info "OpenBSD Secure Shell server: ${GREEN}active (running).${NC} - ${YELLOW}port ${SSH_PORT}${NC}" || info "OpenBSD Secure Shell server: ${RED}inactive (dead)${NC} - port ${SSH_PORT}"
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
fi

#---- Finish
section "Completion Status"

info "${WHITE}Success.${NC} Chroot Jail has been configured.\n  --  SSHd Status: $(if [ $SSHD_STATUS = 0 ]; then echo "${GREEN}active (running)${NC}"; else echo "${RED}inactive (dead)${NC}"; fi)\n  --  Monitored SSH Port: ${YELLOW}${SSH_PORT}${NC}\n"

# Cleanup
if [ -z "${PARENT_EXEC+x}" ]; then
  trap cleanup EXIT
fi