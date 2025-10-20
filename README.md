#  BlackStrap - Automated Arch + BlackArch Installer

**BlackStrap** is an interactive Zsh-based install script that automates the installation of an Arch Linux system from scratch — with optional LUKS encryption, BlackArch tools, and SSH server preconfigured.

It handles full disk formatting, encryption setup, filesystem configuration, system bootstrap, user creation, Zsh customization, and more.

---

##  Key Features

###  Advanced Encryption Options
- **Standard Encryption (Recommended)**: LUKS2 for root, unencrypted /boot with integrity monitoring
- **Full Disk Encryption**: Dual LUKS setup - LUKS1 for /boot (GRUB-compatible) + LUKS2 for root (modern security)
- **No Encryption**: For testing/VMs

###  Boot Integrity Monitoring
- Unified `boot-integrity` command with subcommands
- Automatic checksum generation for /boot contents
- Pacman hooks warn about kernel updates
- Detects tampering/evil maid attacks

###  What's Included
- **Full UEFI-based Arch installation**
- **LVM on LUKS encryption** (optional)
- **Automated disk partitioning** (EFI + boot + encrypted root)
- **Zsh and [Oh My Zsh](https://ohmyz.sh/)** configured for the user
- **Custom LS_COLORS** and prompt color configuration
- **Optional [BlackArch](https://www.blackarch.org/)** repository integration
- **Optional SSH server** with password or key-based auth
- **Clean, color-coded** terminal output

---

## Requirements

- A UEFI-enabled system
- A live Arch Linux USB boot environment
- Internet access
- At least 20GB of available disk space (more for encrypted systems)

---

## Quick Start

### Standard Installation (Recommended)
```bash
./blackstrap.sh
```
- LUKS2 encryption for root partition
- Unencrypted /boot with integrity monitoring
- Single password prompt at boot
- Boot integrity checksums protect against tampering

### Full Disk Encryption (Maximum Security)
```bash
./blackstrap.sh --encrypt-boot
```
- **Advanced**: LUKS1 for /boot + LUKS2 for root (dual encryption)
- Requires password **twice** at boot (GRUB, then kernel)
- Maximum security - entire disk encrypted including kernel
- Uses same password for both prompts

### No Encryption (Testing/VMs)
```bash
./blackstrap.sh --no-encryption
```

### Help
```bash
./blackstrap.sh --help
```

---

##  Usage

1. Boot into a live Arch environment (e.g., official ISO)
2. Connect to the internet (`ping archlinux.org` to verify)
3. Download or copy this script:
   ```bash
   curl -O https://raw.githubusercontent.com/axiom0x0/BlackStrap/main/blackstrap.sh
   chmod +x blackstrap.sh
   ```
4. Run the script with your desired options:
   ```bash
   ./blackstrap.sh              # Standard with encryption
   ./blackstrap.sh --no-encryption  # Without encryption
   ./blackstrap.sh --encrypt-boot   # Full disk encryption
   ```
5. The script will **interactively prompt** you for:
   - Target disk selection
   - Hostname
   - Username and password
   - Timezone
   - Text editor preference
   - Encryption password (if applicable)
   - BlackArch repository installation (optional)
   - SSH server setup (optional)

6. After installation completes, reboot and enjoy your new Arch system!

---

##  Encryption Features

### Boot Integrity Monitoring

When using standard encryption (unencrypted `/boot`), the unified boot integrity tool is installed:

```bash
# Check for tampering (quick)
sudo boot-integrity verify

# Detailed check with file checksums
sudo boot-integrity verify -v

# Update checksums after kernel updates
sudo boot-integrity update

# View database information
boot-integrity info
```

A pacman hook automatically warns you when `/boot` is modified during updates.

### Disk Layouts

**Standard Encryption (Default - Recommended):**
```
/dev/sda1 → EFI (512MB, unencrypted)
/dev/sda2 → /boot (1GB, unencrypted, checksummed)
/dev/sda3 → LUKS2 → LVM
            ├─ swap (4GB)
            └─ root (remaining)
```
- ✅ Best balance of security and usability
- ✅ Single password at boot
- ✅ Boot integrity monitoring detects tampering
- ✅ Modern LUKS2 encryption with Argon2id

**Full Disk Encryption (--encrypt-boot - Maximum Security):**
```
/dev/sda1 → EFI (512MB, unencrypted - required by UEFI)
/dev/sda2 → LUKS1 → /boot (1GB, encrypted)
/dev/sda3 → LUKS2 → LVM
            ├─ swap (4GB)
            └─ root (remaining)
```
- ✅ Maximum security - kernel and initramfs encrypted
- ✅ Dual LUKS: LUKS1 for GRUB compatibility, LUKS2 for modern security
- ⚠️ Two password prompts at boot (same password)
- ⚠️ Slightly longer boot time

**No Encryption (--no-encryption - Testing only):**
```
/dev/sda1 → EFI (512MB)
/dev/sda2 → swap (4GB)
/dev/sda3 → root (remaining)
```
- For VMs and testing environments only
- No security features

---

##  Optional: SSH Server Setup

During installation, you can choose to install and configure an SSH server with two authentication methods:

### Password-Based Authentication
- Standard SSH with password login
- Quick and simple setup
- Suitable for trusted networks

### Key-Based Authentication (Recommended)
- More secure than passwords
- The script will:
  1. Set up a **temporary SSH server in the live environment**
  2. Display connection details (IP, temp user, password)
  3. Wait for you to run `ssh-copy-id` from your local machine
  4. Copy your public key to the new system
  5. Configure SSH with **password authentication disabled**

**Important**: With key-based auth, you must have your SSH keys ready or the script will help you create them. Without copying your key during installation, you won't be able to SSH into the system after reboot!

Example workflow:
```bash
# On your local machine (when prompted during installation):
ssh-copy-id -i ~/.ssh/id_ed25519.pub keysetup_1234567890@192.168.1.100

# After reboot, connect with your normal user:
ssh yourusername@192.168.1.100
```

---

##  Optional: BlackArch Support

If you opt in during the install, BlackStrap will:

- Download the BlackArch `strap.sh` installer
- Modify it to skip installing the new `blackarch-officials` bloat
- Run it as the new user
- Set proper permissions and cleanup

---

##  What It Installs

**Base System:**
- `base`, `linux`, `linux-firmware`
- `zsh`, `sudo`, `curl`, `git`, `wget`
- `terminus-font`, `grc`, your chosen editor
- `NetworkManager`, `grub`, `efibootmgr`, `os-prober`

**With Encryption:**
- `lvm2`, `cryptsetup`
- Boot integrity monitoring tool (standard encryption)
- Automatic crypttab configuration (full disk encryption)
- Pacman hooks for update warnings

**Optional Features:**
- BlackArch repository and tools
- SSH server (OpenSSH) with password or key-based authentication
- Oh My Zsh with custom configuration

---

##  Security Notes

### Why Two Password Prompts with --encrypt-boot?

When you use `--encrypt-boot`, you get maximum security but need to enter your password twice:

1. **GRUB prompt**: Unlocks `/boot` (LUKS1) to read kernel and initramfs
2. **Kernel prompt**: Unlocks root filesystem (LUKS2) to boot the system

**Why LUKS1 + LUKS2?**
- GRUB can only decrypt LUKS1 (not LUKS2)
- LUKS2 uses Argon2id (much stronger than LUKS1's PBKDF2)
- This setup gives you GRUB compatibility + modern encryption
- Both prompts use the **same password** you set during installation

**Is it worth it?**
- For high-security environments: **Yes** - prevents evil maid attacks completely
- For most users: **No** - standard encryption with boot integrity monitoring is sufficient

### Boot Integrity vs Full Disk Encryption

| Feature | Standard (Default) | Full Disk (--encrypt-boot) |
|---------|-------------------|----------------------------|
| Root filesystem | ✅ LUKS2 encrypted | ✅ LUKS2 encrypted |
| /boot partition | ❌ Unencrypted | ✅ LUKS1 encrypted |
| Password prompts | 1 (at boot) | 2 (GRUB + boot) |
| Tampering detection | ✅ SHA256 checksums | ✅ Encryption |
| Evil maid protection | ⚠️ Detection only | ✅ Full prevention |
| Ease of use | ✅ Simple | ⚠️ More complex |
| Boot time | ✅ Fast | ⚠️ Slightly slower |

---

##  Additional Notes

**For deployment:**
- All configuration is now handled via interactive prompts
- No need to edit the script directly
- The script validates inputs and provides helpful error messages
- Review and customize the encryption setup for your specific needs

---

##  File Overview

| File                 | Description                                      |
|----------------------|--------------------------------------------------|
| `blackstrap.sh`      | Main install script                              |
| `/mnt/root/setup.sh` | Temporary setup script executed in chroot        |
| `/mnt/root/sshsetup.sh` | Temporary SSH configuration script (optional) |
| `/mnt/root/blackarch.sh` | Temporary BlackArch install (optional)       |

---

##  Future Improvements

- BTRFS or other filesystem options
- Multi-boot support
- Custom partition sizing

---

##  Issues & Contributing

Open an issue or submit a PR if something breaks. This script assumes:
- A clean UEFI system
- Single disk installation
- No existing partitions to preserve

For dual-boot or complex setups, manual partitioning may be required.
