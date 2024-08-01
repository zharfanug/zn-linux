#!/bin/bash
export motd_ver=2.0.15

if [ -f /etc/lsb-release ]; then
  osver=$(cat /etc/lsb-release | grep "DISTRIB_RELEASE" | cut -d "=" -f 2- | sed 's/"//g')
  os_services="auditd|apparmor|apport|apt-|blk-availability|bolt|cloud-config|cloud-final|cloud-init|console-|cron|cryptdisks|dbus|debug-shell|dm-event|dmesg|dpkg|e2scrub|emergency|esm-cache|finalrd|friendly-recovery|fstrim|fwupd|getty-|gpu-manager|grub-|hwclock|initrd-|irqbalance|iscsi|keyboard-setup|kmod|logrotate|lvm2|lxd-agent|man-db|mdcheck|mdmonitor|ModemManager|motd-news|multipath-|multipathd|netplan-ovs-cleanup|networkd-dispatcher|open-iscsi|packagekit|plymouth|polkit|pollinate|procps|quotaon|rc-local|rc.service|rcS.service|rescue.service|rsync|screen-cleanup|secureboot-db|setvtrgb|snap|snmpd|ssh|sudo|system-update-cleanup|systemd-|thermald|ua-reboot-cmds|ua-timer|ubuntu-advantage|udev|udisks2|unattended-upgrades|update-notifier-download|update-notifier-motd|upower|usbmuxd|uuidd|vgauth|vmtoolsd|x11-common|xfs_scrub_all"
elif [ -f /etc/debian_version ]; then
  osver=$(cat /etc/debian_version)
  os_services="auditd|apparmor|apt-|blk-availability|console-|cron|cryptdisks|dbus|debug-shell|dm-event|dpkg|e2scrub|emergency|fstrim|getty-|hwclock|ifup|initrd-|keyboard-setup|kmod|logrotate|lvm2|man-db|networking|pam_namespace|procps|quotaon|rc-local|rc.service|rcS.service|rescue.service|rsync|ssh|sudo|system-update-cleanup|systemd-|udev|vgauth|vmtoolsd|x11-common"
elif [ -f /etc/redhat-release ]; then
  osver=$(cat /etc/redhat-release)
elif [ -f /etc/SuSE-release ]; then
  osver=$(cat /etc/SuSE-release)
elif [ -f /etc/arch-release ]; then
  osver=$(cat /etc/arch-release)
else
  osver=$(uname -r)
fi

# config
services_pattern="sysstat-"
services_pattern+="|${os_services}"
if [[ -n "${excluded_services}" ]]; then
  services_pattern+="|${excluded_services}"
fi

max_usage=85
warn_usage=50

cs=12
# colors
W="\e[0;39m"
R="\e[1;31m"
G="\e[1;32m"
Y="\e[1;33m"
dim="\e[2m"
undim="\e[0m"

print_usage() {
  usage_used=$2
  usage_used_h=$3
  usage_total=$4
  usage_total_h=$5
  usage_used_ratio=$(( usage_used * 10000 / usage_total ))
  if (( usage_used_ratio < 10 )); then
    usage_used_ratio="0$usage_used_ratio"
  fi
  usage_used_percent="${usage_used_ratio%??}.${usage_used_ratio: -2}"
  if (( usage_used_ratio < 100 )); then
    usage_used_percent="0$usage_used_percent"
  fi
  if (( usage_used_ratio <= (warn_usage * 100) )); then
    usage_color=$G
  elif (( usage_used_ratio <= (max_usage * 100) )); then
    usage_color=$Y
  else
    usage_color=$R
  fi
  
  if [[ "${1}" == "Memory" ]]; then
    printf "${W}  %-*s: ${usage_color}${usage_used_percent}%%${W} (${usage_color}${usage_used_h}${W} / ${usage_total_h})\n" "$cs" "${1}"
  elif [[ "${1}" == "DiskRoot" ]]; then
    printf "${W}  %-*s: ${usage_color}${usage_used_percent}%%${W} (${usage_color}${usage_used_h}${W} / ${usage_total_h}) (/)\n" "$cs" "Disk"
  elif [[ "${1}" == "DiskOther" ]]; then
    padding=$(printf "%*s" $(($cs + 3)) "") # +2 for ": "
    printf "${W}%s ${usage_color}${usage_used_percent}%%${W} (${usage_color}${usage_used_h}${W} / ${usage_total_h}) (${6})\n" "$padding"
  fi
}

print_motd() {
  services=($(systemctl list-unit-files --type=service --no-pager | grep -vE "(@)" | grep -vE "^(${services_pattern})" | awk '/\.service/ {print substr($1, 1, length($1)-8)}'))

  # get processors
  PROCESSOR_COUNT=`grep -ioP 'processor\t:' /proc/cpuinfo | wc -l`

  echo -e "${W}System Info:"
  printf "${W}  %-*s: %s\n" "$cs" "OS Name" "$(cat /etc/*release | grep "PRETTY_NAME" | cut -d "=" -f 2- | sed 's/"//g')"
  printf "${W}  %-*s: %s\n" "$cs" "OS Version" "$osver"
  printf "${W}  %-*s: %s\n" "$cs" "Kernel" "$(uname -sr)"
  printf "${W}  %-*s: %s\n" "$cs" "Uptime" "$(uptime -p | cut -d ' ' -f 2-)"

  ips=$(ip a | awk '/inet / && /global/ {split($2, arr, /\//); print arr[1] " " $NF}')

  first=true
  while read -r line; do
    ip=$(echo $line | awk '{print $1}')
    interface=$(echo $line | awk '{print $2}')
    if $first; then
      printf "${W}  %-*s: %s\n" "$cs" "IP" "$ip ($interface)"
      first=false
    else
      padding=$(printf "%*s" $(($cs + 3)) "") # +2 for ": "
      printf "%s %s (%s)\n" "$padding" "$ip" "$interface"
    fi
  done <<< "$ips"

  ip_v4=$(curl -s ifconfig.me/ip)
  printf "${W}  %-*s: %s\n" "$cs" "Public IP" "$ip_v4"

  echo -e "\n${W}Resources Usage:"

  # Fetch CPU Usage
  cpu_idle=$(mpstat 1 1 | awk '/Average:/ {print $NF}')
  cpu_idle=${cpu_idle//./}
  cpu_used_ratio=$((10000 - $cpu_idle))
  cpu_used_percent="${cpu_used_ratio%??}.${cpu_used_ratio: -2}"
  if (( cpu_idle == 10000 )); then
    cpu_used_percent="0.00"
  elif (( cpu_used_ratio < 100 )); then
    cpu_used_percent="0$cpu_used_percent"
  fi

  if (( cpu_used_ratio <= (warn_usage * 100) )); then
    cpu_color=$G
  elif (( cpu_used_ratio <= (max_usage * 100) )); then
    cpu_color=$Y
  else
    cpu_color=$R
  fi
  printf "${W}  %-*s: ${cpu_color}%s${W} %s\n" "$cs" "CPU" "${cpu_used_percent}%" "($PROCESSOR_COUNT CPU)"

  # Fetch Memory Usage
  memory_info=$(free -b | grep Mem)
  memory_info_h=$(free -h | grep Mem)
  memory_used=$(echo "$memory_info" | awk '{print $3}')
  memory_used_h=$(echo "$memory_info_h" | awk '{print $3}')
  memory_total=$(echo "$memory_info" | awk '{print $2}')
  memory_total_h=$(echo "$memory_info_h" | awk '{print $2}')
  print_usage "Memory" $memory_used $memory_used_h $memory_total $memory_total_h

  # Fetch Disk Usage
  disk_root_info=$(df / | awk 'NR==2 {print $3, $2, $5}')
  disk_root_info_h=$(df / -h | awk 'NR==2 {print $3, $2, $5}')
  disk_root_used=$(echo "$disk_root_info" | awk '{print $1}')
  disk_root_used_h=$(echo "$disk_root_info_h" | awk '{print $1}')
  disk_root_total=$(echo "$disk_root_info" | awk '{print $2}')
  disk_root_total_h=$(echo "$disk_root_info_h" | awk '{print $2}')
  print_usage "DiskRoot" $disk_root_used $disk_root_used_h $disk_root_total $disk_root_total_h

  disks=$(df --output=target -x tmpfs -x devtmpfs | tail -n +2 | grep -vE '^(/boot|/snap)' | grep -vE '^(/)$')
  if [[ -n "${disks}" ]]; then
    while read -r line; do
      disk_info=$(df $line | awk 'NR==2 {print $3, $2, $5}')
      disk_info_h=$(df $line -h | awk 'NR==2 {print $3, $2, $5}')
      disk_used=$(echo "$disk_info" | awk '{print $1}')
      disk_used_h=$(echo "$disk_info_h" | awk '{print $1}')
      disk_total=$(echo "$disk_info" | awk '{print $2}')
      disk_total_h=$(echo "$disk_info_h" | awk '{print $2}')
      if [[ "$disk_used" != "$disk_root_used" ]]; then
        if [[ "$disk_total" != "$disk_root_total" ]]; then
          print_usage "DiskOther" $disk_used $disk_used_h $disk_total $disk_total_h $line
        fi
      fi
    done <<< "$disks"
  fi
  
  # set column width
  COLUMNS=3
  # sort services
  IFS=$'\n' services=($(sort <<<"${services[*]}"))
  unset IFS

  service_status=()
  # get status of all services
  for service in "${services[@]}"; do
    service_status+=($(systemctl is-active "$service"))
  done

  out=""
  for i in ${!services[@]}; do
    # color green if service is active, else red
    if [[ "${service_status[$i]}" == "active" ]]; then
      out+="${services[$i]}:,${G}${service_status[$i]}${undim},"
    else
      out+="${services[$i]}:,${R}${service_status[$i]}${undim},"
    fi
    # insert \n every $COLUMNS column
    if [ $((($i+1) % $COLUMNS)) -eq 0 ]; then
      out+="\n"
    fi
  done
  out+="\n"

  echo -e "\n${W}Services:"
  printf "$out" | column -ts $',' | sed -e 's/^/  /'

  echo -e "\n${W}Active Logins:"
  who_output=$(who)

  # Print header with dynamic spacing
  printf "  %-19s | %-10s | %-17s | %s\n" "User" "Terminal" "Session Start" "From"

  # Parse and format each line
  while IFS= read -r line; do
    # Extract fields
    username=$(echo "$line" | awk '{print $1}')
    terminal=$(echo "$line" | awk '{print $2}')
    login_time=$(echo "$line" | awk '{print $3, $4}')
    login_from=$(echo "$line" | awk '{print $5}' | tr -d '()')

    if [ "$terminal" == "tty1" ]; then
      login_from="console"
    fi

    # Print formatted output with dynamic spacing
    printf "  %-19s | %-10s | %-17s | %s\n" "$username" "$terminal" "$login_time" "$login_from"
  done <<< "$who_output"

  # Check if reboot is required
  if [ -f /var/run/reboot-required ]; then
    echo "Reboot Required: $REBOOT_REQUIRED"
  fi
}

if [[ "$1" == "-v" || "$1" == "-V" ]]; then
  echo "zn-motd v$motd_ver"
else
  print_motd
fi