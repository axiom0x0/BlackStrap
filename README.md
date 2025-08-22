# 🏴‍☠️ BlackStrap - Automated Arch + BlackArch Installer

**BlackStrap** is a interactive Zsh-based install script that automates the installation of an Arch Linux system from scratch — optionally with BlackArch tools and an SSH server preconfigured.

It handles full disk formatting, filesystem setup, system bootstrap, user creation, Zsh customization, and more.

---

## 📋 Features

- Full UEFI-based Arch installation
- Auto disk partitioning (EFI + swap + root)
- Zsh and [Oh My Zsh](https://ohmyz.sh/) configured for the user
- Custom LS_COLORS and prompt color configuration
- Optional [BlackArch](https://www.blackarch.org/) repository integration
- Optional SSH server install with either password or key-based auth
- Clean, color-coded terminal output

---

## 💻 Requirements

- A UEFI-enabled system
- A live Arch Linux USB boot environment
- Internet access
- At least 8GB of available disk space

---

## 🔧 Configuration

Before running the script, **edit the following variables near the top of 'blackstrap.sh'**:


```zsh
DISK="/dev/sda"         # Target installation disk (e.g., /dev/nvme0n1)
HOSTNAME="yourHOSTNAME" # Desired hostname
USRNAME="yourUSRNAME"   # New user account name
PASSWORD="changeme456"  # New user password (plaintext for now)
TIMEZONE="US/Pacific"   # Timezone (e.g., Europe/Berlin)
LOCALE="en_US.UTF-8 UTF-8"
EDITOR="vim"            # Editor to install and use
```


---

## 🚀 Usage

1. Boot into a live Arch environment (e.g., official ISO).
2. Connect to the internet ('ping archlinux.org' to verify).
3. Download or copy this repo.
4. Edit 'blackstrap.sh' and adjust configuration.
5. Run the script:
   ```zsh
   chmod +x blackstrap.sh
   ./blackstrap.sh
   ```


6. Confirm when prompted. The script will:

   - Partition and format the disk
   - Install the base system
   - Set timezone, locale, user, and shell
   - Install and configure Oh My Zsh
   - Ask if you'd like to add the BlackArch repository
   - Ask if you'd like to add an SSH server

7. Reboot and enjoy.

---

## 🕵️‍♂️ Optional: BlackArch Support

If you opt in during the install, BlackStrap will:

- Download the BlackArch 'strap.sh' installer
- Modify it to skip installing the new 'blackarch-officials' bloat
- Run it as the new user
- Set proper permissions and cleanup

---

## 🧼 What It Installs

- 'base', 'linux', 'linux-firmware'
- 'zsh', 'sudo', 'curl', 'git'
- 'terminus-font', 'grc', '$EDITOR'
- 'NetworkManager', 'grub', 'os-prober'
- Optionally: BlackArch repo and tools
- Optionally: SSH server

---

## 🔒 Security Note

For real-world deployments:

- **Do not hardcode passwords** in the script
- Use environment variables or secret files
- Use encrypted partitions (not yet supported here)

---

## 📁 File Overview

| File                 | Description                                      |
|----------------------|--------------------------------------------------|
| 'blackstrap.sh'      | Main install script                              |
| '/mnt/root/setup.sh' | Temporary setup script executed in chroot       |
| '/mnt/root/blackarch.sh' | Temporary BlackArch install (optional)     |

---

## 🧠 Things to Improve

- Encrypted LUKS installation
- BTRFS or other filesystem options
- Lighter terminal output for low-contrast environments
- Password prompt instead of hardcoded variables

---

## 🐛 Issues

Open an issue or submit a PR if something breaks. This script assumes a clean UEFI system and may not handle edge cases (e.g., dual booting).

---

## ⚰️ License

MIT – Do what you want, but don’t blame me if you wipe your system.
