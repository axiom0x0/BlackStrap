#!/usr/bin/env zsh
#
# Arch Linux Automated Installation Script
# # Function for error messages
print_error() {
    echo "${RED}${BOLD}[ERROR] ${1}${RESET}" >&2
}

# Function for warning messages
print_warning() {
    echo "${YELLOW}${BOLD}[WARNING] ${1}${RESET}"
}

# Parse command line arguments
USE_ENCRYPTION=true
ENCRYPT_BOOT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-encryption)
            USE_ENCRYPTION=false
            shift
            ;;
        --encrypt-boot)
            ENCRYPT_BOOT=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-encryption     Disable LUKS encryption (default: enabled)"
            echo "  --encrypt-boot      Encrypt /boot partition (advanced)"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate options
if [[ "$ENCRYPT_BOOT" == true ]] && [[ "$USE_ENCRYPTION" == false ]]; then
    print_error "--encrypt-boot requires encryption to be enabled"
    exit 1
fi

# === Configuration ===================================
#
# This script automates the installation of Arch Linux with a focus on security.
# It handles the entire installation process from disk partitioning to user setup
# and system configuration.
#
# Usage:
#   1. Boot into Arch Linux live environment
#   2. Download this script
#   3. Edit the configuration section (DISK, USRNAME, PASSWORD)
#   4. Make executable: chmod +x blackstrap.sh
#   5. Run: ./blackstrap.sh [OPTIONS]
#
# Options:
#   --no-encryption     Disable LUKS encryption (default: enabled)
#   --encrypt-boot      Encrypt /boot partition (advanced, requires GRUB password)
#
# Requirements:
#   - UEFI-capable system
#   - Internet connection
#   - Sufficient disk space (minimum 20GB recommended)
#
# Features:
#   - UEFI boot setup with GRUB
#   - LUKS2 + LVM encryption (optional)
#   - Separate /boot partition with integrity checking
#   - Automated disk partitioning
#   - User creation with sudo privileges
#   - ZSH + Oh-My-Zsh configuration
#   - Comprehensive terminal color support
#   - Optional BlackArch repository integration
#
# Warning:
#   - This script will ERASE ALL DATA on the specified disk
#   - Verify disk path (DISK variable) before running
#   - Change default password after installation
#
# Troubleshooting:
#   1. Disk not found: Use 'lsblk' to verify disk path
#   2. Not in UEFI mode: Verify boot mode and BIOS settings
#   3. No internet: Check connection with 'ping archlinux.org'
#   4. BlackArch integration fails: Verify sudo access and try manually
#
# Author: axiom0x0

set -e  # errexit
set -u  # nounset

# Color definitions
RED=$'\e[31m'
GREEN=$'\e[32m'
BLUE=$'\e[34m'
YELLOW=$'\e[33m'
BOLD=$'\e[1m'
RESET=$'\e[0m'

# Function for section headers
print_step() {
    echo "${BLUE}${BOLD}[\e[97m${1}\e[34m] ${2}${RESET}"
}

# Function for success messages
print_success() {
    echo "${GREEN}${BOLD}[OK] ${1}${RESET}"
}

# Function for error messages
print_error() {
    echo "${RED}${BOLD}[ERROR] ${1}${RESET}" >&2
}

# === Configuration ===
# Disk Configuration
# Check what disk should be by running `lsblk` or `fdisk -l`
# Default disk is set to /dev/sda, but can be changed
DISK="/dev/sda"
print_step "0" "Available Disks"
lsblk -d -o NAME,SIZE,MODEL

print -n "Enter disk to use (default: ${DISK}): "
read user_disk
DISK=${user_disk:-$DISK}

# LUKS/LVM Configuration
LUKS_NAME="cryptlvm"
VG_NAME="vg0"
LV_SWAP_NAME="swap"
LV_ROOT_NAME="root"

# System Configuration
HOSTNAME="yourHOSTNAME"   # change to desired hostname
USRNAME="yourUSRNAME"     # change to desired username
TIMEZONE="US/Pacific"
LOCALE="en_US.UTF-8 UTF-8"
LANG="en_US.UTF-8"
EDITOR="vim"

# Security Note: In production, consider passing this as an environment variable
# or using a separate configuration file instead of hardcoding it
PASSWORD="changeme456"  # change this!

# Display encryption status
if [[ "$USE_ENCRYPTION" == true ]]; then
    print_warning "Encryption: ENABLED"
    if [[ "$ENCRYPT_BOOT" == true ]]; then
        print_warning "/boot encryption: ENABLED (Advanced)"
        print_warning "You will need to enter password twice at boot (GRUB + LUKS)"
    else
        print_warning "/boot encryption: DISABLED (Recommended)"
        print_warning "/boot integrity checksums will be created for auditing"
    fi
else
    print_warning "Encryption: DISABLED"
fi

# Add safety check for disk
echo "${RED}${BOLD}WARNING: This will ERASE ALL DATA on $DISK. Continue? (y/N)${RESET}"
read -r response
[[ "${response:l}" != "y" ]] && exit 1

[[ -b "$DISK" ]] || {
  print_error "Disk $DISK not found. Exiting."
  exit 1
}
# ======================

print_step "1" "Checking UEFI mode..."
[[ -d /sys/firmware/efi/efivars ]] || {
  print_error "System not booted in UEFI mode. Exiting."
  exit 1
}

print_step "2" "Enabling NTP..."
timedatectl set-ntp true

print_step "3" "Partitioning $DISK..."
sgdisk --zap-all "$DISK"

if [[ "$USE_ENCRYPTION" == true ]]; then
    if [[ "$ENCRYPT_BOOT" == true ]]; then
        # Full disk encryption: EFI + encrypted boot + encrypted root (separate LUKS containers)
        sgdisk -n1:0:+512MiB  -t1:ef00 -c1:"EFI System"     "$DISK"
        sgdisk -n2:0:+1GiB    -t2:8300 -c2:"Encrypted Boot" "$DISK"
        sgdisk -n3:0:0        -t3:8300 -c3:"Encrypted Root" "$DISK"
        
        EFI_PART="${DISK}1"
        BOOT_LUKS_PART="${DISK}2"
        ROOT_LUKS_PART="${DISK}3"
    else
        # Standard encryption: EFI + unencrypted boot + encrypted root
        sgdisk -n1:0:+512MiB  -t1:ef00 -c1:"EFI System"  "$DISK"
        sgdisk -n2:0:+1GiB    -t2:8300 -c2:"Boot"        "$DISK"
        sgdisk -n3:0:0        -t3:8300 -c3:"Linux LVM"   "$DISK"
        
        EFI_PART="${DISK}1"
        BOOT_PART="${DISK}2"
        LUKS_PART="${DISK}3"
    fi
else
    # No encryption: Original layout
    sgdisk -n1:0:+512MiB  -t1:ef00 -c1:"EFI System"  "$DISK"
    sgdisk -n2:0:+4GiB    -t2:8200 -c2:"Swap"        "$DISK"
    sgdisk -n3:0:0        -t3:8300 -c3:"Linux Root"  "$DISK"
    
    EFI_PART="${DISK}1"
    SWAP_PART="${DISK}2"
    ROOT_PART="${DISK}3"
fi

partprobe "$DISK"

if [[ "$USE_ENCRYPTION" == true ]]; then
    print_step "4" "Setting up LUKS encryption..."
    echo -n "${BLUE}${BOLD}Enter encryption password: ${RESET}"
    read -s LUKS_PASSWORD
    echo
    echo -n "${BLUE}${BOLD}Confirm encryption password: ${RESET}"
    read -s LUKS_PASSWORD_CONFIRM
    echo
    
    if [[ "$LUKS_PASSWORD" != "$LUKS_PASSWORD_CONFIRM" ]]; then
        print_error "Passwords do not match. Exiting."
        exit 1
    fi
    
    if [[ "$ENCRYPT_BOOT" == true ]]; then
        # Two separate LUKS containers: LUKS1 for /boot, LUKS2 for root
        print_step "4.1" "Creating LUKS1 container for /boot (GRUB compatible)..."
        echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks1 "$BOOT_LUKS_PART" -
        echo -n "$LUKS_PASSWORD" | cryptsetup open "$BOOT_LUKS_PART" cryptboot -
        
        print_step "4.2" "Creating LUKS2 container for root..."
        echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 "$ROOT_LUKS_PART" -
        echo -n "$LUKS_PASSWORD" | cryptsetup open "$ROOT_LUKS_PART" "$LUKS_NAME" -
        
        # Format encrypted boot partition directly
        BOOT_PART="/dev/mapper/cryptboot"
    else
        # Single LUKS2 container for root only
        print_step "4.1" "Creating LUKS2 container..."
        echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 "$LUKS_PART" -
        echo -n "$LUKS_PASSWORD" | cryptsetup open "$LUKS_PART" "$LUKS_NAME" -
    fi
    
    print_step "5" "Setting up LVM..."
    pvcreate "/dev/mapper/$LUKS_NAME"
    vgcreate "$VG_NAME" "/dev/mapper/$LUKS_NAME"
    
    # LVM always contains swap and root (boot is separate when encrypted)
    lvcreate -L 4G "$VG_NAME" -n "$LV_SWAP_NAME"
    lvcreate -l 100%FREE "$VG_NAME" -n "$LV_ROOT_NAME"
    
    SWAP_PART="/dev/$VG_NAME/$LV_SWAP_NAME"
    ROOT_PART="/dev/$VG_NAME/$LV_ROOT_NAME"
    
    print_step "6" "Formatting partitions..."
    mkfs.fat -F32 "$EFI_PART"
    mkfs.ext4 -L boot "$BOOT_PART"
    mkswap "$SWAP_PART"
    mkfs.ext4 -L root "$ROOT_PART"
    
    print_step "7" "Mounting filesystems..."
    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot
    mount "$BOOT_PART" /mnt/boot
    mkdir -p /mnt/boot/EFI
    mount "$EFI_PART" /mnt/boot/EFI
    swapon "$SWAP_PART"
else
    print_step "4" "Formatting partitions..."
    mkfs.fat -F32 "$EFI_PART"
    mkswap "$SWAP_PART"
    mkfs.ext4 "$ROOT_PART"
    
    print_step "5" "Mounting filesystems..."
    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot/EFI
    mount "$EFI_PART" /mnt/boot/EFI
    swapon "$SWAP_PART"
fi

print_step "8" "Installing base system and essentials..."
if [[ "$USE_ENCRYPTION" == true ]]; then
    pacstrap /mnt base linux linux-firmware zsh sudo git curl $EDITOR terminus-font grc lvm2 cryptsetup
else
    pacstrap /mnt base linux linux-firmware zsh sudo git curl $EDITOR terminus-font grc
fi

print_step "9" "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

print_step "10" "Chrooting into system for config..."

# Create a temporary script to run inside chroot
cat > /mnt/root/setup.sh <<'SCRIPT'
#!/usr/bin/env zsh
set -e  # errexit
set -u  # nounset

# These will be replaced with sed
USRNAME="TEMPLATE_USRNAME"
HOSTNAME="TEMPLATE_HOSTNAME"
TIMEZONE="TEMPLATE_TIMEZONE"
LOCALE="TEMPLATE_LOCALE"
LANG="TEMPLATE_LANG"
PASSWORD="TEMPLATE_PASSWORD"
USE_ENCRYPTION="TEMPLATE_USE_ENCRYPTION"
ENCRYPT_BOOT="TEMPLATE_ENCRYPT_BOOT"
LUKS_NAME="TEMPLATE_LUKS_NAME"
LUKS_PART_DEVICE="TEMPLATE_LUKS_PART_DEVICE"

print_step() {
    echo "\e[34m\e[1m[\e[97m${1}\e[34m] ${2}\e[0m"
}

print_success() {
    echo "\e[32m\e[1m[OK] ${1}\e[0m"
}

print_error() {
    echo "\e[31m\e[1m[ERROR] ${1}\e[0m" >&2
}

print_warning() {
    echo "\e[33m\e[1m[WARNING] ${1}\e[0m"
}
SCRIPT

# Replace the template values with actual values using a loop
typeset -A TEMPLATE_VARS
TEMPLATE_VARS=(
    TEMPLATE_USRNAME "$USRNAME"
    TEMPLATE_HOSTNAME "$HOSTNAME"
    TEMPLATE_TIMEZONE "$TIMEZONE"
    TEMPLATE_LOCALE "$LOCALE"
    TEMPLATE_LANG "$LANG"
    TEMPLATE_PASSWORD "$PASSWORD"
    TEMPLATE_USE_ENCRYPTION "$USE_ENCRYPTION"
    TEMPLATE_ENCRYPT_BOOT "$ENCRYPT_BOOT"
)

for key value in "${(@kv)TEMPLATE_VARS}"; do
    sed -i "s|${key}|${value}|g" /mnt/root/setup.sh
done

# Add encryption-specific variables if needed
if [[ "$USE_ENCRYPTION" == true ]]; then
    sed -i "s|TEMPLATE_LUKS_NAME|${LUKS_NAME}|g" /mnt/root/setup.sh
    
    if [[ "$ENCRYPT_BOOT" == true ]]; then
        # When boot is encrypted, pass the root LUKS partition
        sed -i "s|TEMPLATE_LUKS_PART_DEVICE|${ROOT_LUKS_PART}|g" /mnt/root/setup.sh
    else
        # Standard encryption, single LUKS partition
        sed -i "s|TEMPLATE_LUKS_PART_DEVICE|${LUKS_PART}|g" /mnt/root/setup.sh
    fi
fi

# Append the rest of the setup script
cat >> /mnt/root/setup.sh <<'SCRIPT'
set -e  # errexit
set -u  # nounset

print_step "10.1" "Timezone & clock setup"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

print_step "10.2" "Locale setup"
sed -i "s|^#${LOCALE}|${LOCALE}|" /etc/locale.gen
locale-gen
echo "LANG=$LANG" > /etc/locale.conf

print_step "10.3" "Hostname setup"
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOT
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT

if [[ "$USE_ENCRYPTION" == "true" ]]; then
    print_step "10.3.5" "Configuring mkinitcpio for encryption"
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
fi

print_step "10.4" "Initramfs"
mkinitcpio -P

print_step "10.5" "Networking"
pacman -S --noconfirm networkmanager wpa_supplicant wireless_tools netctl || {
    print_error "Failed to install networking packages"
    exit 1
}
systemctl enable NetworkManager

print_step "10.6" "Bootloader"
set +e
pacman -S --noconfirm grub efibootmgr dosfstools os-prober
PACMAN_EXIT=$?
set -e

if [[ $PACMAN_EXIT -ne 0 ]]; then
    print_error "Failed to install bootloader packages (exit code: $PACMAN_EXIT)"
    exit 1
fi

if [[ "$USE_ENCRYPTION" == "true" ]]; then
    if [[ "$ENCRYPT_BOOT" == "true" ]]; then
        # Two LUKS devices: get UUID of root LUKS partition for kernel
        set +e
        ROOT_UUID=$(blkid -s UUID -o value "$LUKS_PART_DEVICE" 2>&1)
        BLKID_EXIT=$?
        set -e
        
        [[ $BLKID_EXIT -ne 0 ]] && { print_error "Failed to get root partition UUID"; exit 1; }
        
        sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${ROOT_UUID}:${LUKS_NAME}\"|" /etc/default/grub
        echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
        
        # Configure crypttab for the boot partition
        set +e
        BOOT_UUID=$(blkid -s UUID -o value /dev/disk/by-partlabel/Encrypted\ Boot 2>&1)
        [[ $? -ne 0 ]] && BOOT_UUID=$(blkid -s UUID -o value /dev/disk/by-partlabel/Encrypted\\x20Boot 2>&1)
        set -e
        
        echo "cryptboot UUID=${BOOT_UUID} none luks" > /etc/crypttab
        
        print_warning "Encrypted /boot: You will enter password TWICE at boot"
        print_warning "  1) GRUB unlocks /boot (LUKS1)"
        print_warning "  2) Kernel unlocks root (LUKS2)"
    else
        # Single LUKS device
        UUID=$(blkid -s UUID -o value "$LUKS_PART_DEVICE")
        sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${UUID}:${LUKS_NAME}\"|" /etc/default/grub
    fi
fi

set +e
if [[ "$ENCRYPT_BOOT" == "true" ]]; then
    grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck --modules="part_gpt part_msdos luks cryptodisk"
    GRUB_EXIT=$?
else
    grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
    GRUB_EXIT=$?
fi
set -e

[[ $GRUB_EXIT -ne 0 ]] && { print_error "Failed to install GRUB"; exit 1; }

cp /usr/share/locale/en@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo || true

set +e
grub-mkconfig -o /boot/grub/grub.cfg
GRUB_CFG_EXIT=$?
set -e

[[ $GRUB_CFG_EXIT -ne 0 ]] && { print_error "Failed to generate GRUB config"; exit 1; }

if [[ "$USE_ENCRYPTION" == "true" ]] && [[ "$ENCRYPT_BOOT" == "false" ]]; then
    print_step "10.6.5" "Creating /boot integrity checksums"
    
    # Create checksums directory
    mkdir -p /var/lib/boot-checksums
    
    # Generate checksums for all files in /boot
    find /boot -type f -exec sha256sum {} \; > /var/lib/boot-checksums/boot.sha256
    chmod 600 /var/lib/boot-checksums/boot.sha256
    
    # Create consolidated boot integrity script
    cat > /usr/local/bin/boot-integrity <<'INTEGRITYSC'
#!/usr/bin/env bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
CHECKSUM_FILE="/var/lib/boot-checksums/boot.sha256"
METADATA_FILE="/var/lib/boot-checksums/boot.metadata"
BACKUP_FILE="$CHECKSUM_FILE.backup"
TEMP_FILE="/tmp/boot-check-$$.sha256"

verify() {
    VERBOSE=0
    [[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]] && VERBOSE=1
    [[ ! -f "$CHECKSUM_FILE" ]] && { echo -e "${RED}ERROR: No checksum file${NC}"; exit 1; }
    
    echo -e "${BLUE}=== Boot Integrity Verification ===${NC}"
    echo ""
    echo "Last updated: $(stat -c %y "$CHECKSUM_FILE" 2>/dev/null || stat -f "%Sm" "$CHECKSUM_FILE")"
    echo "Files tracked: $(wc -l < "$CHECKSUM_FILE")"
    echo ""
    
    find /boot -type f -exec sha256sum {} \; | sort > "$TEMP_FILE"
    echo "Current files: $(wc -l < "$TEMP_FILE")"
    echo ""
    
    ADDED=$(comm -13 <(sort "$CHECKSUM_FILE" | awk '{print $2}') <(sort "$TEMP_FILE" | awk '{print $2}'))
    REMOVED=$(comm -23 <(sort "$CHECKSUM_FILE" | awk '{print $2}') <(sort "$TEMP_FILE" | awk '{print $2}'))
    MODIFIED=""
    while IFS= read -r line; do
        HASH=$(echo "$line" | awk '{print $1}'); FILE=$(echo "$line" | awk '{print $2}')
        STORED=$(grep -F "$FILE" "$CHECKSUM_FILE" 2>/dev/null | awk '{print $1}')
        [[ -n "$STORED" ]] && [[ "$HASH" != "$STORED" ]] && MODIFIED="$MODIFIED$FILE\n"
    done < "$TEMP_FILE"
    
    if [[ -z "$ADDED" ]] && [[ -z "$REMOVED" ]] && [[ -z "$MODIFIED" ]]; then
        echo -e "${GREEN}[PASS] INTEGRITY CHECK PASSED${NC}"
        if [[ $VERBOSE -eq 1 ]]; then
            echo ""
            echo -e "${BLUE}=== Verified Files ===${NC}"
            cat "$TEMP_FILE" | sed "s/^/  /"
        fi
        rm "$TEMP_FILE"; exit 0
    fi
    
    echo -e "${RED}[FAIL] INTEGRITY CHECK FAILED${NC}"
    echo ""
    [[ -n "$ADDED" ]] && { echo -e "${YELLOW}Added files:${NC}"; echo "$ADDED" | sed "s/^/  + /"; echo ""; }
    [[ -n "$REMOVED" ]] && { echo -e "${RED}Removed files:${NC}"; echo "$REMOVED" | sed "s/^/  - /"; echo ""; }
    [[ -n "$MODIFIED" ]] && { echo -e "${YELLOW}Modified files:${NC}"; echo -e "$MODIFIED" | sed "s/^/  ~ /"; echo ""; }
    echo -e "${RED}WARNING: Changes detected${NC}"
    echo "If legitimate: sudo boot-integrity update"
    rm "$TEMP_FILE"; exit 1
}

update() {
    [[ $EUID -ne 0 ]] && { echo "Must run as root"; exit 1; }
    echo -e "${BLUE}=== Updating Boot Checksums ===${NC}"
    echo ""
    [[ -f "$CHECKSUM_FILE" ]] && { cp "$CHECKSUM_FILE" "$BACKUP_FILE"; echo -e "${GREEN}[OK] Backed up${NC}"; }
    
    FILE_COUNT=$(find /boot -type f | wc -l)
    echo -e "Scanning... Files: ${YELLOW}$FILE_COUNT${NC}"
    echo ""
    find /boot -type f -exec sha256sum {} \; > "$CHECKSUM_FILE"; chmod 600 "$CHECKSUM_FILE"
    
    cat > "$METADATA_FILE" <<META
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Kernel: $(uname -r)
# Files: $FILE_COUNT
META
    command -v pacman &>/dev/null && pacman -Q | grep "^linux\|^grub\|^efibootmgr" >> "$METADATA_FILE" 2>/dev/null
    chmod 600 "$METADATA_FILE"
    
    echo -e "${GREEN}[OK] Checksums updated${NC}"
    echo "Verify: sudo boot-integrity verify"
}

info() {
    echo -e "${BLUE}=== Boot Integrity Info ===${NC}"
    echo ""
    [[ ! -f "$CHECKSUM_FILE" ]] && { echo -e "${RED}No checksum file${NC}"; exit 1; }
    
    echo -e "${GREEN}Database:${NC}"
    echo "  Files: $(wc -l < "$CHECKSUM_FILE")"
    echo "  Updated: $(stat -c %y "$CHECKSUM_FILE" 2>/dev/null || stat -f "%Sm" "$CHECKSUM_FILE")"
    if [[ -f "$METADATA_FILE" ]]; then
        echo ""
        echo -e "${BLUE}Metadata:${NC}"
        cat "$METADATA_FILE"
    fi
    if [[ -f "$BACKUP_FILE" ]]; then
        echo ""
        echo -e "${GREEN}Backup:${NC} $BACKUP_FILE ($(wc -l < "$BACKUP_FILE") files)"
    fi
    echo ""
    echo -e "${BLUE}Current:${NC} $(find /boot -type f | wc -l) files, $(du -sh /boot | awk '{print $1}')"
}

case "${1:-}" in
    verify) shift; verify "$@";;
    update) update;;
    info) info;;
    *) echo "Usage: boot-integrity {verify|update|info} [--verbose|-v]"; exit 1;;
esac
INTEGRITYSC

    chmod +x /usr/local/bin/boot-integrity || {
        print_error "Failed to make boot-integrity executable"
        exit 1
    }
    
    # Create pacman hook to warn about kernel updates
    mkdir -p /etc/pacman.d/hooks
    cat > /etc/pacman.d/hooks/99-boot-checksum-warning.hook <<'HOOKCONTENT'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux
Target = linux-lts
Target = linux-zen
Target = linux-hardened

[Action]
Description = Warning: /boot has been modified - update checksums
When = PostTransaction
Exec = /usr/bin/bash -c 'echo ""; echo "WARNING: Kernel updated - /boot contents changed"; echo "Run: sudo boot-integrity update"; echo ""'
HOOKCONTENT

    print_step "10.6.6" "Boot integrity tools installed"
    echo "Command: boot-integrity {verify|update|info}"
    echo "  sudo boot-integrity verify      - Check for modifications"
    echo "  sudo boot-integrity verify -v   - Detailed check with checksums"
    echo "  sudo boot-integrity update      - Update after legitimate changes"
    echo "  boot-integrity info             - View checksum database info"
fi

print_step "10.7" "Creating user $USRNAME"
# Delete the user first if it exists (including their home directory and mail spool)
id -u "$USRNAME" >/dev/null 2>&1 && userdel -r "$USRNAME" >/dev/null 2>&1
# Create new user
useradd -m -g users -G wheel "$USRNAME"
echo "${USRNAME}:${PASSWORD}" | chpasswd

print_step "10.8" "Sudo permissions"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

print_step "10.9" "Setting Zsh as default shell for user"
chsh -s /usr/bin/zsh "$USRNAME"

print_step "10.10" "Installing oh-my-zsh and configuring colors for user"
su - "$USRNAME" << 'ZSHSETUP'
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="frisk"/' ~/.zshrc
echo '# Custom additions' >> ~/.zshrc
echo "export LANG=${LANG}" >> ~/.zshrc

# Basic color support
cat >> ~/.zshrc << 'COLORCONFIG'
autoload -U colors && colors
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

# Advanced color configuration
export TERM="xterm-256color"
[[ -f ~/.dir_colors ]] && eval $(dircolors ~/.dir_colors)
export LS_COLORS="${LS_COLORS:-rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=00:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.avif=01;35:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36}"

# Generic command coloring
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ip='ip -c=auto'
setopt PROMPT_SUBST

# GRC (Generic Colouriser) configuration
[[ -s "/etc/grc.zsh" ]] && source /etc/grc.zsh

# Additional command color aliases
alias diff='diff --color=auto'
alias pacman='pacman --color=auto'
alias dmesg='dmesg --color=auto'
COLORCONFIG
ZSHSETUP
SCRIPT

# Make the script executable and run it in chroot
chmod +x /mnt/root/setup.sh
arch-chroot /mnt /root/setup.sh
rm /mnt/root/setup.sh

# Ask about BlackArch repository installation
echo "${BLUE}${BOLD}Would you like to install the BlackArch repository? (y/N)${RESET}"
read -r blackarch_response
if [[ "${blackarch_response:l}" == "y" ]]; then
    print_step "11" "Installing BlackArch Repository"
    # Create a temporary script for BlackArch installation
    cat > /mnt/root/blackarch.sh <<BLACKARCH
#!/usr/bin/env zsh
set -e  # errexit
set -u  # nounset

# Variable will be replaced by sed
USRNAME="TEMPLATE_USRNAME"
PASSWORD="TEMPLATE_PASSWORD"

cd /home/\${USRNAME}
curl -O https://blackarch.org/strap.sh
chmod +x strap.sh

# Comment out the blackarch-officials installation lines
sed -i 's/^.*msg.*installing blackarch-officials.*$/# &/' strap.sh
sed -i 's/^.*pacman -S --noconfirm --needed blackarch-officials.*$/# &/' strap.sh

# Set ownership
chown \${USRNAME}:users strap.sh

# Run the modified script as the user with sudo, providing the password
echo "\${PASSWORD}" | su - \${USRNAME} -c "sudo -S ./strap.sh"

# Cleanup
rm strap.sh
BLACKARCH

    # Replace template values
    sed -i "s|TEMPLATE_USRNAME|${USRNAME}|g" /mnt/root/blackarch.sh
    sed -i "s|TEMPLATE_PASSWORD|${PASSWORD}|g" /mnt/root/blackarch.sh

    # Make the script executable and run it in chroot
    chmod +x /mnt/root/blackarch.sh
    arch-chroot /mnt /root/blackarch.sh
    rm /mnt/root/blackarch.sh
    print_success "BlackArch repository installed successfully!"
fi

# Ask about SSH server installation
echo "${BLUE}${BOLD}Would you like to install an SSH server? (y/N)${RESET}"
read -r ssh_response
if [[ "${ssh_response:l}" == "y" ]]; then
    echo "Choose SSH authentication method:"
    echo "  1) Password-based"
    echo "  2) Key-based"
    read -r auth_method
    auth_method=${auth_method:-1}

    print_step "12" "Installing OpenSSH server"
    cat > /mnt/root/sshsetup.sh <<'SSHSCRIPT'
#!/usr/bin/env zsh
set -e
set -u

AUTH_METHOD="TEMPLATE_AUTH_METHOD"
USRNAME="TEMPLATE_USRNAME"

print_step() {
    echo "\e[34m\e[1m[\e[97m${1}\e[34m] ${2}\e[0m"
}

print_step "12.1" "Installing openssh"
pacman -S --noconfirm openssh

print_step "12.2" "Enabling sshd service"
systemctl enable sshd

if [[ "$AUTH_METHOD" == "2" ]]; then
  # Define color variables locally in case they're out of scope
    BLUE=$'\e[34m'
    BOLD=$'\e[1m'
    RESET=$'\e[0m'
    print_step "12.3" "Configuring key-based authentication"
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    mkdir -p /home/TEMPLATE_USRNAME/.ssh
    chown TEMPLATE_USRNAME:users /home/TEMPLATE_USRNAME/.ssh
    chmod 700 /home/TEMPLATE_USRNAME/.ssh
    echo "${BLUE}${BOLD}IMPORTANT:${RESET} You enabled SSH key-based authentication."
    echo " - Before rebooting, you must copy your SSH public key into the installed system."
    echo " - Recommended:"
    echo "     ssh-copy-id -i ~/.ssh/id_rsa.pub ${USRNAME}@<installed-system-ip>"
    echo " - Or manually place your public key at:"
    echo "     /home/${USRNAME}/.ssh/authorized_keys"
    echo " - If you donÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â½ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“t have a key yet, generate one with:"
    echo "     ssh-keygen -t ed25519 -C \"your_email@example.com\""
    echo " - After adding the key, reboot and connect using:"
    echo "     ssh ${USRNAME}@<installed-system-ip>"
else
    print_step "12.3" "Configuring password-based authentication"
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PubkeyAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo "Password-based authentication enabled."
fi

print_step "12.4" "Restarting sshd"
systemctl restart sshd
SSHSCRIPT

    # Replace template values
    sed -i "s|TEMPLATE_AUTH_METHOD|${auth_method}|g" /mnt/root/sshsetup.sh
    sed -i "s|TEMPLATE_USRNAME|${USRNAME}|g" /mnt/root/sshsetup.sh

    chmod +x /mnt/root/sshsetup.sh
    arch-chroot /mnt /root/sshsetup.sh
    rm /mnt/root/sshsetup.sh
    print_success "OpenSSH server installed and configured!"
fi

echo ""
print_success "Installation complete!"
echo ""

if [[ "$USE_ENCRYPTION" == true ]] && [[ "$ENCRYPT_BOOT" == false ]]; then
    print_warning "Boot Integrity Monitoring Enabled:"
    echo "  Quick check:   sudo boot-integrity verify"
    echo "  Detailed:      sudo boot-integrity verify -v"
    echo "  Update:        sudo boot-integrity update"
    echo "  Info:          boot-integrity info"
    echo ""
fi

echo "You may now:"
echo "  1. umount -R /mnt"
echo "  2. reboot"
