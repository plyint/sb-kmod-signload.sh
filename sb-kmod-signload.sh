#!/usr/bin/env bash
################################################################################
# sb-kmod-signload.sh
# UEFI Secure Boot sign and load utility for kernel modules
#
# Description:
#  This script provides commands to sign an array list of kernel modules
#  and load them via modprobe into the linux kernel.  This was built to
#  specfically address the issue of having to resign and load kernel modules
#  after upgrading the linux kernel, so they are not rejected by Secure Boot.
#
#  As an example, this script is defaulted to load virtualbox kernel modules
#  and will look for the private key and x509 cert in a specific directory.
#  Please change these values as needed.
#
# Author: Xan Nick
#
###############################################################################

KERN_MODS=(
  vboxdrv
  vboxnetadp
  vboxnetflt
  vboxpci
)

KERN_MODS_TO_SIGN=(${KERN_MODS[@]})
KERN_MODS_TO_LOAD=(${KERN_MODS[@]})

PRIVATE_KEY="/root/secureboot_keys/MOK.priv"
PUBLIC_CERT="/root/secureboot_keys/MOK.der"

LOG_FILE="/var/log/sb-kmod-signload.log"
LOG=0

log() {
  if [ $LOG == 1 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S - ')$1" >> $LOG_FILE
  else
    echo "$1"
  fi
}

usage() {
cat << EOF
Usage:
  sb-kmod-signload.sh [COMMAND]

Description:
 This script provides commands to sign a designated list of kernel modules
 and load them via modprobe into the linux kernel.  This was built to
 specfically loadress the issue of having to resign and load kernel modules
 after upgrading the linux kernel, so they are not rejected by Secure Boot.

Commands:
  check
    Identifies and outputs which modules from KERN_MODS need to be signed or
    loaded.

  sign
    Signs the kernel modules with the public/private keys specified in
    PUBLIC_KEY_PATH and PRIVATE_KEY_PATH for the current kernel version.

  load
    Add the list of kernel modules specified in KERN_MODS to the linux kernel.

  auto [-l]
    Determines which modules from the list of kernel modules specified
    in KERN_MODS needs to be signed/loaded and then automatically performs
    those operations.

    If -l is passed then output will be logged to the file specified by 
    LOG_FILE.

  install-svc
    Creates a systemd service and automatically installs and enables it.
    This will cause the script to be run everytime at startup.

  uninstall-svc
    Removes the systemd service.

  help|--help|usage|--usage|?
    Display this help message.
EOF
}

check () {
  # Clear default lists for modules to sign/load
  KERN_MODS_TO_SIGN=()
  KERN_MODS_TO_LOAD=()

  for MOD in ${KERN_MODS[@]}; do
    signed=$(tail $(modinfo -n $MOD) | grep "Module signature appended")
    loaded=$(lsmod | grep $MOD)

    if [[ ! -z $signed ]]; then
      log "Kernel module $MOD is already signed"
    else
      KERN_MODS_TO_SIGN+=($MOD)
    fi
    if [[ ! -z $loaded ]]; then
      log "Kernel module $MOD is already loaded"
    else
      KERN_MODS_TO_LOAD+=($MOD)
    fi
  done

  if [ ${#KERN_MODS_TO_SIGN[@]} -eq 0 ]; then
    log "No kernel modules need to be signed."
  else
    log "These kernel modules need to be signed:"
    for MOD in ${KERN_MODS_TO_SIGN[@]}; do
      log $MOD
    done
  fi

  if [ ${#KERN_MODS_TO_LOAD[@]} -eq 0 ]; then
    log "No kernel modules need to be loaded."
  else
    log "These kernel modules need to be loaded:"
    for MOD in ${KERN_MODS_TO_LOAD[@]}; do
      log $MOD
    done
  fi

}

sign () {
  for MOD in ${KERN_MODS_TO_SIGN[@]}; do
    log "Signing $MOD..."
    /usr/src/linux-headers-$(uname -r)/scripts/sign-file \
    sha256 $PRIVATE_KEY $PUBLIC_CERT $(modinfo -n $MOD)
  done
}

load () {
  for MOD in ${KERN_MODS_TO_LOAD[@]}; do
    log "Loading $MOD..."
    modprobe $MOD
  done
}

install-svc () {
cat << EOF > /etc/systemd/system/sb-kmod-signload.service
[Unit]
Description=Secure Boot kernel module sign/load utility
After=runlevel4.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sb-kmod-signload.sh auto -l

[Install]
WantedBy=multi-user.target
EOF

  chmod 664 /etc/systemd/system/sb-kmod-signload.service
  systemctl daemon-reload
  systemctl enable sb-kmod-signload.service
}

uninstall-svc () {
  systemctl disable sb-kmod-signload.service
  rm /etc/systemd/system/sb-kmod-signload.service
  systemctl daemon-reload
  systemctl reset-failed
}

if [ "$EUID" -ne 0 ]
  then log "Please run as root"
  exit
fi

case $1 in 
  check )
    # Checks which modules from the list need to be
    # signed/loaded.
    check
    ;;
  sign )
    # Sign the default list of modules
    sign
    ;;
  load )
    # Load the default list of modules
    load
    ;;
  auto )
    # Checks which modules from the list need to be
    # signed/loaded and then automatically signs and
    # loads only those modules. 

    # If -l parameter is passed then enable logging
    shift
    while getopts ":l" OPTS; do
      case $OPTS in
        l ) LOG=1;;
      esac
    done

    check
    sign
    load
    ;;
  install-svc )
    # Automatically creates a systemd service script
    # and installs the service so it will be run
    # everytime the system starts up.
    install-svc
    ;;
  uninstall-svc )
    # Removes the systemd service
    uninstall-svc
    ;;
  help|--help|usage|--usage|\? )
    usage
    ;;
  * )
    usage
    ;;
esac
