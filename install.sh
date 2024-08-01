#!/bin/bash

# colors
W="\e[0;39m"
R="\e[1;31m"
G="\e[1;32m"
Y="\e[1;33m"
dim="\e[2m"
undim="\e[0m"

repo_update=0

do_repo_update() {
  sudo apt update
  repo_update=1
}

install_if_not_exist() {
  if ! dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; then
    message="$R'$1' is not installed. Installing it now...$W"
    echo -e >&2 "$message"
    if [ "$repo_update" -eq 0 ]; then
      do_repo_update
    fi
    sudo apt install -y "$1"
  else
    success_message="$G'$1' is installed!$W"
    echo -e "$success_message"
  fi
}

run_if_not_active() {
  if ! systemctl is-active --quiet "$1"; then
    echo -e "$Y'$1' is not active. Starting it now...$W"
    sudo systemctl start "$1"
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
    sudo systemctl enable "$1"
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
  sudo chmod 755 ./dist/$1
  sudo rm -f /etc/profile.d/$1 2>/dev/null
  sudo cp ./dist/$1 /etc/profile.d/
}
install_script_config() {
  sudo chmod 755 $1
  sudo rm -f /etc/profile.d/$1 2>/dev/null
  sudo rm -f /etc/profile.d/${1}.sh 2>/dev/null
  sudo cp $1 /etc/profile.d/${1}.sh
}
link_to_bin() {
  sudo rm -f /usr/local/bin/$2 2>/dev/null
  sudo ln -s /etc/profile.d/$1 /usr/local/bin/$2
}
add_to_bin() {
  sudo chmod 755 ./dist/$1
  sudo rm -f /usr/local/bin/$1 2>/dev/null
  sudo cp ./dist/$1 /usr/local/bin/$1
}

create_if_not_exist() {
  if [ ! -e "$1" ]; then
    sudo touch "$1"
  fi
}
cp_if_not_exists() {
  if [ ! -e "$2" ]; then
    sudo cp "$1" "$2"
  fi
}

copy_nft() {
  sudo cp "./dist/zn-nft-base.nft" "/etc/nftables.conf"
  nftd_path="/etc/nftables.d"
  mkdir -p $nftd_path
  sudo cp "./dist/zn-nft-define.nft" "${nftd_path}/"
  sudo cp "./dist/zn-nft-input.nft" "${nftd_path}/"
  sudo cp "./dist/zn-nft-sets.nft" "${nftd_path}/"
  create_if_not_exist "${nftd_path}/custom-define.nft"
  cp_if_not_exists "${nftd_path}/custom-input.nft" "./dist/custom-input.nft"
  create_if_not_exist "${nftd_path}/custom-sets.nft"
}

initial_nftables() {
  mkdir -p ~/.backup
  timestamp=$(date +'%Y%m%d_%H%M')
  sudo cp "/etc/nftables.conf" "${HOME}/.backup/nftables_${timestamp}.conf"
  copy_nft
}
install_if_not_exist sysstat
run_if_not_active sysstat
enable_if_not_enabled sysstat

install_script zn-motd.sh
link_to_bin zn-motd.sh motd
add_to_bin zn-linux
install_script zn-init.sh

if [ -e zn-config ]; then
  install_script_config zn-config
fi

if command -v nft >/dev/null 2>&1; then
  initial_nftables
fi