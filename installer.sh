#!/bin/bash
#-
# Copyright (c) 2012-2015 Juan Romero Pardines <xtraeme@gmail.com>.
#               2012 Dave Elusive <davehome@redthumb.info.tm>.
#               2025 Florin Tanasă <florin.tanasa@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#-

# Set the color for dialog interface
dialogRcFile="$HOME/.dialogrc"

# This function create file .dialogrc
sh_create_dialogrc() {
  cat >"$dialogRcFile" <<-EOF
  screen_color = (white,black,off)
  dialog_color = (white,black,off)
  title_color = (cyan,black,on)
  border_color = dialog_color
  shadow_color = (black,black,on)
  button_inactive_color = dialog_color
  button_key_inactive_color = dialog_color
  button_label_inactive_color = dialog_color
  button_active_color = (white,cyan,on)
  button_key_active_color = button_active_color
  button_label_active_color = (black,cyan,on)
  tag_key_selected_color = (white,cyan,on)
  item_selected_color = tag_key_selected_color
  form_text_color = (BLUE,black,ON)
  form_item_readonly_color = (green,black,on)
  itemhelp_color = (white,cyan,off)
  inputbox_color = dialog_color
  inputbox_border_color = dialog_color
  searchbox_color = dialog_color
  searchbox_title_color = title_color
  searchbox_border_color = border_color
  position_indicator_color = title_color
  menubox_color = dialog_color
  menubox_border_color = border_color
  item_color = dialog_color
  tag_color = title_color
  tag_selected_color = button_label_active_color
  tag_key_color = button_key_inactive_color
  check_color = dialog_color
  check_selected_color = button_active_color
  uarrow_color = screen_color
  darrow_color = screen_color
  form_active_text_color = button_active_color
  gauge_color = title_color
  border2_color = dialog_color
  searchbox_border2_color = dialog_color
  menubox_border2_color = dialog_color
  separate_widget = ''
  tab_len = 0
  visit_items = off
  use_shadow = off
  use_colors = on
EOF
}

# Next function remove file .dialogrc
cleanup() {
  rm -f "$dialogRcFile"
}

# Check if file .dialogrc not exist. If is true create call function to create the .dialogrc file
if [[ ! -e "$dialogRcFile" ]]; then
  sh_create_dialogrc
fi

# Make sure we don't inherit these from env.
SOURCE_DONE=
HOSTNAME_DONE=
KEYBOARD_DONE=
LOCALE_DONE=
TIMEZONE_DONE=
ROOTPASSWORD_DONE=
USERLOGIN_DONE=
USERPASSWORD_DONE=
USERNAME_DONE=
USERGROUPS_DONE=
USERACCOUNT_DONE=
BOOTLOADER_DONE=
PARTITIONS_DONE=
NETWORK_DONE=
FILESYSTEMS_DONE=
MIRROR_DONE=

# set the date and time
date_time=$(date +'%d%m%Y_%H%M%S')

# Set directory where is mount new partition for rootfs
TARGETDIR=/mnt/target

# Set the name file for logs saving
#LOG=/dev/tty9
LOG="/tmp/install_brgvos_$date_time.log"

# Create saving file for logs
touch -f $LOG

# Set the name for config file using by installer
CONF_FILE=/tmp/.brgvos-installer.conf
# Check if exist the file is not create the file
if [ ! -f "$CONF_FILE" ]; then
  touch -f "$CONF_FILE"
fi

# Set variables with the temporal files used by installer
ANSWER=$(mktemp -t vinstall-XXXXXXXX || exit 1)
TARGET_SERVICES=$(mktemp -t vinstall-sv-XXXXXXXX || exit 1)
TARGET_FSTAB=$(mktemp -t vinstall-fstab-XXXXXXXX || exit 1)

# Exit clean from script installer.sh
# Call function "DIE" when installer.sn catch INT (Ctrl+C) TERM (terminate request) or QUIT (Ctrl+\)
trap "DIE" INT TERM QUIT

# disable printk
if [ -w /proc/sys/kernel/printk ]; then
  echo 0 >/proc/sys/kernel/printk
fi

# Detect if this is an EFI system.
if [ -e /sys/firmware/efi/systab ]; then
  EFI_SYSTEM=1
  EFI_FW_BITS=$(cat /sys/firmware/efi/fw_platform_size)
  if [ "$EFI_FW_BITS" -eq 32 ]; then
    EFI_TARGET=i386-efi
  else
    EFI_TARGET=x86_64-efi
  fi
fi

# Dialog colors
BLACK="\Z0"
RED="\Z1"
GREEN="\Z2"
YELLOW="\Z3"
BLUE="\Z4"
MAGENTA="\Z5"
CYAN="\Z6"
WHITE="\Z7"
BOLD="\Zb"
REVERSE="\Zr"
UNDERLINE="\Zu"
RESET="\Zn"

# Properties shared per widget.
MENULABEL="${BOLD}Use UP and DOWN keys to navigate \
menus. Use TAB to switch between buttons and ENTER to select.${RESET}"
MENUSIZE="14 70 0"
INPUTSIZE="8 70"
MSGBOXSIZE="8 80"
YESNOSIZE="$INPUTSIZE"
WIDGET_SIZE="10 70"

DIALOG() {
  rm -f "$ANSWER"
  dialog --colors --keep-tite --no-shadow --no-mouse \
    --backtitle "${BOLD}${WHITE}BRGV-OS Linux installation -- https://github.com/florintanasa/brgvos-void (@@MKLIVE_VERSION@@)${RESET}" \
    --cancel-label "Back" --aspect 20 "$@" 2>"$ANSWER"
  return $?
}

INFOBOX() {
  # Note: dialog --infobox and --keep-tite don't work together
  dialog --colors --no-shadow --no-mouse \
    --backtitle "${BOLD}${WHITE}BRGV-OS Linux installation -- https://github.com/florintanasa/brgvos-void (@@MKLIVE_VERSION@@)${RESET}" \
    --title "${TITLE}" --aspect 20 --infobox "$@"
}

# Function used for clean exit from script
DIE() {
  rval=$1
  # Check variable rval is empty/or have zero length and if is true set rval=0
  [ -z "$rval" ] && rval=0
  # Clear terminal screen
  clear
  # Remove temporal files
  rm -f "$ANSWER" "$TARGET_FSTAB" "$TARGET_SERVICES"
  # re-enable printk
  if [ -w /proc/sys/kernel/printk ]; then
    echo 4 >/proc/sys/kernel/printk
  fi
  # Call function to unmount filesystems
  umount_filesystems
  # Call function to remove .dialogrc
  cleanup
  # Close the script and exit with code 0 for success and with 1-255 for errors
  exit "$rval"
}

# Function used to save chosen options in configure file
set_option() {
  if grep -Eq "^${1} .*" "$CONF_FILE"; then
    sed -i -e "/^${1} .*/d" "$CONF_FILE"
  fi
  echo "${1} ${2}" >>"$CONF_FILE"
}

# Function used to load saved chosen options from configure file
get_option() {
  grep -E "^${1} .*" "$CONF_FILE" | sed -e "s|^${1} ||"
}

# ISO-639 language names for locales
iso639_language() {
  case "$1" in
  aa)  echo "Afar" ;;
  af)  echo "Afrikaans" ;;
  an)  echo "Aragonese" ;;
  ar)  echo "Arabic" ;;
  ast) echo "Asturian" ;;
  be)  echo "Belgian" ;;
  bg)  echo "Bulgarian" ;;
  bhb) echo "Bhili" ;;
  br)  echo "Breton" ;;
  bs)  echo "Bosnian" ;;
  ca)  echo "Catalan" ;;
  cs)  echo "Czech" ;;
  cy)  echo "Welsh" ;;
  da)  echo "Danish" ;;
  de)  echo "German" ;;
  el)  echo "Greek" ;;
  en)  echo "English" ;;
  es)  echo "Spanish" ;;
  et)  echo "Estonian" ;;
  eu)  echo "Basque" ;;
  fi)  echo "Finnish" ;;
  fo)  echo "Faroese" ;;
  fr)  echo "French" ;;
  ga)  echo "Irish" ;;
  gd)  echo "Scottish Gaelic" ;;
  gl)  echo "Galician" ;;
  gv)  echo "Manx" ;;
  he)  echo "Hebrew" ;;
  hr)  echo "Croatian" ;;
  hsb) echo "Upper Sorbian" ;;
  hu)  echo "Hungarian" ;;
  id)  echo "Indonesian" ;;
  is)  echo "Icelandic" ;;
  it)  echo "Italian" ;;
  iw)  echo "Hebrew" ;;
  ja)  echo "Japanese" ;;
  ka)  echo "Georgian" ;;
  kk)  echo "Kazakh" ;;
  kl)  echo "Kalaallisut" ;;
  ko)  echo "Korean" ;;
  ku)  echo "Kurdish" ;;
  kw)  echo "Cornish" ;;
  lg)  echo "Ganda" ;;
  lt)  echo "Lithuanian" ;;
  lv)  echo "Latvian" ;;
  mg)  echo "Malagasy" ;;
  mi)  echo "Maori" ;;
  mk)  echo "Macedonian" ;;
  ms)  echo "Malay" ;;
  mt)  echo "Maltese" ;;
  nb)  echo "Norwegian Bokmål" ;;
  nl)  echo "Dutch" ;;
  nn)  echo "Norwegian Nynorsk" ;;
  oc)  echo "Occitan" ;;
  om)  echo "Oromo" ;;
  pl)  echo "Polish" ;;
  pt)  echo "Portuguese" ;;
  ro)  echo "Romanian" ;;
  ru)  echo "Russian" ;;
  sk)  echo "Slovak" ;;
  sl)  echo "Slovenian" ;;
  so)  echo "Somali" ;;
  sq)  echo "Albanian" ;;
  st)  echo "Southern Sotho" ;;
  sv)  echo "Swedish" ;;
  tcy) echo "Tulu" ;;
  tg)  echo "Tajik" ;;
  th)  echo "Thai" ;;
  tl)  echo "Tagalog" ;;
  tr)  echo "Turkish" ;;
  uk)  echo "Ukrainian" ;;
  uz)  echo "Uzbek" ;;
  wa)  echo "Walloon" ;;
  xh)  echo "Xhosa" ;;
  yi)  echo "Yiddish" ;;
  zh)  echo "Chinese" ;;
  zu)  echo "Zulu" ;;
  *)   echo "$1" ;;
  esac
}

# ISO-3166 country codes for locales
iso3166_country() {
  case "$1" in
  AD) echo "Andorra" ;;
  AE) echo "United Arab Emirates" ;;
  AL) echo "Albania" ;;
  AR) echo "Argentina" ;;
  AT) echo "Austria" ;;
  AU) echo "Australia" ;;
  BA) echo "Bosnia and Herzegovina" ;;
  BE) echo "Belgium" ;;
  BG) echo "Bulgaria" ;;
  BH) echo "Bahrain" ;;
  BO) echo "Bolivia" ;;
  BR) echo "Brazil" ;;
  BW) echo "Botswana" ;;
  BY) echo "Belarus" ;;
  CA) echo "Canada" ;;
  CH) echo "Switzerland" ;;
  CL) echo "Chile" ;;
  CN) echo "China" ;;
  CO) echo "Colombia" ;;
  CR) echo "Costa Rica" ;;
  CY) echo "Cyprus" ;;
  CZ) echo "Czech Republic" ;;
  DE) echo "Germany" ;;
  DJ) echo "Djibouti" ;;
  DK) echo "Denmark" ;;
  DO) echo "Dominican Republic" ;;
  DZ) echo "Algeria" ;;
  EC) echo "Ecuador" ;;
  EE) echo "Estonia" ;;
  EG) echo "Egypt" ;;
  ES) echo "Spain" ;;
  FI) echo "Finland" ;;
  FO) echo "Faroe Islands" ;;
  FR) echo "France" ;;
  GB) echo "Great Britain" ;;
  GE) echo "Georgia" ;;
  GL) echo "Greenland" ;;
  GR) echo "Greece" ;;
  GT) echo "Guatemala" ;;
  HK) echo "Hong Kong" ;;
  HN) echo "Honduras" ;;
  HR) echo "Croatia" ;;
  HU) echo "Hungary" ;;
  ID) echo "Indonesia" ;;
  IE) echo "Ireland" ;;
  IL) echo "Israel" ;;
  IN) echo "India" ;;
  IQ) echo "Iraq" ;;
  IS) echo "Iceland" ;;
  IT) echo "Italy" ;;
  JO) echo "Jordan" ;;
  JP) echo "Japan" ;;
  KE) echo "Kenya" ;;
  KR) echo "Korea, Republic of" ;;
  KW) echo "Kuwait" ;;
  KZ) echo "Kazakhstan" ;;
  LB) echo "Lebanon" ;;
  LT) echo "Lithuania" ;;
  LU) echo "Luxembourg" ;;
  LV) echo "Latvia" ;;
  LY) echo "Libya" ;;
  MA) echo "Morocco" ;;
  MG) echo "Madagascar" ;;
  MK) echo "Macedonia" ;;
  MT) echo "Malta" ;;
  MX) echo "Mexico" ;;
  MY) echo "Malaysia" ;;
  NI) echo "Nicaragua" ;;
  NL) echo "Netherlands" ;;
  NO) echo "Norway" ;;
  NZ) echo "New Zealand" ;;
  OM) echo "Oman" ;;
  PA) echo "Panama" ;;
  PE) echo "Peru" ;;
  PH) echo "Philippines" ;;
  PL) echo "Poland" ;;
  PR) echo "Puerto Rico" ;;
  PT) echo "Portugal" ;;
  PY) echo "Paraguay" ;;
  QA) echo "Qatar" ;;
  RO) echo "Romania" ;;
  RU) echo "Russian Federation" ;;
  SA) echo "Saudi Arabia" ;;
  SD) echo "Sudan" ;;
  SE) echo "Sweden" ;;
  SG) echo "Singapore" ;;
  SI) echo "Slovenia" ;;
  SK) echo "Slovakia" ;;
  SO) echo "Somalia" ;;
  SV) echo "El Salvador" ;;
  SY) echo "Syria" ;;
  TH) echo "Thailand" ;;
  TJ) echo "Tajikistan" ;;
  TN) echo "Tunisia" ;;
  TR) echo "Turkey" ;;
  TW) echo "Taiwan" ;;
  UA) echo "Ukraine" ;;
  UG) echo "Uganda" ;;
  US) echo "United States of America" ;;
  UY) echo "Uruguay" ;;
  UZ) echo "Uzbekistan" ;;
  VE) echo "Venezuela" ;;
  YE) echo "Yemen" ;;
  ZA) echo "South Africa" ;;
  ZW) echo "Zimbabwe" ;;
  *)  echo "$1" ;;
  esac
}

# Function to display the disc(s) size in GB and sector size from system
show_disks() {
  # Define some variables locally
  local dev size sectorsize gbytes
  # IDE
  for dev in $(ls /sys/block|grep -E '^hd'); do
    if [ "$(cat /sys/block/"$dev"/device/media)" = "disk" ]; then
      # Find out nr sectors and bytes per sector;
      echo "/dev/$dev"
      size=$(cat /sys/block/"$dev"/size)
      sectorsize=$(cat /sys/block/"$dev"/queue/hw_sector_size)
      gbytes="$((size * sectorsize / 1024 / 1024 / 1024))"
      echo "size:${gbytes}GB;sector_size:$sectorsize"
    fi
  done
  # SATA/SCSI and Virtual disks (virtio)
  for dev in $(ls /sys/block|grep -E '^([sv]|xv)d|mmcblk|nvme'); do
    echo "/dev/$dev"
    size=$(cat /sys/block/"$dev"/size)
    sectorsize=$(cat /sys/block/"$dev"/queue/hw_sector_size)
    gbytes="$((size * sectorsize / 1024 / 1024 / 1024))"
    echo "size:${gbytes}GB;sector_size:$sectorsize"
  done
  # cciss(4) devices
  for dev in $(ls /dev/cciss 2>/dev/null|grep -E 'c[0-9]d[0-9]$'); do
    echo "/dev/cciss/$dev"
    size=$(cat /sys/block/cciss\!"$dev"/size)
    sectorsize=$(cat /sys/block/cciss\!"$dev"/queue/hw_sector_size)
    gbytes="$((size * sectorsize / 1024 / 1024 / 1024))"
    echo "size:${gbytes}GB;sector_size:$sectorsize"
  done
}

# Function to get fs type from configuration if available.
# This ensures that, the user is shown the proper fs type if they install the system.
get_partfs() {
  # Define some variables locally
  local part default fstype

  part="$1"
  default="${2:-none}"
  fstype=$(grep "MOUNTPOINT ${part} " "$CONF_FILE"|awk '{print $3}')

  echo "${fstype:-$default}"
}

# Function show partitions
show_partitions() {
  # Define some variables locally
  local disk fstype fssize p part

  set -- "$(show_disks)"
  while [ $# -ne 0 ]; do
    disk=$(basename "$1")
    shift 2
    # ATA/SCSI/SATA
    for p in /sys/block/"$disk"/$disk*; do
      if [ -d "$p" ]; then
        part=$(basename $p)
        fstype=$(lsblk -nfr /dev/"$part"|awk '{print $2}'|head -1)
        [ "$fstype" = "iso9660" ] && continue
        [ "$fstype" = "crypto_LUKS" ] && continue
        [ "$fstype" = "LVM2_member" ] && continue
        fssize=$(lsblk -nr /dev/"$part"|awk '{print $4}'|head -1)
        echo "/dev/$part"
        echo "size:${fssize:-unknown};fstype:$(get_partfs "/dev/$part")"
      fi
    done
  done
  # Device Mapper
  for p in /dev/mapper/*; do
    part=$(basename "$p")
    [ "${part}" = "live-rw" ] && continue
    [ "${part}" = "live-base" ] && continue
    [ "${part}" = "control" ] && continue

    fstype=$(lsblk -nfr "$p"|awk '{print $2}'|head -1)
    fssize=$(lsblk -nr "$p"|awk '{print $4}'|head -1)
    echo "${p}"
    echo "size:${fssize:-unknown};fstype:$(get_partfs "$p")"
  done
  # Software raid (md)
  for p in $(ls -d /dev/md* 2>/dev/null|grep '[0-9]'); do
    part=$(basename "$p")
    if cat /proc/mdstat|grep -qw "$part"; then
      fstype=$(lsblk -nfr /dev/"$part"|awk '{print $2}')
      [ "$fstype" = "crypto_LUKS" ] && continue
      [ "$fstype" = "LVM2_member" ] && continue
      fssize=$(lsblk -nr /dev/"$part"|awk '{print $4}')
      echo "$p"
      echo "size:${fssize:-unknown};fstype:$(get_partfs "$p")"
    fi
  done
  # cciss(4) devices
  for part in $(ls /dev/cciss 2>/dev/null|grep -E 'c[0-9]d[0-9]p[0-9]+'); do
    fstype=$(lsblk -nfr /dev/cciss/"$part"|awk '{print $2}')
    [ "$fstype" = "crypto_LUKS" ] && continue
    [ "$fstype" = "LVM2_member" ] && continue
    fssize=$(lsblk -nr /dev/cciss/"$part"|awk '{print $4}')
    echo "/dev/cciss/$part"
    echo "size:${fssize:-unknown};fstype:$(get_partfs "/dev/cciss/$part")"
  done
  if [ -e /sbin/lvs ]; then
    # LVM
    lvs --noheadings|while read lvname vgname perms size; do
      echo "/dev/mapper/${vgname}-${lvname}"
      echo "size:${size};fstype:$(get_partfs "/dev/mapper/${vgname}-${lvname}" lvm)"
    done
  fi
}

# Function to chose and set the filesystem used to format the device selected and mount point
menu_filesystems() {
  # Define some variables locally
  local dev fstype fssize mntpoint reformat result

  while true; do
    DIALOG --ok-label "Change" --cancel-label "Done" \
      --title " Select the partition to edit " --menu "$MENULABEL" \
      "${MENUSIZE}" "$(show_partitions)"
    result=$?
    [ "$result" -ne 0 ] && return
    dev=$(cat "$ANSWER")

    DIALOG --title " Select the filesystem type for $dev " \
      --menu "$MENULABEL" "${MENUSIZE}" \
      "btrfs" "Subvolume @,@home,@var_log,@var_lib,@snapshots" \
      "btrfs_lvm" "Subvolume @,@home,@var_log,@var_lib,@snapshots" \
      "btrfs_lvm_crypt" "Subvolume @,@home,@var_log,@var_lib,@snapshots" \
      "ext2" "Linux ext2 (without journal)" \
      "ext3" "Linux ext3 (journal)" \
      "ext4" "Linux ext4 (journal)" \
      "f2fs" "Flash-Friendly Filesystem" \
      "swap" "Linux swap" \
      "vfat" "FAT32" \
      "xfs" "SGI's XFS"
    result=$?
    if [ "$result" -eq 0 ]; then
      fstype=$(cat "$ANSWER")
    else
      continue
    fi
    if [ "$fstype" != "swap" ]; then
      DIALOG --inputbox "Please specify the mount point for $dev:" "${INPUTSIZE}"
      result=$?
      if [ "$result" -eq 0 ]; then
        mntpoint=$(cat "$ANSWER")
      elif [ "$result" -eq 1 ]; then
        continue
      fi
    else
      mntpoint=swap
    fi
    DIALOG --yesno "Do you want to create a new filesystem on $dev?" "${YESNOSIZE}"
    result=$?
    if [ "$result" -eq 0 ]; then
      reformat=1
    elif [ "$result" -eq 1 ]; then
      reformat=0
    else
      continue
    fi
    fssize=$(lsblk -nr "$dev"|awk '{print $4}')
    set -- "$fstype" "$fssize" "$mntpoint" "$reformat"
    if [[ -n "$1" && -n "$2" && -n "$3" && -n "$4" ]]; then
      local bdev ddev
      bdev=$(basename "$dev")
      ddev=$(basename "$(dirname "$dev")")
      if [ "$ddev" != "dev" ]; then
        sed -i -e "/^MOUNTPOINT \/dev\/${ddev}\/${bdev} .*/d" "$CONF_FILE"
      else
        sed -i -e "/^MOUNTPOINT \/dev\/${bdev} .*/d" "$CONF_FILE"
      fi
      echo "MOUNTPOINT $dev $1 $2 $3 $4" >>"$CONF_FILE"
    fi
  done
  FILESYSTEMS_DONE=1
}

# Function for chose partition tool for modify partition table
menu_partitions() {
  # Define some variables locally
  local device software result

  DIALOG --title " Select the disk to partition " \
    --menu "$MENULABEL" "${MENUSIZE}" "$(show_disks)"
  result=$?
  if [ "$result" -eq 0 ]; then
    device=$(cat "$ANSWER")

    DIALOG --title " Select the software for partitioning " \
      --menu "$MENULABEL" "${MENUSIZE}" \
      "cfdisk" "Easy to use" \
      "fdisk" "More advanced"
    result=$?
    if [ "$result" -eq 0 ]; then
      software=$(cat "$ANSWER")

      DIALOG --title "Modify Partition Table on $device" --msgbox "\n
${BOLD}${MAGENTA}${software}${RESET} ${BOLD}will be executed in disk $device.${RESET}\n\n
For BIOS systems, MBR or GPT partition tables are supported. To use GPT\n
on PC BIOS systems, an empty partition of 1MB must be added at the first\n
2GB of the disk with the partition type ${BOLD}${BLUE}'BIOS Boot'${RESET}.\n
${BOLD}${GREEN}NOTE: you don't need this on EFI systems.${RESET}\n\n
For EFI systems, GPT is mandatory and a FAT32 partition with at least 100MB\n
must be created with the partition type ${BOLD}${BLUE}'EFI System'${RESET}. This will be used as\n
the EFI System Partition. This partition must have the mountpoint '/boot/efi'.\n\n
At least 1 partition is required for the rootfs (/). For this partition,\n
at least 12GB is required, but more is recommended. The rootfs partition\n
should have the partition type ${BOLD}${BLUE}'Linux Filesystem'${RESET}. For swap, RAM*2\n
should be enough and the partition type ${BOLD}${BLUE}'Linux swap'${RESET} should be used.\n\n
${BOLD}${RED}WARNING: /usr is not supported as a separate partition.${RESET}\n\n
For ${BOLD}${CYAN}'btrfs'${RESET} option, installer script detect if the used disk is a HDD or
SSD (to prepare mount options) and automatically creates the following subvolumes:\n\n
* @, which will be mounted at /;\n
* @home, which will be mounted at /home;\n
* @var_log, which will be mounted at /var/log;\n
* @var_lib, which will be mounted at /var/lib;\n
* @snapshots, which will be mounted at /.snapshots.\n\n
For ${BOLD}${CYAN}'btrfs_lvm'${RESET} subvolume is created on LVM and for ${BOLD}${CYAN}'btrfs_lvm_crypt'${RESET}
subvolume is also created on LVM but this time device was before crypted.\n\n
${BOLD}${GREEN}INFO: Passphrase used for crypt is the user password.${RESET}\n\n
${BOLD}${RED}WARNING: Also for ${BOLD}${CYAN}'btrfs_lvm'${RESET} ${BOLD}${RED}and ${BOLD}${CYAN}'btrfs_lvm_crypt'${RESET}
${BOLD}${RED}installer created automatically ${BOLD}${BLUE}'Linux swap' ${BOLD}${RED}partition with rule 2*RAM.${RESET}\n\n
${RESET}\n" 23 80
      result=$?
      if [ "$result" -eq 0 ]; then
        while true; do
          clear; "$software" "$device"; PARTITIONS_DONE=1
          break
        done
      else
        return
      fi
    fi
  fi
}

# Function for chose and set keymap
menu_keymap() {
  # Define some variables locally
  local _keymaps _KEYMAPS result
  _keymaps="$(find /usr/share/kbd/keymaps/ -type f -iname "*.map.gz" -printf "%f\n" | sed 's|.map.gz||g' | sort)"
  _KEYMAPS=

  for f in ${_keymaps}; do
    _KEYMAPS="${_KEYMAPS} ${f} -"
  done
  while true; do
    DIALOG --title " Select your keymap " --menu "$MENULABEL" 14 70 14 "${_KEYMAPS}"
    result=$?
    if [ "$result" -eq 0 ]; then
      set_option KEYMAP "$(cat "$ANSWER")"
      loadkeys "$(cat "$ANSWER")"
      KEYBOARD_DONE=1
      break
    else
      return
    fi
  done
}

# Function to set keymap from loaded saved configure file
set_keymap() {
  # Define some variables locally
  local KEYMAP
  KEYMAP=$(get_option KEYMAP)

  if [ -f /etc/vconsole.conf ]; then
    sed -i -e "s|KEYMAP=.*|KEYMAP=$KEYMAP|g" "$TARGETDIR"/etc/vconsole.conf
  else
    sed -i -e "s|#\?KEYMAP=.*|KEYMAP=$KEYMAP|g" "$TARGETDIR"/etc/rc.conf
  fi
}

# Function for chose and set locale
menu_locale() {
  # Define some variables locally
  local _locales LOCALES ISO639 ISO3166 TMPFILE result
  _locales="$(grep -E '\.UTF-8' /etc/default/libc-locales|awk '{print $1}'|sed -e 's/^#//')"
  TMPFILE=$(mktemp -t vinstall-XXXXXXXX || exit 1)

  INFOBOX "Scanning locales ..." 4 60
  for f in ${_locales}; do
    eval "$(echo "$f" | awk 'BEGIN { FS="." } \
            { FS="_"; split($1, a); printf "ISO639=%s ISO3166=%s\n", a[1], a[2] }')"
    echo "$f|$(iso639_language "$ISO639") ($(iso3166_country "$ISO3166"))|" >> "$TMPFILE"
  done
  clear
  # Sort by ISO-639 language names
  LOCALES=$(sort -t '|' -k 2 < "$TMPFILE" | xargs | sed -e's/| /|/g')
  rm -f "$TMPFILE"
  while true; do
    (IFS="|"; DIALOG --title " Select your locale " --menu "$MENULABEL" 18 70 18 "${LOCALES}")
    result=$?
    if [ "$result" -eq 0 ]; then
      set_option LOCALE "$(cat "$ANSWER")"
      LOCALE_DONE=1
      break
    else
      return
    fi
  done
}

# # Function to set locale from loaded saved configure file
set_locale() {
  # Define some variables locally
  local LOCALE

  if [ -f "$TARGETDIR"/etc/default/libc-locales ]; then
    LOCALE="$(get_option LOCALE)"
    : "${LOCALE:=C.UTF-8}"
    sed -i -e "s|LANG=.*|LANG=$LOCALE|g" "$TARGETDIR"/etc/locale.conf
    # Uncomment locale from /etc/default/libc-locales and regenerate it.
    sed -e "/${LOCALE}/s/^\#//" -i "$TARGETDIR"/etc/default/libc-locales
    echo "Running xbps-reconfigure -f glibc-locales ..." >>"$LOG"
    chroot "$TARGETDIR" xbps-reconfigure -f glibc-locales >>"$LOG" 2>&1
  fi
}

# Function to chose and set timezone
menu_timezone() {
  # Define some variables locally
  local areas area locations location
  areas=(Africa America Antarctica Arctic Asia Atlantic Australia Europe Indian Pacific)

  while (IFS='|'; DIALOG ${area:+--default-item|"$area"} --title " Select area " --menu "$MENULABEL" 19 51 19 "$(printf '%s||' "${areas[@]}")"); do
    area=$(cat "$ANSWER")
    read -a locations -d '\n' < <(find /usr/share/zoneinfo/"$area" -type f -printf '%P\n' | sort)
    if (IFS='|'; DIALOG --title " Select location (${area}) " --menu "$MENULABEL" 19 51 19 "$(printf '%s||' "${locations[@]//_/ }")"); then
      location=$(tr ' ' '_' < "$ANSWER")
      set_option TIMEZONE "$area/$location"
      TIMEZONE_DONE=1
      return 0
    else
      continue
    fi
  done
  return 1
}

# Function to set timezone from loaded saved configure file
set_timezone() {
  # Define some variables locally
  local TIMEZONE
  TIMEZONE="$(get_option TIMEZONE)"

  ln -sf "/usr/share/zoneinfo/${TIMEZONE}" "${TARGETDIR}/etc/localtime"
}

# Function to set hostname
menu_hostname() {
  # Define some variables locally
  local result

  while true; do
    DIALOG --inputbox "Set the machine hostname:" "${INPUTSIZE}"
    result=$?
    if [ "$result" -eq 0 ]; then
      set_option HOSTNAME "$(cat "$ANSWER")"
      HOSTNAME_DONE=1
      break
    else
      return
    fi
  done
}

# Function to set hostname from loaded saved configure file
set_hostname() {
  # Define some variables locally
  local hostname

  hostname="$(get_option HOSTNAME)"
  echo "${hostname:-void}" > "$TARGETDIR"/etc/hostname
}

# Function to set password for root
menu_rootpassword() {
  # Define some variables locally
  local _firstpass _secondpass _again _desc result

  while true; do
    if [ -z "${_firstpass}" ]; then
      _desc="Enter the root password"
    else
      _again=" again"
    fi
    DIALOG --insecure --passwordbox "${_desc}${_again}" "${INPUTSIZE}"
    result=$?
    if [ "$result" -eq 0 ]; then
      if [ -z "${_firstpass}" ]; then
        _firstpass="$(cat $ANSWER)"
      else
        _secondpass="$(cat $ANSWER)"
      fi
      if [ -n "${_firstpass}" ] && [ -n "${_secondpass}" ]; then
        if [ "${_firstpass}" != "${_secondpass}" ]; then
          INFOBOX "Passwords do not match! Please enter again." 6 60
          unset _firstpass _secondpass _again
          sleep 2 && clear && continue
        fi
        set_option ROOTPASSWORD "${_firstpass}"
        ROOTPASSWORD_DONE=1
        break
      fi
    else
      return
    fi
  done
}

# Function to set password for root from loaded saved configure file
set_rootpassword() {
  echo "root:$(get_option ROOTPASSWORD)" | chroot "$TARGETDIR" chpasswd -c SHA512
}

# Function to set user account
menu_useraccount() {
  # Define some variables locally
  local _firstpass _secondpass _desc _again
  local _groups _status _group _gid _checklist
  local _preset _userlogin result

  while true; do
    _preset=$(get_option USERLOGIN)
    [ -z "$_preset" ] && _preset="brgvos"
    DIALOG --inputbox "Enter a primary login name:" "${INPUTSIZE}" "$_preset"
    result=$?
    if [ "$result" -eq 0 ]; then
      _userlogin="$(cat "$ANSWER")"
      # based on useradd(8) § Caveats
      if [ "${#_userlogin}" -le 32 ] && [[ "${_userlogin}" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
        set_option USERLOGIN "${_userlogin}"
        USERLOGIN_DONE=1
        break
      else
        INFOBOX "Invalid login name! Please try again." 6 60
        unset _userlogin
        sleep 2 && clear && continue
      fi
    else
      return
    fi
  done

  while true; do
    _preset=$(get_option USERNAME)
    [ -z "$_preset" ] && _preset="User Name"
    DIALOG --inputbox "Enter a display name for login '$(get_option USERLOGIN)' :" \
      "${INPUTSIZE}" "$_preset"
    result=$?
    if [ "$result" -eq 0 ]; then
      set_option USERNAME "$(cat "$ANSWER")"
      USERNAME_DONE=1
      break
    else
      return
    fi
  done

  while true; do
    if [ -z "${_firstpass}" ]; then
      _desc="Enter the password for login '$(get_option USERLOGIN)'"
    else
      _again=" again"
    fi
    DIALOG --insecure --passwordbox "${_desc}${_again}" "${INPUTSIZE}"
    result=$?
    if [ "$result" -eq 0 ]; then
      if [ -z "${_firstpass}" ]; then
        _firstpass="$(cat "$ANSWER")"
      else
        _secondpass="$(cat "$ANSWER")"
      fi
      if [ -n "${_firstpass}" ] && [ -n "${_secondpass}" ]; then
        if [ "${_firstpass}" != "${_secondpass}" ]; then
          INFOBOX "Passwords do not match! Please enter again." 6 60
          unset _firstpass _secondpass _again
          sleep 2 && clear && continue
        fi
        set_option USERPASSWORD "${_firstpass}"
        USERPASSWORD_DONE=1
        break
      fi
    else
      return
    fi
  done

  _groups="wheel,audio,video,floppy,cdrom,optical,kvm,users,xbuilder"
  while true; do
    _desc="Select group membership for login '$(get_option USERLOGIN)':"
    for _group in $(cat /etc/group); do
      _gid="$(echo "${_group}" | cut -d: -f3)"
      _group="$(echo "${_group}" | cut -d: -f1)"
      _status="$(echo "${_groups}" | grep -w "${_group}")"
      if [ -z "${_status}" ]; then
        _status=off
      else
        _status=on
      fi
      # ignore the groups of root, existing users, and package groups
      if [[ "${_gid}" -ge 1000 || "${_group}" = "_"* || "${_group}" =~ ^(root|nogroup|chrony|dbus|lightdm|polkitd)$ ]]; then
        continue
      fi
      if [ -z "${_checklist}" ]; then
        _checklist="${_group} ${_group}:${_gid} ${_status}"
      else
        _checklist="${_checklist} ${_group} ${_group}:${_gid} ${_status}"
      fi
    done
    DIALOG --no-tags --checklist "${_desc}" 20 60 18 "${_checklist}"
    if [ $? -eq 0 ]; then
      set_option USERGROUPS "$(cat "$ANSWER" | sed -e's| |,|g')"
      USERGROUPS_DONE=1
      break
    else
      return
    fi
  done
}

# Function to set user account from loaded saved configure file
set_useraccount() {
  [ -z "$USERACCOUNT_DONE" ] && return
  chroot "$TARGETDIR" useradd -m -G "$(get_option USERGROUPS)" \
    -c "$(get_option USERNAME)" "$(get_option USERLOGIN)"
  echo "$(get_option USERLOGIN):$(get_option USERPASSWORD)" | \
    chroot "$TARGETDIR" chpasswd -c SHA512
}

# Function to set bootloader
menu_bootloader() {
  # Define some variables locally
  local result

  while true; do
    DIALOG --title " Select the disk to install the bootloader" \
      --menu "$MENULABEL" "${MENUSIZE}" "$(show_disks)" none "Manage bootloader otherwise"
    result=$?
    if [ "$result" -eq 0 ]; then
      set_option BOOTLOADER "$(cat "$ANSWER")"
      BOOTLOADER_DONE=1
      break
    else
      return
    fi
  done
  while true; do
    DIALOG --yesno "Use a graphical terminal for the boot loader?" "${YESNOSIZE}"
    result=$?
    if [ "$result" -eq 0 ]; then
      set_option TEXTCONSOLE 0
      break
    elif [ "$result" -eq 1 ]; then
      set_option TEXTCONSOLE 1
      break
    else
      return
    fi
  done
}

# Function to set boot loader from loaded saved configure file
set_bootloader() {
  # Define some variables locally
  local dev grub_args CRYPT_UUID result bool
  dev=$(get_option BOOTLOADER)
  grub_args=

  if [ "$dev" = "none" ]; then return; fi

  # Check if it's an EFI system via efivars module.
  if [ -n "$EFI_SYSTEM" ]; then
    grub_args="--target=$EFI_TARGET --efi-directory=/boot/efi --bootloader-id=brgvos_grub --recheck"
  fi
  echo "Running grub-install $grub_args $dev..." >>"$LOG"
  # Check if root file system was crypted and add option in grub config
  $(cryptsetup isLuks "$ROOTFS") && bool=1 || bool=0
  echo "Check if root file system was crypted and add option in grub config" >>"$LOG"
  if [ "$bool" -eq 1 ]; then
    echo "Detected crypted device on $ROOTFS"  >>"$LOG"
    CRYPT_UUID=$(blkid -s UUID -o value "$ROOTFS")
    chroot "$TARGETDIR" dd bs=512 count=4 if=/dev/urandom of=/boot/cryptlvm.key >>"$LOG" 2>&1
    echo -n "$PASSPHRASE" | cryptsetup luksAddKey "$ROOTFS" "$TARGETDIR"/boot/cryptlvm.key >>"$LOG" 2>&1
    chroot "$TARGETDIR" chmod 0600 /boot/cryptlvm.key >>"$LOG" 2>&1
    awk 'BEGIN{print "crypt UUID='"$CRYPT_UUID"' /boot/cryptlvm.key luks"}' >> "$TARGETDIR"/etc/crypttab
    chroot "$TARGETDIR" touch /etc/dracut.conf.d/10-crypt.conf >>"$LOG" 2>&1
    awk 'BEGIN{print "install_items+=\" /boot/cryptlvm.key /etc/crypttab \""}' >> "$TARGETDIR"/etc/dracut.conf.d/10-crypt.conf
    echo "Generate again initramfs because was created a key for open crypted device $ROOTFS" >>"$LOG"
    chroot "$TARGETDIR" dracut --no-hostonly --force >>"$LOG" 2>&1
    echo "Enable cryptodisk option in grub config" >>"$LOG"
    chroot "$TARGETDIR" sed -i '$aGRUB_ENABLE_CRYPTODISK=y' /etc/default/grub >>"$LOG" 2>&1
  else
    echo "Device $ROOTFS is not crypted"  >>"$LOG"
  fi
  # Install grub
  chroot "$TARGETDIR" grub-install "$grub_args" "$dev" >>"$LOG" 2>&1
  result=$?
  if [ "$result" -ne 0 ]; then
    DIALOG --msgbox "${BOLD}${RED}ERROR:${RESET} \
failed to install GRUB to $dev!\nCheck $LOG for errors." "${MSGBOXSIZE}"
    DIE 1
  fi
  echo "Preparing the Logo and name in the grub menu $TARGETDIR..." >>"$LOG"
  chroot "$TARGETDIR" sed -i 's+#GRUB_BACKGROUND=/usr/share/void-artwork/splash.png+GRUB_BACKGROUND=/usr/share/brgvos-artwork/splash.png+g' /etc/default/grub >>"$LOG" 2>&1
  chroot "$TARGETDIR" sed -i 's/GRUB_DISTRIBUTOR="Void"/GRUB_DISTRIBUTOR="BRGV-OS"/g' /etc/default/grub >>"$LOG" 2>&1
  if [ "$bool" -eq 1 ]; then
    echo "Prepare parameters on Grub for crypted device $ROOTFS"  >>"$LOG"
    chroot "$TARGETDIR" sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 rd.auto=1 cryptkey=rootfs:\/boot\/cryptlvm.key quiet splash"/g' /etc/default/grub >>"$LOG" 2>&1
  else
    echo "Prepare parameters on Grub for device $ROOTFS"  >>"$LOG"
    chroot "$TARGETDIR" sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 quiet splash"/g' /etc/default/grub >>"$LOG" 2>&1
  fi
  chroot "$TARGETDIR" sed -i '$aGRUB_DISABLE_OS_PROBER=false' /etc/default/grub >>"$LOG" 2>&1
  echo "Running grub-mkconfig on $TARGETDIR..." >>"$LOG"
  chroot "$TARGETDIR" grub-mkconfig -o /boot/grub/grub.cfg >>"$LOG" 2>&1
  result=$?
  if [ "$result" -ne 0 ]; then
    DIALOG --msgbox "${BOLD}${RED}ERROR${RESET}: \
failed to run grub-mkconfig!\nCheck $LOG for errors." "${MSGBOXSIZE}"
    DIE 1
  fi
}

# Function to test network connection
test_network() {
  # Define some variables locally
  local status
  # Reset the global variable to ensure that network is accessible for this test.
  NETWORK_DONE=

  rm -f otime && \
    xbps-uhelper fetch https://repo-default.voidlinux.org/current/otime >>"$LOG" 2>&1
  status=$?
  rm -f otime
  if [ "$status" -eq 0 ]; then
    DIALOG --msgbox "Network is working properly!" "${MSGBOXSIZE}"
    NETWORK_DONE=1
    return 1
  fi
  if [ "$1" = "nm" ]; then
    DIALOG --msgbox "Network Manager is enabled but network is inaccessible, please set it up
    externally with nmcli, nmtui, or the Network Manager tray applet." "${MSGBOXSIZE}"
  else
    DIALOG --msgbox "Network is inaccessible, please set it up properly." "${MSGBOXSIZE}"
  fi
}
