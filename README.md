# TJ Arch Linux Installation Script

A comprehensive, automated Arch Linux installation script that sets up a complete system with BTRFS filesystem, Cinnamon desktop environment, and various useful packages.

## Features

- **Automated Installation**: Streamlined installation process with minimal user interaction
- **BTRFS Filesystem**: Modern filesystem with subvolume support for better organization
- **Cinnamon Desktop**: Full desktop environment with Windows 10 Dark theme
- **Custom Fonts**: VictorMono Nerd Font for better terminal experience
- **Package Management**: Yay AUR helper for easy package installation
- **Network Setup**: NetworkManager for easy network configuration
- **Audio Support**: PipeWire for modern audio handling
- **Printing Support**: CUPS for printer management
- **Bluetooth Support**: BlueZ for Bluetooth devices

## Prerequisites

- Arch Linux live USB/CD
- Internet connection
- Target disk/device for installation
- Basic knowledge of Linux partitioning

## Installation Process

### Step 1: Boot into Arch Linux Live Environment

1. Boot your computer from the Arch Linux live USB/CD
2. Ensure you have an internet connection
3. Update the system: `pacman -Syu`

### Step 2: Download and Run the Installation Script

```bash
# Download the installation script
curl -L -o install.sh "https://raw.githubusercontent.com/t-jaardvark/tj-arch-install/main/01-base-install.bash"

# Make it executable
chmod +x install.sh

# Run the installation
./install.sh
```

### Step 3: Follow the Interactive Prompts

The script will guide you through the following configuration:

1. **Block Device Selection**: Choose your target disk (e.g., `/dev/sda`)
2. **User Account**: Set up username and password
3. **Root Password**: Set root password
4. **System Configuration**: 
   - Country for mirror selection
   - Timezone
   - Hostname (auto-generated if not specified)
5. **Partitioning Options**:
   - Option 1: Replace all partitions with new BTRFS layout
   - Option 2: Use existing BTRFS, preserve @home, @opt, and @srv

### Step 4: Automatic Installation

The script will automatically:

- Create and format partitions (EFI + BTRFS)
- Set up BTRFS subvolumes (@, @home, @.snapshots, @var_log, @opt, @tmp, @srv)
- Install base system packages
- Configure bootloader (GRUB)
- Install desktop environment (Cinnamon)
- Set up themes and fonts
- Configure services

## What Gets Installed

### Base System
- Linux kernel and firmware
- AMD microcode (if applicable)
- Essential system tools

### Desktop Environment
- X.org server
- Cinnamon desktop environment
- LightDM display manager with slick-greeter

### Applications
- Firefox web browser
- XTerm terminal emulator
- File manager (Nemo)

### System Tools
- NetworkManager for network management
- PipeWire for audio
- CUPS for printing
- BlueZ for Bluetooth
- Snapper for BTRFS snapshots (configured but disabled by default)

### Development Tools
- Base development tools
- Git version control
- Yay AUR helper

### Themes and Fonts
- Windows 10 Dark theme
- Windows 10 icon theme
- VictorMono Nerd Font

## BTRFS Subvolume Layout

The installation creates the following BTRFS subvolume structure:

```
@ (root)
├── @home (user data)
├── @.snapshots (system snapshots)
├── @var_log (log files)
├── @opt (optional software)
├── @tmp (temporary files)
└── @srv (server data)
```

## Post-Installation

After installation completes:

1. **Reboot** into your new system
2. **Login** with your user credentials
3. **Update** the system: `sudo pacman -Syu`
4. **Install additional software** using yay: `yay -S package-name`

## Customization

### Enabling Snapper Snapshots

To enable automatic BTRFS snapshots, uncomment the Snapper configuration section in `02-arch-chroot-install.bash`:

```bash
# Uncomment lines 130-150 in 02-arch-chroot-install.bash
# Then reinstall or manually configure Snapper
```

### Adding More Packages

Edit the package installation sections in `02-arch-chroot-install.bash` to add or remove packages according to your needs.

## Troubleshooting

### Common Issues

1. **Network Connection**: Ensure you have internet connectivity before running the script
2. **Disk Space**: Ensure you have at least 20GB free space for installation
3. **EFI vs BIOS**: The script automatically detects and configures for your system type
4. **Partitioning**: Be careful when selecting the target disk - all data will be lost

### Getting Help

- Check the installation logs in `/var/log/install-packages.log`
- Review the script output for error messages
- Ensure all prerequisites are met

## File Structure

```
tj-arch-install/
├── 01-base-install.bash          # Main installation script
├── 02-arch-chroot-install.bash   # Chroot configuration script
├── README.md                     # This file
└── answers.env                   # Generated during installation
```

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve this installation script.

## License

This project is open source. Feel free to modify and distribute according to your needs.

## Disclaimer

This script will **delete all data** on the target disk. Use with caution and ensure you have backups of any important data. The authors are not responsible for data loss or system damage. 