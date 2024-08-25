#!/bin/bash

atsvc_keywords=("getty|ifup|lvm2|systemd-|user-")
svc_keywords=("apparmor" "apport" "apt-" "arp-" "auditd" "blk-availability" "bolt" "cgroupfs-mount" "chrony" "cloud-" "console-" "containerd" "cpupower" "cron" "cryptdisks" "dbus" "debug-shell" "dmesg" "dm-event" "dnf-" "dpkg" "dracut-" "e2scrub" "emergency" "esm-cache" "finalrd" "friendly-recovery" "fstrim" "fwupd" "getty-" "gpu-manager" "grub-" "grub2-" "hwclock" "ifup" "initrd-" "irqbalance" "iscsi" "kdump" "keyboard-setup" "kmod" "kvm_" "ldconfig" "logrotate" "lvm2" "lxd-agent" "man-db" "mdcheck" "mdmonitor" "microcode" "ModemManager" "motd-news" "multipath-" "multipathd" "netplan-ovs-cleanup" "networkd-dispatcher" "networking" "NetworkManager" "nis-" "nm-" "open-iscsi" "packagekit" "pam_namespace" "phpsessionclean" "plymouth" "polkit" "pollinate" "procps" "quotaon" "raid-" "rc.service" "rc-local" "rcS.service" "rdisc" "rescue.service" "rpmdb-" "rsync" "screen-cleanup" "secureboot-db" "selinux-" "setvtrgb" "snap" "snmpd" "ssh" "sssd" "sudo" "systemd-" "system-update-cleanup" "thermald" "ua-reboot-cmds" "ua-timer" "ubuntu-advantage" "udev" "udisks2" "unattended-upgrades" "update-notifier-download" "update-notifier-motd" "upower" "usbmuxd" "uuidd" "vgauth" "x11-common" "xfs_scrub_all")
# colors
W="\e[0;39m"
R="\e[1;31m"
G="\e[1;32m"
Y="\e[1;33m"
dim="\e[2m"
undim="\e[0m"

repo_update=0

command -v apt >/dev/null 2>&1 && alias apt='sudo apt -y'
command -v yum >/dev/null 2>&1 && alias apt='sudo yum -y'
command -v cp >/dev/null 2>&1 && alias cp='sudo cp -f'
command -v mv >/dev/null 2>&1 && alias mv='sudo mv -f'
command -v rm >/dev/null 2>&1 && alias rm='sudo rm -f'
command -v mkdir >/dev/null 2>&1 && alias mkdir='sudo mkdir'
command -v chmod >/dev/null 2>&1 && alias chmod='sudo chmod'
command -v ln >/dev/null 2>&1 && alias ln='sudo ln'
command -v touch >/dev/null 2>&1 && alias touch='sudo touch'
command -v systemctl >/dev/null 2>&1 && alias systemctl='sudo systemctl'


copy_if_updated() {
  timestamp=$(date +'%Y%m%d_%H%M')
  src=$1
  dst=$2
  fid=$3
  sha1_src=$(sha1sum $(realpath -m $src) | awk '{print $1}')
  dst_dir=$(dirname $(realpath -m $dst))
  dst_f=$(basename "$dst" | cut -d. -f1)
  dst_ext=".${dst##*.}"

  if [ -e $dst ]; then
    sha1_dst=$(sha1sum $(realpath -m $dst) | awk '{print $1}')
    if [ "$sha1_src" = "$sha1_dst" ]; then
      echo -e "${fid}: File is up-to-date."
    else
      dst_backup="${HOME}/.backup${dst_dir}/${dst_f}_${timestamp}${dst_ext}"
      mkdir -p ~/.backup/${dst_dir}
      cp "$dst" "$dst_backup"
      echo -e "${fid}: Backup created at ${dst_backup}"
      cp $src $dst
    fi
  else
    cp $src $dst
  fi
}


do_repo_update() {
  if [ -f /etc/debian_version ]; then
    apt update
  elif [ -f /etc/redhat-release ]; then
    yum makecache
  fi

  repo_update=1
}

install_if_not_exist() {
  is_installed=0

  if [ -f /etc/debian_version ]; then
    if dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; then
      is_installed=1
    fi
  elif [ -f /etc/redhat-release ]; then
    if rpm -q "$1" >/dev/null 2>&1; then
      is_installed=1
    fi
  fi
  if [ "$is_installed" -eq 0 ]; then
    message="$R'$1' is not installed. Installing it now...$W"
    echo -e >&2 "$message"
    if [ "$repo_update" -eq 0 ]; then
      do_repo_update
    fi
    
    if [ -f /etc/debian_version ]; then
      apt install "$1"
    elif [ -f /etc/redhat-release ]; then
      yum install "$1"
    fi
  else
    success_message="$G'$1' is installed! $W"
    echo -e "$success_message"
  fi
}

run_if_not_active() {
  if ! systemctl is-active --quiet "$1"; then
    echo -e "$Y'$1' is not active. Starting it now...$W"
    systemctl start "$1"
    if [ $? -eq 0 ]; then
      echo -e "$G'$1' started successfully!$W"
    else
      echo -e "$RFailed to start '$1'.$W"
    fi
  else
    echo -e "$G'$1' is already active.$W"
  fi
}

enable_if_not_enabled() {
  if ! systemctl is-enabled --quiet "$1"; then
    echo -e "$Y'$1' is not enabled. Enabling it now...$W"
    systemctl enable "$1"
    if [ $? -eq 0 ]; then
      echo -e "$G'$1' enabled successfully!$W"
    else
      echo -e "$RFailed to enable '$1'.$W"
    fi
  else
    echo -e "$G'$1' is already enabled.$W"
  fi
}

install_script() {
  chmod 755 ./dist/$1
  rm /etc/profile.d/$1 >/dev/null 2>&1
  cp ./dist/$1 /etc/profile.d/
}
install_script_config() {
  chmod 644 $1
  rm /etc/profile.d/$1 >/dev/null 2>&1
  rm /etc/profile.d/${1}.sh >/dev/null 2>&1
  cp $1 /etc/profile.d/${1}.sh
}
link_to_bin() {
  rm /usr/local/bin/$2 >/dev/null 2>&1
  rm /usr/bin/$2 >/dev/null 2>&1
  ln -s /etc/profile.d/$1 /usr/bin/$2
}
add_to_bin() {
  chmod 755 ./dist/$1
  rm /usr/local/bin/$1 >/dev/null 2>&1
  rm /usr/bin/$1 >/dev/null 2>&1
  cp ./dist/$1 /usr/bin/$1
}

create_if_not_exist() {
  if [ ! -e "$1" ]; then
    touch "$1"
  fi
}
cp_if_not_exists() {
  if [ ! -e "$2" ]; then
    cp "$1" "$2"
  fi
}

clean_old_motd() {
  mkdir -p ~/.backup/etc/update-motd.d/
  if [ -e "/etc/update-motd.d/" ]; then
    mv /etc/update-motd.d/* ~/.backup/etc/update-motd.d/ >/dev/null 2>&1
  fi
  if [ ! -e ~/.backup/etc/motd ]; then
    mv /etc/motd ~/.backup/etc/ >/dev/null 2>&1
    touch /etc/motd
  fi
  rm /usr/local/bin/znver >/dev/null 2>&1
  rm /usr/local/bin/zn-linux >/dev/null 2>&1
  rm /usr/local/bin/motd >/dev/null 2>&1
}

omit_svc() {
  check_svc=$(echo -e "$all_svc" | grep -E "^($1)")
  if [[ -n "$check_svc" ]]; then
    common_svc+="${2}|"
    if [[ -n "$3" ]]; then
      custom_svc+="arkimecapture,arkimeviewer"
    fi
  fi
}

create_common_svc() {
  common_svc=""
  custom_svc=""
  all_svc=$(systemctl list-unit-files --type=service --no-pager --no-legend | grep -vE "(@)")
  check_mariadb=$(echo -e "$all_svc" | grep -E "^(mariadb)")
  check_mysql=$(echo -e "$all_svc" | grep -E "^(mysql)")
  if [[ -n "$check_mariadb" ]]; then
    common_svc+="mysql|"
  elif [[ -n "$check_mysql" ]]; then
    common_svc+="mysqld|"
  fi
  
  omit_svc "qemu-guest-agent" "open-vm-tools|vmtoolsd"
  omit_svc "open-vm-tools" "vmtoolsd"
  omit_svc "arkime" "arkime" "arkimecapture,arkimeviewer"
  
  for svc_keyword in "${svc_keywords[@]}"
  do
    check_svc=$(echo -e "$all_svc" | grep -E "^($svc_keyword)")
    if [[ -n "$check_svc" ]]; then
      common_svc+="${svc_keyword}|"
    fi
  done
  
  if [ -n "$custom_svc" ]; then
    custom_svc="${custom_svc%,}"
    sed -i 's/custom_svc=""/custom_svc="'$custom_svc'"/' /etc/profile.d/zn-motd.sh
  fi
  
  common_svc="${common_svc%|}"
  sed -i 's/common_svc=""/common_svc="'$common_svc'"/' /etc/profile.d/zn-motd.sh

  common_atsvc=""
  all_atsvc=$(systemctl list-units --type=service --state=active --no-pager --no-legend | awk '{print $1}' | grep "@")
  for atsvc_keyword in "${atsvc_keywords[@]}"
  do
    check_atsvc=$(echo -e "$all_atsvc" | grep -E "^($atsvc_keyword)")
    if [[ -n "$check_atsvc" ]]; then
      common_atsvc+="${atsvc_keyword}|"
    fi
  done

  common_atsvc="${common_atsvc%|}"
  sed -i 's/common_atsvc=""/common_atsvc="'$common_atsvc'"/' /etc/profile.d/zn-motd.sh
}

initial_nftables() {
  sysconfig_nft="/etc/sysconfig/nftables.conf"
  etc_nft="/etc/nftables.conf"
  is_sysconfig_nft=0
  if [ -e "$sysconfig_nft" ]; then
    is_sysconfig_nft=1
    if ! [ -L "$sysconfig_nft" ]; then
      cp "$sysconfig_nft" "$etc_nft"
    fi
  fi
  copy_if_updated "./dist/zn-nft-base.nft" "$etc_nft" "Nftables"
  if [ "$is_sysconfig_nft" -eq 1 ]; then
    rm "$sysconfig_nft" >/dev/null 2>&1
    ln -s "$etc_nft" "$sysconfig_nft"
  fi

  nftd_path="/etc/nftables.d"
  mkdir -p $nftd_path
  cp "./dist/zn-nft-define.nft" "${nftd_path}/"
  cp "./dist/zn-nft-input.nft" "${nftd_path}/"
  cp "./dist/zn-nft-sets.nft" "${nftd_path}/"
  create_if_not_exist "${nftd_path}/custom-define.nft"
  cp_if_not_exists "./dist/custom-input.nft" "${nftd_path}/custom-input.nft"
  create_if_not_exist "${nftd_path}/custom-sets.nft"
}

main() {
  install_if_not_exist sysstat
  run_if_not_active sysstat
  enable_if_not_enabled sysstat

  install_script zn-motd.sh
  link_to_bin zn-motd.sh motd
  create_common_svc
  add_to_bin zn-linux
  install_script zn-init.sh

  if command -v nft >/dev/null 2>&1; then
    initial_nftables
  fi

  clean_old_motd

  if [ -e ./zn-config ]; then
    install_script_config zn-config
    source ./zn-config
    source ./dist/zn-init.sh
  fi
}

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    missing_command+=("$1")
  fi
}

prereq_test_os() {
  os_supported=0
  if [ -f /etc/debian_version ]; then
    os_supported=1
  elif [ -f /etc/redhat-release ]; then
    os_supported=1
  else
    echo -e "${R}Error: OS not supported.${W}"
  fi

  if [ "$os_supported" -eq 1 ]; then
    main
  fi
}

prereq_test() {
  req_commands=(
    "date"
    "cp" "mv" "rm" "ln"
    "dirname" "realpath" "basename" "mkdir" "touch"
    "cut" "awk" "sed" "grep"
    "echo" "printf" "cat"
    "sudo" "systemctl" "source"
    "sha1sum"
    "free" "df" "uname" "uptime"
  )

  missing_command=()
  for cmd in "${req_commands[@]}"; do
    check_command $cmd
  done

  if [ ${#missing_command[@]} -ne 0 ]; then
    echo -e "${R}Error: Prerequisite unsatisfied.${W} Missing commands: ${missing_command[*]}"
  else
    prereq_test_os
  fi
}

prereq_test