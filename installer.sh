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

# Next function is used for clean exit from script
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

# Next function is used to save chosen options in config file
set_option() {
  if grep -Eq "^${1} .*" "$CONF_FILE"; then
    sed -i -e "/^${1} .*/d" "$CONF_FILE"
  fi
  echo "${1} ${2}" >>"$CONF_FILE"
}

# Next function is used to load saved chosen options from config file
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

# Next function display the disc(s) size in GB and sector size from system
show_disks() {
  # Set local some variables
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