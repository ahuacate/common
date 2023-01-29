#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_ct_usbpassthru.sh
# Description:  Setup single USB port pass through to container
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# PCT list fix
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

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Setup USB Pass Through
section "Create a USB pass through"

msg_box "#### SINGLE USB PORT PASSTHROUGH - READ CAREFULLY ####\n
There can be good reasons to access USB diskware directly from a PVE CT. To make a physically connected USB device accessible inside a CT the PVE CT configuration file requires modification. This installer will pass through a single physical $(hostname) USB port only. This single USB port is then only accessible inside your PVE CT OS.

In the next step we will display all available USB devices connected to your PVE host $(hostname). You need to identify which USB host device ID to passthrough to the CT. The simplest way is to now ( before proceeding) plugin a physical USB memory stick, for example a 'SanDisk Cruzer Blade', into a preferred USB port on the PVE host $(hostname). Our script will then scan all USB devices and display the identity of your physical USB memory stick making it easy for you to identify the USB host device ID to passthrough. In the 'SanDisk Cruzer Blade' example you would select No.5 to passthrough, being USB buss 002:

    5) Bus 002 Device 004: ID 0781:5567 SanDisk Corp. Cruzer Blade

In the next step choose $(hostname) USB device ID to passthrough to the PVE CT."
echo
while true
do
  read -p "Do you want to configure $(hostname) USB pass (Not Recommended) [y/n]? " -n 1 -r YN
  echo
  case $YN in
    [Yy]*)
      USB_PASS=0
      break
      ;;
    [Nn]*)
      USB_PASS=1
      msg "You have chosen not to proceed. Bye..."
      echo
      break
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done

if [ "$USB_PASS" = 0 ]
then
  # Set CTID
  if [ -z ${CTID+x} ]
  then
    msg "Setting your PVE CT container CTID..."
    while true
    do
      read -p "Enter your PVE CT container CTID: " -e -i 110 CTID_VAR
      if [ "$(pct_list | grep -w $CTID_VAR > /dev/null; echo $?)" = 0 ]
      then
        CTID=$CTID_VAR
        info "PVE CT CTID is set: ${YELLOW}$CTID${NC}"
        echo
        break
      else
        msg "There are ${UNDERLINE}problems with your input${NC}. PVE CTID numeric ID '$CTID_VAR' is NOT in use. You must choose a valid PVE CTID numeric ID (VMID) from the list below:\n\n$(pct_list |  awk -F',' '{print "  "$1","$4}' | column -t -s ',')\n\nTry again..."
        echo
      fi
    done
  fi

  # Stop CT
  pct_stop_waitloop

  # Select USB port
  msg "Select a PVE host $(hostname) USB device port..."
  mapfile -t options < <(lsusb | awk '{$3=$4=$5=$6=""; print $0}' | sed "/[hH]ub$/d"  | awk '$1=$1')
  PS3="Select a USB bus device (entering numeric) : "
  select USB_BUS in "${options[@]}"
  do
    case $USB_BUS in
      $options)
        test -n "${USB_BUS}"
        USB_BUS_ID=$(echo "$USB_BUS" | awk '{ print $2 }')
        echo
        msg "You have chosen ( '${USB_BUS}' ), USB Bus No.'${USB_BUS_ID}' to configure for USB pass through..."
        info "USB pass through Bus ID set: ${YELLOW}$USB_BUS_ID${NC}"
        echo
        break
        ;;
      *) warn "Invalid entry. Try again.." >&2
    esac
  done

  # Edit CT conf for pass through
  msg "Creating USB pass through for PVE CT '$CTID'..."
  printf "%b\n" "lxc.cgroup.devices.allow: c 189:* rwm" \
  "lxc.mount.entry: /dev/bus/usb/$USB_BUS_ID dev/bus/usb/$USB_BUS_ID none bind,optional,create=dir" >> /etc/pve/lxc/${CTID}.conf
  echo

  # Stop CT
  pct_start_waitloop
fi

#---- Finish Line ------------------------------------------------------------------
if [ "$USB_PASS" = 0 ]
then
  section "Completion Status."

  msg "${WHITE}Success.${NC} USB pass through has been configured.

    --  PVE host $(hostname) USB pass through: ${YELLOW}$USB_BUS_ID${NC}
    --  This USB port is now available inside PVE CT '$CTID'.\n"
fi
#-----------------------------------------------------------------------------------