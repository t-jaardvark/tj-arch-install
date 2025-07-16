#!/bin/bash
#                 _     _ _                  
#   __ _ _ __ ___| |__ | (_)_ __  _   ___  __
#  / _` | '__/ __| '_ \| | | '_ \| | | \ \/ /
# | (_| | | | (__| | | | | | | | | |_| |>  < 
#  \__,_|_|  \___|_| |_|_|_|_| |_|\__,_/_/\_\
#            01 - BASE SYSTEM INSTALL

# Source environment variables if .env exists
if [ -f answers.env ]; then
    source answers.env
fi

# Function to save variable to .env file
save_to_env() {
    local var_name=$1
    local var_value=$2
    echo "${var_name}=\"${var_value}\"" >> answers.env
}

# Function to check internet connectivity
check_internet() {
    if ! ping -c 1 archlinux.org &>/dev/null; then
        echo "No internet connection. Please connect and try again."
        exit 1
    fi
}

# Function to get block device
get_block_device() {
    if [ -z "$USER_DEV" ]; then
        clear
        echo "Checking available block devices..."
        lsblk
        
        # Try to find a suitable default device
        DEFAULT_DEV=""
        if [ -b "/dev/sda" ]; then
            DEFAULT_DEV="/dev/sda"
        elif [ -b "/dev/nvme0n1" ]; then
            DEFAULT_DEV="/dev/nvme0n1"
        elif [ -b "/dev/vda" ]; then
            DEFAULT_DEV="/dev/vda"
        fi
        
        if [ -n "$DEFAULT_DEV" ]; then
            read -p "Enter block device (press Enter for default $DEFAULT_DEV): " USER_DEV
            USER_DEV=${USER_DEV:-$DEFAULT_DEV}
        else
            read -p "Enter block device (e.g., /dev/sda): " USER_DEV
        fi
        
        if [ ! -b "$USER_DEV" ]; then
            echo "Invalid block device: $USER_DEV"
            echo "Please check the device name and try again."
            exit 1
        fi
        save_to_env "USER_DEV" "$USER_DEV"
    fi
}

# Function to get username
get_username() {
    if [ -z "$USER_USER" ]; then
        clear
        echo "Setting up user account..."
        read -p "Enter username (default: user): " USER_USER
        USER_USER=${USER_USER:-user}
        save_to_env "USER_USER" "$USER_USER"
    fi
}

# Function to get user password
get_user_password() {
    if [ -z "$USER_USER_PASS" ]; then
        clear
        echo "Setting password for user: $USER_USER"
        while true; do
            read -s -p "Enter user password (press Enter for default 'idk'): " USER_USER_PASS
            echo
            read -s -p "Confirm user password: " USER_PASS_CONFIRM
            echo
            
            # Check if passwords match
            if [ "$USER_USER_PASS" != "$USER_PASS_CONFIRM" ]; then
                echo "Passwords do not match! Please try again."
                continue
            fi
            
            # If password is empty, set to default
            if [ -z "$USER_USER_PASS" ]; then
                USER_USER_PASS="idk"
                echo "Using default password: idk"
                break
            fi
            
            # Check if password contains problematic characters
            if [[ "$USER_USER_PASS" =~ [\"\'\\] ]]; then
                echo "Password contains invalid characters! Please avoid quotes and backslashes."
                continue
            fi
            
            break
        done
        save_to_env "USER_USER_PASS" "$USER_USER_PASS"
    fi
}

# Function to get country
get_country() {
    if [ -z "$USER_COUNTRY" ]; then
        clear
        echo "Configuring system location..."
        read -p "Enter country for mirror (default: United States): " USER_COUNTRY
        USER_COUNTRY=${USER_COUNTRY:-"United States"}
        save_to_env "USER_COUNTRY" "$USER_COUNTRY"
    fi
}

# Function to get timezone
get_timezone() {
    if [ -z "$USER_TIMEZONE" ]; then
        clear
        echo "Setting timezone..."
        read -p "Enter timezone (default: America/Chicago): " USER_TIMEZONE
        USER_TIMEZONE=${USER_TIMEZONE:-"America/Chicago"}
        save_to_env "USER_TIMEZONE" "$USER_TIMEZONE"
    fi
}

# Function to get hostname
get_hostname() {
    if [ -z "$USER_HOSTNAME" ]; then
        clear
        echo "Setting system hostname..."
        # Generate random 8-character hex string
        RANDOM_HEX=$(openssl rand -hex 4)
        DEFAULT_HOSTNAME="arch${RANDOM_HEX}"
        read -p "Enter hostname (default: $DEFAULT_HOSTNAME): " USER_HOSTNAME
        USER_HOSTNAME=${USER_HOSTNAME:-$DEFAULT_HOSTNAME}
        save_to_env "USER_HOSTNAME" "$USER_HOSTNAME"
    fi
}

# Function to get root password
get_root_password() {
    if [ -z "$USER_ROOT_PASS" ]; then
        clear
        echo "Setting root password..."
        while true; do
            read -s -p "Enter root password (press Enter for default 'idk'): " USER_ROOT_PASS
            echo
            read -s -p "Confirm root password: " ROOT_PASS_CONFIRM
            echo
            
            # Check if passwords match
            if [ "$USER_ROOT_PASS" != "$ROOT_PASS_CONFIRM" ]; then
                echo "Passwords do not match! Please try again."
                continue
            fi
            
            # If password is empty, set to default
            if [ -z "$USER_ROOT_PASS" ]; then
                USER_ROOT_PASS="idk"
                echo "Using default password: idk"
                break
            fi
            
            # Check if password contains problematic characters
            if [[ "$USER_ROOT_PASS" =~ [\"\'\\] ]]; then
                echo "Password contains invalid characters! Please avoid quotes and backslashes."
                continue
            fi
            
            break
        done
        save_to_env "USER_ROOT_PASS" "$USER_ROOT_PASS"
    fi
}

# Function to confirm partition replacement
confirm_partitions() {
    if [ -z "$USER_REPLACE_PART" ]; then
        clear
        echo "Configuring partitions..."
        echo "Choose partition setup:"
        echo "1) Replace all partitions with new btrfs layout (default)"
        echo "2) Use existing btrfs, preserve @home, @opt, and @srv (will format others)"
        read -p "Enter choice (default: 1): " REPLY

        case $REPLY in
            2)
                echo "WARNING: This will format all subvolumes except @home, @opt, and @srv"
                read -p "Are you sure? (y/N): " CONFIRM
                if [[ $CONFIRM =~ ^[Yy]$ ]]; then
                    USER_REPLACE_PART=2
                else
                    USER_REPLACE_PART=1
                fi
                ;;
            *)
                echo "WARNING: This will delete all existing partitions on $USER_DEV"
                read -p "Are you sure? (y/N): " CONFIRM
                if [[ $CONFIRM =~ ^[Yy]$ ]]; then
                    USER_REPLACE_PART=1
                else
                    echo "Installation cancelled"
                    exit 1
                fi
                ;;
        esac
        save_to_env "USER_REPLACE_PART" "$USER_REPLACE_PART"
    fi
}

# Function to create and format partitions
create_partitions() {
    if [ "$USER_REPLACE_PART" -eq 1 ]; then
        echo "Creating new partition layout..."
        # Remove existing partitions
        sgdisk -Z "$USER_DEV"

        # Create new partitions
        echo "Creating EFI and root partitions..."
        sgdisk -n 1:0:+1024M -t 1:ef00 "$USER_DEV" # EFI partition
        sgdisk -n 2:0:0 -t 2:8300 "$USER_DEV"      # Root partition

        # Format partitions
        echo "Formatting EFI partition (FAT32)..."
        mkfs.fat -F32 "${USER_DEV}1"
        echo "Formatting root partition (BTRFS)..."
        mkfs.btrfs -f "${USER_DEV}2"
    fi
}

# Function to attempt mount with fallback
mount_with_fallback() {
    local device=$1
    local mountpoint=$2
    local subvol=$3

    # First attempt with space_cache=v2
    if ! mount -o noatime,compress=zstd,space_cache=v2,subvol="$subvol" "$device" "$mountpoint"; then
        # Second attempt without space_cache=v2
        if ! mount -o noatime,compress=zstd,subvol="$subvol" "$device" "$mountpoint"; then
            echo "Failed to mount $subvol on $mountpoint"
            return 1
        fi
    fi
    return 0
}

# Function to create and mount btrfs subvolumes
setup_btrfs() {
    local preserve_home_opt=$1

    echo "Mounting BTRFS root for subvolume management..."
    # Mount the btrfs partition
    if ! mount "${USER_DEV}2" /mnt; then
        echo "Failed to mount root for subvolume creation"
        exit 1
    fi

    if [ "$preserve_home_opt" = true ]; then
        echo "Preserving existing @home, @opt, and @srv subvolumes..."
        # Check if required subvolumes exist
        if ! btrfs subvolume list /mnt | grep -q "@home" || \
           ! btrfs subvolume list /mnt | grep -q "@opt" || \
           ! btrfs subvolume list /mnt | grep -q "@srv"; then
            echo "Error: One or more required subvolumes (@home, @opt, @srv) not found in existing btrfs filesystem"
            umount /mnt
            exit 1
        fi

        echo "Removing old subvolumes (except @home, @opt, and @srv)..."
        # Delete all subvolumes except @home, @opt, and @srv
        for subvol in $(btrfs subvolume list /mnt | grep -v "@home\|@opt\|@srv" | awk '{print $NF}'); do
            echo "Deleting subvolume: $subvol"
            btrfs subvolume delete "/mnt/$subvol"
        done

        echo "Creating new subvolumes..."
        # Create new subvolumes
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@.snapshots
        btrfs subvolume create /mnt/@var_log
        btrfs subvolume create /mnt/@tmp
    else
        echo "Creating fresh BTRFS subvolume layout..."
        # Create all subvolumes
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@.snapshots
        btrfs subvolume create /mnt/@var_log
        btrfs subvolume create /mnt/@opt
        btrfs subvolume create /mnt/@tmp
        btrfs subvolume create /mnt/@srv
    fi

    umount /mnt

    echo "Mounting subvolumes..."
    # Mount subvolumes with appropriate flags
    if ! mount_with_fallback "${USER_DEV}2" /mnt "@" "compress=zstd"; then
        echo "Failed to mount root subvolume"
        exit 1
    fi

    echo "Creating mount points..."
    mkdir -p /mnt/{boot,home,.snapshots,var/log,opt,tmp,srv}

    echo "Mounting remaining subvolumes..."
    # Mount each subvolume with verification
    if ! mount_with_fallback "${USER_DEV}2" /mnt/home "@home" "compress=zstd"; then
        echo "Failed to mount home subvolume"
        exit 1
    fi

    if ! mount_with_fallback "${USER_DEV}2" /mnt/.snapshots "@.snapshots" "compress=zstd"; then
        echo "Failed to mount snapshots subvolume"
        exit 1
    fi

    if ! mount_with_fallback "${USER_DEV}2" /mnt/var/log "@var_log" "compress=zstd"; then
        echo "Failed to mount var_log subvolume"
        exit 1
    fi

    if ! mount_with_fallback "${USER_DEV}2" /mnt/opt "@opt" "compress=zstd"; then
        echo "Failed to mount opt subvolume"
        exit 1
    fi

    if ! mount_with_fallback "${USER_DEV}2" /mnt/tmp "@tmp" "nodev,nosuid,noexec"; then
        echo "Failed to mount tmp subvolume"
        exit 1
    fi

    if ! mount_with_fallback "${USER_DEV}2" /mnt/srv "@srv" "compress=zstd"; then
        echo "Failed to mount srv subvolume"
        exit 1
    fi

    echo "Mounting EFI partition..."
    # Mount boot partition
    if ! mount "${USER_DEV}1" /mnt/boot; then
        echo "Failed to mount boot partition"
        exit 1
    fi

    echo "All filesystems mounted successfully!"
}

# Main script execution
echo "Starting Arch Linux installation..."
check_internet
get_block_device
get_username
get_user_password
get_root_password
get_country
get_timezone
get_hostname
confirm_partitions

# Sync time
echo "Synchronizing system time..."
timedatectl set-ntp true

# Update mirrors
echo "Updating mirror list for $USER_COUNTRY..."
if ! reflector -c "$USER_COUNTRY" --latest 5 --download-timeout 10 --sort rate --save /etc/pacman.d/mirrorlist; then
    echo "Warning: Failed to update mirror list, using default mirrors"
fi
echo "Synchronizing package databases..."
if ! pacman -Sy; then
    echo "Error: Failed to sync package databases"
    exit 1
fi

# Enable parallel downloads in pacman
echo "Enabling parallel downloads in pacman..."
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

# Partition and format if requested
if [ "$USER_REPLACE_PART" -eq 1 ]; then
    echo "Preparing to create new partition layout..."
    create_partitions
    setup_btrfs false
elif [ "$USER_REPLACE_PART" -eq 2 ]; then
    echo "Checking existing BTRFS partition..."
    # Verify the partition is btrfs
    if ! blkid "${USER_DEV}2" | grep -q 'TYPE="btrfs"'; then
        echo "Error: ${USER_DEV}2 is not a btrfs partition"
        exit 1
    fi
    setup_btrfs true
fi

# Install base system
echo "Installing base system packages (this may take a while)..."
if ! pacstrap /mnt base linux linux-firmware amd-ucode base-devel vi vim nano micro; then
    echo "Error: Failed to install base system packages"
    exit 1
fi

echo "Copying mirror list to new system..."
cp "/etc/pacman.d/mirrorlist" "/mnt/etc/pacman.d/"

echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

if ! curl -L -o "o2.sh" "https://raw.githubusercontent.com/t-jaardvark/tj-arch-install/refs/heads/main/02-arch-chroot-install.bash"; then
    echo "Error: Failed to download chroot installation script"
    exit 1
fi

if [ -f "o1.sh" ]; then
    cp "o1.sh" "/mnt"
fi
cp "o2.sh" "/mnt"
chmod +x "/mnt/o1.sh" "/mnt/o2.sh"
# Copy answers.env to new system
if [ -f answers.env ]; then
    echo "Copying answers.env to new system..."
    cp answers.env /mnt/
    
    # Validate that all required variables are set
    echo "Validating configuration..."
    required_vars=("USER_DEV" "USER_USER" "USER_USER_PASS" "USER_ROOT_PASS" "USER_COUNTRY" "USER_TIMEZONE" "USER_HOSTNAME" "USER_REPLACE_PART")
    missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "Warning: Missing required variables: ${missing_vars[*]}"
        echo "This may cause issues during installation."
    else
        echo "All required variables are set."
    fi
else
    echo "Error: answers.env not found!"
    exit 1
fi

echo "Base installation complete! You can now chroot into the system."
echo "Next steps:"
echo "1. Run arch-chroot /mnt"
echo "2. Continue with system configuration"

arch-chroot "/mnt" /o2.sh