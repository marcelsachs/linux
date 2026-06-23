#!/usr/bin/env bash
set -euo pipefail

# config
DISK="/dev/nvme0n1"
EFI_PART="${DISK}p1"
ROOT_PART="${DISK}p2"
HOSTNAME="blackwell"
USERNAME="sachs"
TIMEZONE="Europe/Berlin"
USER_PASSWORD="hunter2"
ROOT_PASSWORD="hunter2"

PACKAGES=(
  amd-ucode arm-none-eabi-gcc arm-none-eabi-gdb arm-none-eabi-newlib
  base base-devel bluez bluez-utils btop chromium cmake cpupower cuda cudnn curl
  dmidecode dmenu docker fastfetch ffmpeg firefox
  gdb github-cli git git-lfs gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugin-pipewire
  i3-wm i3status inxi iwd jdk21-openjdk less linux linux-firmware linux-headers lm_sensors
  man-db man-pages nmap nvidia-container-toolkit nvidia-open nvidia-utils nvme-cli nvtop
  opencv openocd openssh picocom pipewire pipewire-alsa pipewire-pulse powertop python python-pip
  ranger tailscale tcpdump tmux traceroute tree ttf-ibm-plex unzip usbutils vim wget wireplumber wireshark-cli
  xclip xorg-server xorg-xev xorg-xinit xorg-xrandr xorg-xset
)

# Phase 2 inside chroot
if [[ "${1:-}" == "chroot" ]]; then
  ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
  hwclock --systohc
  printf 'en_US.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8\n' > /etc/locale.gen
  locale-gen
  echo "LANG=en_US.UTF-8" > /etc/locale.conf
  echo "${HOSTNAME}" > /etc/hostname
  printf '[Match]\nName=en* wl*\n\n[Network]\nDHCP=yes\n' > /etc/systemd/network/20-dhcp.network
  echo "KEYMAP=neoqwertz" > /etc/vconsole.conf
  useradd -m -G wheel -s /bin/bash "${USERNAME}"
  printf '%s:%s\n' "${USERNAME}" "${USER_PASSWORD}" | chpasswd
  printf '%s:%s\n' root "${ROOT_PASSWORD}" | chpasswd
  echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
  chmod 0440 /etc/sudoers.d/wheel
  fallocate -l 32G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  echo "/swapfile none swap defaults 0 0" >> /etc/fstab
  echo "root=PARTUUID=$(blkid -s PARTUUID -o value "${ROOT_PART}") rw" > /etc/kernel/cmdline
  cat > /etc/mkinitcpio.d/linux.preset <<'EOF'
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
ALL_cmdline="/etc/kernel/cmdline"
PRESETS=('default')
default_uki="/boot/EFI/BOOT/BOOTX64.EFI"
EOF
  mkdir -p /boot/EFI/BOOT
  mkinitcpio -p linux
  systemctl enable bluetooth iwd nvidia-persistenced sshd systemd-networkd systemd-resolved systemd-timesyncd tailscaled
  exit 0
fi

# Phase 1
echo ">>> This will wipe ${DISK}:"
lsblk "${DISK}"
read -rp "Type 'yes sir' to confirm: " confirm
[[ "${confirm}" == "yes sir" ]] || { echo "Aborted."; exit 1; }
timedatectl set-ntp true
pacman -Sy archlinux-keyring --noconfirm
pacman-key --init
pacman-key --populate archlinux
blkdiscard -f "${DISK}"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" -n 2:0:0   -t 2:8300 -c 2:"arch" "${DISK}"
partprobe "${DISK}"
udevadm settle
mkfs.fat -F 32 "${EFI_PART}"
mkfs.ext4 -F "${ROOT_PART}"
mount "${ROOT_PART}" /mnt
mount --mkdir "${EFI_PART}" /mnt/boot
reflector --latest 10 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
pacstrap -K /mnt "${PACKAGES[@]}"
genfstab -U /mnt >> /mnt/etc/fstab

# re-run script for phase 2
cp "$0" /mnt/root/install-arch.sh
arch-chroot /mnt /bin/bash /root/install-arch.sh chroot
rm /mnt/root/install-arch.sh
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
umount -R /mnt
echo ">>> Install complete. Reboot"
