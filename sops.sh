#!/usr/bin/env bash
set -euo pipefail

sh_v="0.1.5"

cyan='\033[96m'
green='\033[32m'
white='\033[0m'

pause() {
  echo
  read -r -n 1 -s -p "Press any key to continue..."
  echo
}

show_header() {
  clear
  echo -e "${cyan}SOPS Script Toolbox v${sh_v}${white}"
  echo "------------------------"
}

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "This action requires root privileges."
    pause
    return 1
  fi
  return 0
}

to_human() {
  local bytes="${1:-0}"
  awk -v b="$bytes" 'BEGIN {
    split("B KB MB GB TB", u, " ");
    i=1;
    while (b>=1024 && i<5) { b/=1024; i++ }
    if (i==1) printf "%.0f%s", b, u[i];
    else printf "%.2f%s", b, u[i];
  }'
}

percent() {
  local used="$1" total="$2"
  if [ "${total:-0}" -eq 0 ]; then
    echo "0.00%"
  else
    awk -v u="$used" -v t="$total" 'BEGIN { printf "%.2f%%", (u/t)*100 }'
  fi
}

cpu_usage_percent() {
  local a b idle_a idle_b total_a total_b diff_idle diff_total
  a=$(grep '^cpu ' /proc/stat)
  sleep 0.5
  b=$(grep '^cpu ' /proc/stat)

  read -r _ user nice system idle iowait irq softirq steal _ <<<"$a"
  idle_a=$((idle + iowait))
  total_a=$((user + nice + system + idle + iowait + irq + softirq + steal))

  read -r _ user nice system idle iowait irq softirq steal _ <<<"$b"
  idle_b=$((idle + iowait))
  total_b=$((user + nice + system + idle + iowait + irq + softirq + steal))

  diff_idle=$((idle_b - idle_a))
  diff_total=$((total_b - total_a))
  if [ "$diff_total" -le 0 ]; then
    echo "0%"
  else
    awk -v di="$diff_idle" -v dt="$diff_total" 'BEGIN { printf "%.0f%%", (1-di/dt)*100 }'
  fi
}

system_query() {
  show_header
  echo "System Information"
  echo "-------------"

  local host os_pretty kernel
  host="$(hostname)"
  os_pretty="$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
  [ -z "$os_pretty" ] && os_pretty="Unknown"
  kernel="$(uname -r)"

  echo "Hostname:       ${host}"
  echo "OS:             ${os_pretty}"
  echo "Kernel:         ${kernel}"
  echo "-------------"

  local cpu_arch cpu_model cpu_cores cpu_freq
  cpu_arch="$(uname -m)"
  cpu_model="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
  [ -z "$cpu_model" ] && cpu_model="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^[ \t]*//')"
  [ -z "$cpu_model" ] && cpu_model="Unknown"
  cpu_cores="$(nproc 2>/dev/null || echo 0)"
  cpu_freq="$(lscpu 2>/dev/null | awk -F: '/CPU MHz/ {gsub(/^[ \t]+/,"",$2); printf "%.1f MHz", $2; exit}')"
  [ -z "$cpu_freq" ] && cpu_freq="Unknown"

  echo "CPU Arch:       ${cpu_arch}"
  echo "CPU Model:      ${cpu_model}"
  echo "CPU Cores:      ${cpu_cores}"
  echo "CPU Frequency:  ${cpu_freq}"
  echo "-------------"

  local cpu_usage load_avg tcp_conn udp_conn
  cpu_usage="$(cpu_usage_percent)"
  load_avg="$(awk '{print $1", "$2", "$3}' /proc/loadavg)"
  tcp_conn="$(ss -ant 2>/dev/null | awk 'NR>1 {c++} END{print c+0}')"
  udp_conn="$(ss -anu 2>/dev/null | awk 'NR>1 {c++} END{print c+0}')"

  echo "CPU Usage:      ${cpu_usage}"
  echo "Load Average:   ${load_avg}"
  echo "TCP/UDP Conns:  ${tcp_conn}|${udp_conn}"

  local mem_total mem_used swap_total swap_used
  mem_total="$(free -b | awk '/^Mem:/ {print $2}')"
  mem_used="$(free -b | awk '/^Mem:/ {print $3}')"
  swap_total="$(free -b | awk '/^Swap:/ {print $2}')"
  swap_used="$(free -b | awk '/^Swap:/ {print $3}')"

  echo "RAM:            $(to_human "$mem_used")/$(to_human "$mem_total") ($(percent "$mem_used" "$mem_total"))"
  echo "Swap:           $(to_human "$swap_used")/$(to_human "$swap_total") ($(percent "$swap_used" "$swap_total"))"

  local disk_total disk_used
  disk_total="$(df -B1 / | awk 'NR==2 {print $2}')"
  disk_used="$(df -B1 / | awk 'NR==2 {print $3}')"
  echo "Disk:           $(to_human "$disk_used")/$(to_human "$disk_total") ($(percent "$disk_used" "$disk_total"))"
  echo "-------------"

  local rx_total tx_total
  rx_total="$(awk -F'[: ]+' 'NR>2 {rx+=$3} END{print rx+0}' /proc/net/dev)"
  tx_total="$(awk -F'[: ]+' 'NR>2 {tx+=$11} END{print tx+0}' /proc/net/dev)"
  echo "Total RX:       $(to_human "$rx_total")"
  echo "Total TX:       $(to_human "$tx_total")"
  echo "-------------"

  local cc qdisc
  cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
  echo "TCP Algo:       ${cc} ${qdisc}"
  echo "-------------"

  local org ip dns tz now city region country
  org="$(curl -fsSL --max-time 2 ipinfo.io/org 2>/dev/null || true)"
  ip="$(curl -fsSL --max-time 2 ipinfo.io/ip 2>/dev/null || true)"
  dns="$(awk '/^nameserver/ {printf("%s ",$2)} END{print ""}' /etc/resolv.conf | sed 's/[[:space:]]*$//')"
  tz="$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo Unknown)"
  now="$(date '+%Y-%m-%d %I:%M %p')"
  city="$(curl -fsSL --max-time 2 ipinfo.io/city 2>/dev/null || true)"
  region="$(curl -fsSL --max-time 2 ipinfo.io/region 2>/dev/null || true)"
  country="$(curl -fsSL --max-time 2 ipinfo.io/country 2>/dev/null || true)"

  echo "Provider:       ${org:-Unknown}"
  echo "IPv4:           ${ip:-Unknown}"
  echo "DNS:            ${dns:-Unknown}"
  echo "Location:       ${country:-Unknown} ${region:-} ${city:-}"
  echo "System Time:    ${tz}  ${now}"
  echo "-------------"

  local up
  up="$(uptime -p 2>/dev/null | sed 's/^up //')"
  [ -z "$up" ] && up="Unknown"
  echo "Uptime:         ${up}"
  echo
  echo -e "${green}Done${white}"
  pause
}

detect_update_cmd() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt-get update && apt-get -y upgrade"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf -y upgrade --refresh"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum -y update"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper --non-interactive refresh && zypper --non-interactive update"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman -Syu --noconfirm"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk update && apk upgrade"
  else
    echo ""
  fi
}

system_update() {
  require_root || return
  show_header
  echo "System Update"
  echo "------------------------"

  local cmd
  cmd="$(detect_update_cmd)"
  if [ -z "$cmd" ]; then
    echo "No supported package manager found."
    pause
    return
  fi

  echo "Running:"
  echo "$cmd"
  echo "------------------------"
  bash -lc "$cmd"
  echo "Update complete."
  pause
}

system_cleanup() {
  require_root || return
  show_header
  echo "System Cleanup"
  echo "------------------------"
  echo "Cleaning cache, unused deps, logs and temp files."

  if command -v apt-get >/dev/null 2>&1; then
    apt-get -y autoremove --purge || true
    apt-get -y autoclean || true
    apt-get -y clean || true
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y autoremove || true
    dnf -y clean all || true
  elif command -v yum >/dev/null 2>&1; then
    yum -y autoremove || true
    yum -y clean all || true
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive clean --all || true
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sc --noconfirm || true
  elif command -v apk >/dev/null 2>&1; then
    apk cache clean || true
  fi

  journalctl --vacuum-time=7d >/dev/null 2>&1 || true
  find /tmp -mindepth 1 -mtime +3 -exec rm -rf {} + 2>/dev/null || true
  find /var/tmp -mindepth 1 -mtime +3 -exec rm -rf {} + 2>/dev/null || true

  echo "Cleanup complete."
  pause
}

system_operations_menu() {
  while true; do
    show_header
    echo "System Operations"
    echo "------------------------"
    echo "1. System Query"
    echo "2. System Update"
    echo "3. System Cleanup"
    echo "------------------------"
    echo "0. Return to Main Menu"
    echo "------------------------"
    read -r -p "Please enter your choice: " sub_choice
    case "${sub_choice}" in
      1) system_query ;;
      2) system_update ;;
      3) system_cleanup ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

base_tools_menu() {
  while true; do
    show_header
    echo "Basic Tools"
    echo "------------------------"
    echo "1. Coming soon...."
    echo "------------------------"
    echo "0. Return to Main Menu"
    echo "------------------------"
    read -r -p "Please enter your choice: " bt_choice
    case "${bt_choice}" in
      1)
        show_header
        echo "Coming soon...."
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

show_main_menu() {
  echo "1.  System Operations"
  echo "2.  Basic Tools"
  echo "------------------------"
  echo "00. Script Update"
  echo "------------------------"
  echo "0.  Exit"
  echo "------------------------"
}

update_script() {
  show_header
  echo "Updating script from GitHub..."

  local update_url tmp_file target_file
  update_url="https://raw.githubusercontent.com/stone086/sops/main/sops.sh"
  tmp_file="/tmp/sops.sh.$$"
  target_file="${HOME}/sops.sh"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$update_url" -o "$tmp_file"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp_file" "$update_url"
  else
    echo "curl/wget not found."
    pause
    return
  fi

  if [ ! -s "$tmp_file" ]; then
    echo "Download failed: empty file."
    rm -f "$tmp_file" 2>/dev/null || true
    pause
    return
  fi

  chmod +x "$tmp_file" 2>/dev/null || true
  mv -f "$tmp_file" "$target_file"
  chmod +x "$target_file" 2>/dev/null || true

  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    cp -f "$target_file" /usr/local/bin/s 2>/dev/null || true
    ln -sf /usr/local/bin/s /usr/bin/s 2>/dev/null || true
  fi

  echo "Updated from GitHub. Restarting..."
  exec bash "$target_file"
}

main() {
  while true; do
    show_header
    show_main_menu
    read -r -p "Please enter your choice: " choice
    case "${choice}" in
      1) system_operations_menu ;;
      2) base_tools_menu ;;
      00) update_script ;;
      0) exit 0 ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

main "$@"