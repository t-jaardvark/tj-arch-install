#                 _     _ _                  
#   __ _ _ __ ___| |__ | (_)_ __  _   ___  __
#  / _` | '__/ __| '_ \| | | '_ \| | | \ \/ /
# | (_| | | | (__| | | | | | | | | |_| |>  < 
#  \__,_|_|  \___|_| |_|_|_|_| |_|\__,_/_/\_\
#            02 - CHROOT SECTION                                            

### BEGIN CHROOT SECTION ###
# Source the answers file
if [ -f "/answers.env" ]; then
    source "/answers.env"
else
    echo "Error: answers.env not found in chroot environment"
    exit 1
fi

ln -sf /usr/share/zoneinfo/$USER_TIMEZONE /etc/localtime
hwclock --systohc

#Localization
#    Edit /etc/locale.gen: Uncomment en_US.UTF-8 UTF-8
#Generate locales:
locale-gen
#Create /etc/locale.conf:
echo "LANG=en_US.UTF-8" > /etc/locale.conf

#Network Configuration
echo "$USER_HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $USER_HOSTNAME.localdomain   $USER_HOSTNAME" >> /etc/hosts

#User Setup
# Set root password
echo "Setting root password..."
if [ -n "$USER_ROOT_PASS" ]; then
    if echo "root:${USER_ROOT_PASS}" | chpasswd; then
        echo "Root password set successfully"
    else
        echo "Warning: Failed to set root password with provided password"
        echo "Setting default root password: 'idk'"
        echo "root:idk" | chpasswd
    fi
else
    echo "Warning: No root password provided, setting default password: 'idk'"
    echo "root:idk" | chpasswd
fi

# Create user and set password
echo "Creating user account..."
if [ -n "$USER_USER" ]; then
    useradd -mG wheel "$USER_USER"
    
    if [ -n "$USER_USER_PASS" ]; then
        if echo "${USER_USER}:${USER_USER_PASS}" | chpasswd; then
            echo "User password set successfully"
        else
            echo "Warning: Failed to set user password with provided password"
            echo "Setting default user password: 'idk'"
            echo "${USER_USER}:idk" | chpasswd
        fi
    else
        echo "Warning: No user password provided, setting default password: 'idk'"
        echo "${USER_USER}:idk" | chpasswd
    fi
else
    echo "Error: No username provided"
    exit 1
fi

# Install base packages
echo "Installing additional packages..."
pacman -S --noconfirm networkmanager network-manager-applet dialog wpa_supplicant > /var/log/install-packages.log 2>&1
pacman -S --noconfirm mtools dosfstools git reflector snapper bluez bluez-utils cups xdg-utils >> /var/log/install-packages.log 2>&1
pacman -S --noconfirm xdg-user-dirs alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack base-devel linux-headers >> /var/log/install-packages.log 2>&1

# Check for EFI system
echo "DEBUG: Checking for EFI system..."
echo "DEBUG: Base device is: ${USER_DEV}"
echo "DEBUG: EFI partition should be: ${USER_DEV}1"
echo "DEBUG: Listing disk partitions:"
lsblk

if [ -d "/sys/firmware/efi" ]; then
    echo "DEBUG: EFI directory found at /sys/firmware/efi"
    echo "DEBUG: Contents of /sys/firmware/efi:"
    ls -la /sys/firmware/efi
    
    echo "DEBUG: EFI system detected - installing EFI bootloader packages..."
    # Install EFI specific packages
    pacman -S --noconfirm grub efibootmgr
    
    echo "DEBUG: Verifying EFI partition is mounted at /boot:"
    mount | grep boot
    
    echo "DEBUG: Contents of /boot before GRUB installation:"
    ls -la /boot
    
    echo "DEBUG: Installing GRUB for EFI..."
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    
    echo "DEBUG: GRUB installation exit code: $?"
    echo "DEBUG: Contents of /boot after GRUB installation:"
    ls -la /boot
else
    echo "DEBUG: No EFI directory found, assuming BIOS system"
    echo "DEBUG: Installing GRUB for BIOS..."
    # Install GRUB for BIOS
    pacman -S --noconfirm grub
    
    echo "DEBUG: Installing GRUB to disk: ${USER_DEV}"
    grub-install --target=i386-pc --recheck "${USER_DEV}"
    
    echo "DEBUG: GRUB installation exit code: $?"
fi

# Generate GRUB configuration
echo "DEBUG: Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg
echo "DEBUG: GRUB configuration generation exit code: $?"
echo "DEBUG: Contents of /boot/grub:"
ls -la /boot/grub

#######################################################################
# Install Windows-10-Dark theme
mkdir -p /usr/share/themes
pushd /usr/share/themes
git clone https://github.com/B00merang-Project/Windows-10-Dark
popd
#######################################################################
# Install Windows-10 icon theme
mkdir -p /usr/share/icons
pushd /usr/share/icons
git clone https://github.com/B00merang-Artwork/Windows-10
gtk-update-icon-cache -f /usr/share/icons/Windows-10
popd
#######################################################################
# install VictorMono Nerd Font
mkdir -p /usr/share/fonts/TTF
pushd /usr/share/fonts/TTF
curl -L -o "VictorMono.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/VictorMono.zip"
unzip VictorMono.zip
rm VictorMono.zip
popd
#######################################################################
# install yay as user (safer than running as root)
echo "Installing yay AUR helper..."
cd /tmp
git clone https://aur.archlinux.org/yay.git
# Set proper ownership of the yay directory
chown -R "$USER_USER:$USER_USER" yay
cd yay
# Build and install as the user
sudo -u "$USER_USER" makepkg -si --noconfirm
cd /
rm -rf /tmp/yay
#######################################################################


# Snapper Configuration *disabled for now*
# Prepare Snapshot Directory
#umount /.snapshots
#rm -r /.snapshots
#snapper -c root create-config /
#btrfs subvolume delete /.snapshots
#mkdir /.snapshots
#mount -a
#chmod 750 /.snapshots

# Configure Snapper
# Set timeline limits:
#echo 'TIMELINE_LIMIT_YEARLY="0"' > /etc/snapper/configs/root
#echo 'TIMELINE_LIMIT_MONTHLY="0"' >> /etc/snapper/configs/root
#echo 'TIMELINE_LIMIT_WEEKLY="0"' >> /etc/snapper/configs/root
#echo 'TIMELINE_LIMIT_DAILY="7"' >> /etc/snapper/configs/root
#echo 'TIMELINE_LIMIT_HOURLY="5"' >> /etc/snapper/configs/root

#Enable Snapper Services
#systemctl enable --now snapper-timeline.timer
#systemctl enable --now snapper-cleanup.timer

#Desktop Environment Installation
echo "Installing desktop environment packages..."
pacman -S --noconfirm xorg xorg-server gnome-keyring cinnamon cinnamon-translations nemo-fileroller \
    lightdm lightdm-gtk-greeter lightdm-slick-greeter \
    firefox xterm >> /var/log/install-packages.log 2>&1

# Configure LightDM to use slick-greeter
echo "Configuring LightDM to use slick-greeter..."
echo "[Seat:*]" > /etc/lightdm/lightdm.conf
echo "greeter-session=lightdm-slick-greeter" >> /etc/lightdm/lightdm.conf

# Ensure proper home directory permissions
echo "Setting up home directory permissions..."
chown -R "${USER_USER}:${USER_USER}" "/home/${USER_USER}"

# Enable required services
echo "Enabling required services..."
systemctl enable lightdm
systemctl enable NetworkManager

#    Boot Configuration
#        Create boot backup hook
#        Install rsync
#        Update GRUB configuration

# The system is now ready for use with Btrfs filesystem
# and automatic snapshots configured through Snapper.