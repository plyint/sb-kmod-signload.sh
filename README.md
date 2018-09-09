# sb-kmod-signload.sh

This script provides commands to sign a designated list of kernel modules and loads them via modprobe into the linux kernel.  This was built to specfically address the issue of having to re-sign and reload kernel modules after upgrading the linux kernel, so they are not rejected by UEFI Secure Boot. (e.g. virtualbox kernel modules)

As an example, this script is defaulted to load virtualbox kernel modules and will look for the private key and x509 cert in a specific directory. Please change these values inside the script as needed.

## Requirements

sb-kmod-signload.sh requires the following software to be installed:

* BASH
* Systemd (if you want to enable the optional service)

## Installation

1. Download the sb-kmod-signload.sh script and install it to a directory in your path.

Example: curl the script to /usr/local/bin
```
$ sudo curl https://raw.githubusercontent.com/plyint/sb-kmod-signload.sh/master/sb-kmod-signload.sh -o /usr/local/bin/sb-kmod-signload.sh
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  5266  100  5266    0     0  34874      0 --:--:-- --:--:-- --:--:-- 35106
```

2. Ensure the script has the executable permissions set and is owned by root
```
sudo chmod 755 /usr/local/bin/sb-kmod-signload.sh
sudo chown root:root /usr/local/bin/sb-kmod-signload.sh
```

3. Adjust script variables as desired.  The defaults are listed below...
```
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
```

4. Install systemd service to run at startup (Optional)

Execute the following command as root to install the systemd service
```
sudo /usr/local/bin/sb-kmod-signload.sh install-svc
```

## Usage

If the systemd script was installed, then you should not have to do anything going forward.  Everytime you start your machine, the service will be run and it will automatically detect which of the modules specified in the array need to be signed and loaded.  

If the systemd script was not installed or you want to execute the commands manually, then you can become root and run the commands directly.  

```
# Become root and run the same auto command as the systemd service
sudo su -
/usr/local/bin/sb-kmod-signload.sh auto
```

The basic commands available are:
* sign - signs all modules listed in the array
* load - loads all modules listed in the array
* auto - automatically detect which of the modules need to be signed/loaded
* check - identifies the modules that would be signed/loaded if the auto command is run 

To see a list of available commands along with detailed descriptions, just run the script without any parameters.

```
# Become root and display the available commands
sudo su -
/usr/local/bin/sb-kmod-signload.sh
```

## Uninstall

To remove the script from your system, run the uninstall-svc command as root (if the systemd service was installed) and then delete the script.

```
sudo /usr/local/bin/sb-kmod-signload.sh uninstall-svc
rm -f /usr/local/bin/sb-kmod-signload.sh
```

## Troubleshooting

### Systemd
The installed systemd service is designed to run after runlevel4 in the hopes that most other scripts that might load kernel modules have already run.  You may need to adjust the "After" dependency listed under the Unit section if you observe the service running earlier than expected.

### Logging
By default the installed systemd service will log output to the logfile /var/log/sb-kmod-signload.log.  Check this log for errors if you encounter issues.
