#!/bin/bash

echo "+-----------------------------------------------------+"
echo "|           MacOS Icon Changer by ConradZn            |"
echo "| https://github.com/ConradZn/MOIC-macOS-Icon-Changer |"
echo "|            -  Modified by kawaiishay                |"
echo "+-----------------------------------------------------+"

echo "$PATH"

echo ""
echo "Root password will be required. To enable root user, see:"
echo "https://support.apple.com/en-us/HT204012"
echo ""

IS_CSRUTIL_DISABLED=$(csrutil status | egrep -oh '(en|dis)abled' | head -n 1)
IS_AUTH_ROOT_DISABLED=$(csrutil authenticated-root status | egrep -oh '(en|dis)abled' | head -n 1)

if [ "$IS_CSRUTIL_DISABLED" == "enabled" ] || [ "$IS_AUTH_ROOT_DISABLED" == "enabled" ]
then
  echo "ERROR: In order to proceed, you must boot into Recovery Mode and enter the following in Terminal, then reboot back to macOS:"
  echo ""
  echo "  csrutil disable"
  echo "  csrutil authenticated-root disable"
  echo ""
  echo "Your current settings are:"
  echo ""
  echo "  csrutil disable $IS_CSRUTIL_DISABLED"
  echo "  csrutil authenticated-root $IS_AUTH_ROOT_DISABLED"
  echo ""
  echo "Exiting..."
  exit 1
fi

# Check if homebrew is installed & then install glow if not already present on system
# 1. Check if Homebrew itself is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed."
    read -p "Would you like to install Homebrew first? (y/n): " install_brew
    if [[ "$install_brew" =~ ^[Yy]$ ]]; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Ensure brew is available in the current script environment after installation
        # For Apple Silicon Macs:
        if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        # For Intel Macs:
        elif [ -f /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        echo "Exiting because Homebrew is required."
        exit 1
    fi
fi

install_glow()
{
  read -p "Do you want to install glow via Homebrew? (y/n): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
      echo "Installing glow..."
      brew install glow
  elif [[ "$confirm" =~ ^[Nn]$ ]]; then
      echo "Skipping installation of glow."
  else
      echo "Invalid input. Please enter 'y' or 'n'."
      install_glow 
  fi
}

# 2. Check if the specific Homebrew app is installed
if brew list "glow" &> /dev/null; then
    echo "glow is already installed."
else
    echo '`glow` is not installed. You will not be able to view the README.md help file without it.'
    install_glow
fi

echo "What do you want to change?"
echo "  [1] System Application Icons"
echo "  [2] Change Finder Icon"
echo ""
echo "Or view the ReadMe.md file in Terminal for more information: [?]"
echo ""

printf "[Choose between 1, 2, or ?. Just type the number/symbol]: "
read selection

check_valid() {
  if [ "$1" != "1" ] && [ "$1" != "2" ]
  then
    echo ""
    read -n 1 -s -r -p "Invalid Selection. Exiting, press any key to continue..."
    exit 1
  fi
}

continue_changing(){
  printf "Do you want to continue with changing icons? [Y/n]: "
  read selection
  if [ "$selection" == "Y" ] || [ "$selection" == "y" ]
  then
    echo ""
    printf "[Choose between the original system icon change options above. Just type the number]: "
    read selection
  elif [ "$selection" == "N" ] || [ "$selection" == "n" ]
  then
    echo ""
    read -n 1 -s -r -p "Exiting, press any key to continue..."
    exit 1
  else
    echo ""
    echo "Invalid Selection. Try again ..."
    continue_changing
  fi
}

if [ "$selection" == "?" ]
then
  if brew list "glow" &> /dev/null; then
    glow "/Users/shaynahjackson/Documents/- Miscellaneous/- MacOS Knowledge Dump & Tools/- Application Download Files/SystemIconChangers/MacOS Icon Changer/README.md"
    continue_changing
  else
    echo "glow is not installed, the markdown file cannot be displayed."
    continue_changing
  fi
else
  check_valid selection
fi

mkdir -p /tmp/mount
ROOT_DISK=$(mount | head -n 1 | egrep -oh '/dev/disk[0-9]s[0-9]')
TMP_MOUNT=$(df -h /tmp/mount | tail -n 1 | egrep -oh '/dev/disk[0-9]s[0-9]')

if [ "$ROOT_DISK" == "$TMP_MOUNT" ]
then
  echo ""
  echo "System Volume at $ROOT_DISK is already mounted to /tmp/mount. Skipping..."
  echo ""
else
  echo ""
  echo "Mounting System Volume at $ROOT_DISK to /tmp/mount..."
  sudo mount -o nobrowse -t apfs "$ROOT_DISK" /tmp/mount
  echo ""
fi

if [ "$selection" == "1" ]
then
  echo "Opened a Finder window to System Applications. You can now customize icons by:"
  open /tmp/mount/System/Applications/
  echo ""
  echo "  1) Right clicking an app, \"Get Info\", and drag a replacement icon"
  echo ""
  echo "  -- or --"
  echo ""
  echo "  2) Right clicking an app, \"Show Package Contents\" > \"Contents\" > \"Resources\", and replace \"AppIcon.icns\""
  echo ""
fi

if [ "$selection" == "2" ]
then
  echo "Note: BE SURE TO MAKE A BACK-UP FROM THOSE 2 FILES!!!"
  echo ""
  echo "The folder with resources from Dock.app just opened. Replace the finder.png and finder@2x.png files with yours."
  open /tmp/mount/System/Library/CoreServices/Dock.app/Contents/Resources
  echo ""
fi

read -n 1 -s -r -p "When you're done making changes, press any key to continue..."
echo ""

echo "WARNING: By committing these changes, the System Volume will no longer be bootable on computers that have SIP or SSV enabled. This script has determined that both are currently disabled. Do you wish to continue?"
echo ""

printf "[Y/N]: "
read final_confirm

if [ "$final_confirm" == "Y" ] || [ "$final_confirm" == "y" ]
then
  echo ""
  echo "Creating a new snapshot to write changes to disk..."
  sudo bless --folder /tmp/mount/System/Library/CoreServices --bootefi --create-snapshot
  echo "Flushing the icon cache..."
  sudo rm -rfv /Library/Caches/com.apple.iconservices.store > /dev/null 2>&1
  sudo find /private/var/folders/ -name com.apple.dock.iconcache -exec rm -rf {} \; > /dev/null 2>&1
  sudo find /private/var/folders/ -name com.apple.iconservices -exec rm -rf {} \; > /dev/null 2>&1
  sudo umount -f /tmp/mount > /dev/null 2>&1
  echo ""
  echo "Please reboot your computer for changes to take effect."
else
  sudo umount -f /tmp/mount > /dev/null 2>&1
  echo ""
  echo "Cancelling changes..."
fi