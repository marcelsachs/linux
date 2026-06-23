#!/usr/bin/env bash
set -euo pipefail

# config
DISK="/dev/sda"
BIOS_PART="${DISK}1"
ROOT_PART="${DISK}1"
HOSTNAME="dell"
USERNAME="sachs"
TIMEZONE="Europe/Berlin"
USER_PASSWORD="hunter2"
ROOT_PASSWORD="hunter2"
PACKAGES=(
  base base-devel bluez bluez-utils btop chromium cmake cpupower curl
  dmenu docker fastfetch firefox gdb github-cli git git-lfs grub
  i3-wm i3status intel-ucode inxi iwd less linux linux-firmware lm_sensors
  man-db man-pages nmap openssh
  picocom pipewire pipewire-alsa pipewire-pulse powertop python python-pip
  ranger tailscale tcpdump tmux traceroute tree ttf-ibm-plex unzip usbutils vim wget wireplumber
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
  mkinitcpio -p linux
  grub-install --target=i386-pc "${DISK}"
  grub-mkconfig -o /boot/grub/grub.cfg
  systemctl enable bluetooth iwd sshd systemd-networkd systemd-resolved systemd-timesyncd tailscaled
  exit 0
fi

# Phase 1
echo ">>> This will wipe ${DISK}:"
lsblk "${DISK}"
read -rp "Type 'yes sir' to confirm: " confirm
[[ "${confirm}" == "yes sir" ]] || { echo "Aborted."; exit 1; }
wipefs -a "${DISK}"
parted -s "${DISK}" -- mklabel msdos mkpart primary ext4 1MiB 100% set 1 boot on
partprobe "${DISK}"
udevadm settle
mkfs.ext4 -F "${ROOT_PART}"
mount "${ROOT_PART}" /mnt
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
