#!/usr/bin/env zsh
#
# Arch Linux Automated Installation Script
# ======================================
#
# This script automates the installation of Arch Linux with a focus on security.
# It handles the entire installation process from disk partitioning to user setup
# and system configuration.
#
# Usage:
#   1. Boot into Arch Linux live environment
#   2. Download this script
#   3. Edit the configuration section (DISK, USRNAME, PASSWORD)
#   4. Make executable: chmod +x archsetup.sh
#   5. Run: ./archsetup.sh
#
# Requirements:
#   - UEFI-capable system
#   - Internet connection
#   - Sufficient disk space (minimum 20GB recommended)
#
# Features:
#   - UEFI boot setup with GRUB
#   - Automated disk partitioning (EFI, Swap, Root)
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
BOLD=$'\e[1m'
RESET=$'\e[0m'

# Function for section headers
print_step() {
    echo "${BLUE}${BOLD}[\e[97m${1}\e[34m] ${2}${RESET}"
}

# Function for success messages
print_success() {
    echo "${GREEN}${BOLD}Γ£ô ${1}${RESET}"
}

# Function for error messages
print_error() {
    echo "${RED}${BOLD}Γ¥î ${1}${RESET}" >&2
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

EFI_PART="${DISK}1"
SWAP_PART="${DISK}2"
ROOT_PART="${DISK}3"



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
sgdisk -n1:0:+512MiB  -t1:ef00 -c1:"EFI System" "$DISK"
sgdisk -n2:0:+1GiB     -t2:8200 -c2:"Swap"       "$DISK"
sgdisk -n3:0:0         -t3:8300 -c3:"Linux Root" "$DISK"
partprobe "$DISK"

print_step "4" "Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkswap "$SWAP_PART"
mkfs.ext4 "$ROOT_PART"

print_step "5" "Mounting filesystems..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot/EFI
mount "$EFI_PART" /mnt/boot/EFI
swapon "$SWAP_PART"

print_step "6" "Installing base system and essentials..."
pacstrap /mnt base linux linux-firmware zsh sudo git curl $EDITOR terminus-font grc

print_step "7" "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

print_step "8" "Chrooting into system for config..."

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

print_step() {
    echo "\e[34m\e[1m[\e[97m${1}\e[34m] ${2}\e[0m"
}
SCRIPT

# Replace the template values with actual values
sed -i "s|TEMPLATE_USRNAME|${USRNAME}|g" /mnt/root/setup.sh
sed -i "s|TEMPLATE_HOSTNAME|${HOSTNAME}|g" /mnt/root/setup.sh
sed -i "s|TEMPLATE_TIMEZONE|${TIMEZONE}|g" /mnt/root/setup.sh
sed -i "s|TEMPLATE_LOCALE|${LOCALE}|g" /mnt/root/setup.sh
sed -i "s|TEMPLATE_LANG|${LANG}|g" /mnt/root/setup.sh
sed -i "s|TEMPLATE_PASSWORD|${PASSWORD}|g" /mnt/root/setup.sh

# Append the rest of the setup script
cat >> /mnt/root/setup.sh <<'SCRIPT'
set -e  # errexit
set -u  # nounset

print_step "8.1" "Timezone & clock setup"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

print_step "8.2" "Locale setup"
sed -i "s|^#${LOCALE}|${LOCALE}|" /etc/locale.gen
locale-gen
echo "LANG=$LANG" > /etc/locale.conf

print_step "8.3" "Hostname setup"
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOT
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT

echo "[8.4] Initramfs"
mkinitcpio -P

echo "[8.5] Networking"
pacman -S --noconfirm networkmanager wpa_supplicant wireless_tools netctl
systemctl enable NetworkManager

echo "[8.6] Bootloader"
pacman -S --noconfirm grub efibootmgr dosfstools os-prober mtools
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
cp /usr/share/locale/en@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo || true
grub-mkconfig -o /boot/grub/grub.cfg

print_step "8.7" "Creating user $USRNAME"
# Delete the user first if it exists (including their home directory and mail spool)
id -u "$USRNAME" >/dev/null 2>&1 && userdel -r "$USRNAME" >/dev/null 2>&1
# Create new user
useradd -m -g users -G wheel "$USRNAME"
echo "${USRNAME}:${PASSWORD}" | chpasswd

print_step "8.8" "Sudo permissions"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

print_step "8.9" "Setting Zsh as default shell for user"
chsh -s /usr/bin/zsh "$USRNAME"

print_step "8.10" "Installing oh-my-zsh and configuring colors for user"
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
    print_step "9" "Installing BlackArch Repository"
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

    print_step "10" "Installing OpenSSH server"
    cat > /mnt/root/sshsetup.sh <<'SSHSCRIPT'
#!/usr/bin/env zsh
set -e
set -u

AUTH_METHOD="TEMPLATE_AUTH_METHOD"
USRNAME="TEMPLATE_USRNAME"

print_step() {
    echo "\e[34m\e[1m[\e[97m${1}\e[34m] ${2}\e[0m"
}

print_step "10.1" "Installing openssh"
pacman -S --noconfirm openssh

print_step "10.2" "Enabling sshd service"
systemctl enable sshd

if [[ "$AUTH_METHOD" == "2" ]]; then
  # Define color variables locally in case they're out of scope
    BLUE=$'\e[34m'
    BOLD=$'\e[1m'
    RESET=$'\e[0m'
    print_step "10.3" "Configuring key-based authentication"
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
    echo " - If you donΓÇÖt have a key yet, generate one with:"
    echo "     ssh-keygen -t ed25519 -C \"your_email@example.com\""
    echo " - After adding the key, reboot and connect using:"
    echo "     ssh ${USRNAME}@<installed-system-ip>"
else
    print_step "10.3" "Configuring password-based authentication"
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PubkeyAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo "Password-based authentication enabled."
fi

print_step "10.4" "Restarting sshd"
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

print_success "Installation complete! You may reboot now."
