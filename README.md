![BlackStrap](BlackStrap2.jpg)

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
- **BTRFS or ext4 filesystem** with optional snapshots (snapper)
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
- Requires password **three times** at boot (GRUB reads, kernel root unlock, kernel boot mount)
- Maximum security - entire disk encrypted including kernel
- Uses same password for all prompts
- Optional keyfile reduces this to single password at GRUB

### No Encryption (Testing/VMs)
```bash
./blackstrap.sh --no-encryption
```

### BTRFS Filesystem
During installation, you'll be prompted to choose between:
- **ext4** (default) - Traditional, reliable
- **BTRFS** - Modern with compression, snapshots, and snapper integration
  - zstd compression (typical 30-40% space savings)
  - Subvolume layout: @, @home, @var_log
  - Automatic snapshot management with snapper

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
   - Filesystem type (ext4 or BTRFS)
   - Text editor preference
   - Encryption password (if applicable)
   - Keyfile for encrypted boot (if applicable)
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

**Automatic Protection:**
- Boot-time verification runs automatically on each boot
- If tampering is detected, a warning message appears on login (MOTD)
- Shows which files were modified and instructions to investigate or update
- Pacman hook warns you when `/boot` is modified during updates

### Disk Layouts

**Standard Encryption (Default - Recommended):**
```
/dev/sda1 → EFI (512MB, unencrypted)
/dev/sda2 → /boot (1GB, unencrypted, checksummed)
/dev/sda3 → LUKS2 → LVM
            ├─ swap (4GB)
            └─ root (remaining, ext4 or BTRFS)
```
- ✅ Best balance of security and usability
- ✅ Single password at boot
- ✅ Boot integrity monitoring detects tampering
- ✅ Modern LUKS2 encryption with Argon2id
- ✅ Optional BTRFS with compression and snapper snapshots

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
- ⚠️ Three password prompts at boot without keyfile (same password)
- ⚠️ One password prompt with keyfile (recommended)
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

**VM Testing Note**: Your host machine must be able to reach the VM's IP address to run `ssh-copy-id` during installation. If using default VM networking (NAT), you may not be able to access the VM's IP from your host. In this case, configure **bridge networking** in your VM settings so the VM gets an IP on your local network. This has been tested successfully with VMware Fusion on macOS using bridged networking.

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

**With BTRFS:**
- `btrfs-progs` utilities
- `snapper` for snapshot management
- Automatic snapper configuration on first boot
- Subvolume layout optimized for snapshots

**Optional Features:**
- BlackArch repository and tools
- SSH server (OpenSSH) with password or key-based authentication
- Oh My Zsh with custom configuration

---

##  Security Notes

### Password Prompts with --encrypt-boot

When you use `--encrypt-boot`, you'll be asked during installation whether to use a keyfile:

**Without Keyfile (3 password prompts):**
1. **GRUB prompt**: Unlocks `/boot` (LUKS1) to read kernel and initramfs
2. **Kernel prompt**: Unlocks root filesystem (LUKS2)
3. **Kernel prompt**: Unlocks `/boot` again for mounting

**With Keyfile (1 password prompt - Recommended):**
1. **GRUB prompt**: Unlocks `/boot` (LUKS1) to read kernel and initramfs
2. Root and `/boot` auto-unlock via embedded keyfile

**Why LUKS1 + LUKS2?**
- GRUB can only decrypt LUKS1 (not LUKS2)
- LUKS2 uses Argon2id (much stronger than LUKS1's PBKDF2)
- This setup gives you GRUB compatibility + modern encryption
- All prompts use the **same password** you set during installation

**Is it worth it?**
- For high-security environments: **Yes** - prevents evil maid attacks completely
- For most users: **No** - standard encryption with boot integrity monitoring is sufficient
- If using encrypted boot, the keyfile option is highly recommended

### Boot Integrity vs Full Disk Encryption

| Feature | Standard (Default) | Full Disk (no keyfile) | Full Disk (with keyfile) |
|---------|-------------------|------------------------|-------------------------|
| Root filesystem | ✅ LUKS2 encrypted | ✅ LUKS2 encrypted | ✅ LUKS2 encrypted |
| /boot partition | ❌ Unencrypted | ✅ LUKS1 encrypted | ✅ LUKS1 encrypted |
| Password prompts | 1 (at boot) | 3 (GRUB + root + boot) | 1 (GRUB only) |
| Tampering detection | ✅ SHA256 checksums | ✅ Encryption | ✅ Encryption |
| Evil maid protection | ⚠️ Detection only | ✅ Full prevention | ✅ Full prevention |
| Ease of use | ✅ Simple | ⚠️ Complex | ✅ Reasonable |
| Boot time | ✅ Fast | ⚠️ Slightly slower | ⚠️ Slightly slower |

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

- Multi-boot support
- Custom partition sizing
- Additional filesystem options (XFS, F2FS)

---

##  Issues & Contributing

Open an issue or submit a PR if something breaks. This script assumes:
- A clean UEFI system
- Single disk installation
- No existing partitions to preserve

For dual-boot or complex setups, manual partitioning may be required.
