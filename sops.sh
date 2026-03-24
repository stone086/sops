#!/usr/bin/env bash
set -euo pipefail

sh_v="0.1.5"

cyan='\033[96m'
green='\033[32m'
yellow='\033[33m'
red='\033[31m'
white='\033[0m'
bold='\033[1m'

pause() {
  echo
  read -r -n 1 -s -p "Press any key to continue..."
  echo
}

read_numeric_choice() {
  local __var_name="$1"
  local __prompt="$2"
  local __value=""
  while true; do
    read -r -p "$__prompt" __value
    if [[ "$__value" =~ ^[0-9]+$ ]]; then
      printf -v "$__var_name" '%s' "$__value"
      return 0
    fi
    echo "Invalid input: numbers only."
  done
}

status_mark() {
  local spec="$1"
  local cmd
  IFS='|' read -r -a _cmds <<< "$spec"
  for cmd in "${_cmds[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf "${bold}${green}OK${white}"
      return 0
    fi
  done
  printf "${bold}${red}NO${white}"
}

basic_star() {
  local code="$1"
  case "$code" in
    101|104|106|201|301|303|401|501|601|801|804|807)
      printf " ${yellow}*${white}"
      ;;
    *)
      printf ""
      ;;
  esac
}

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  else
    echo ""
  fi
}

install_package_for_current_pm() {
  local apt_pkg="$1" dnf_pkg="$2" yum_pkg="$3" zypper_pkg="$4" pacman_pkg="$5" apk_pkg="$6"
  local pm
  pm="$(detect_pkg_manager)"
  case "$pm" in
    apt)
      [ -n "$apt_pkg" ] || return 1
      apt-get update >/dev/null 2>&1 || true
      apt-get install -y $apt_pkg
      ;;
    dnf)
      [ -n "$dnf_pkg" ] || return 1
      dnf -y install $dnf_pkg
      ;;
    yum)
      [ -n "$yum_pkg" ] || return 1
      yum -y install $yum_pkg
      ;;
    zypper)
      [ -n "$zypper_pkg" ] || return 1
      zypper --non-interactive in $zypper_pkg
      ;;
    pacman)
      [ -n "$pacman_pkg" ] || return 1
      pacman -Sy --noconfirm $pacman_pkg
      ;;
    apk)
      [ -n "$apk_pkg" ] || return 1
      apk add --no-cache $apk_pkg
      ;;
    *)
      return 1
      ;;
  esac
}

install_command_if_missing() {
  local cmd="$1"
  local apt_pkg="$2" dnf_pkg="$3" yum_pkg="$4" zypper_pkg="$5" pacman_pkg="$6" apk_pkg="$7"
  command -v "$cmd" >/dev/null 2>&1 && return 0
  install_package_for_current_pm "$apt_pkg" "$dnf_pkg" "$yum_pkg" "$zypper_pkg" "$pacman_pkg" "$apk_pkg" || return 1
  command -v "$cmd" >/dev/null 2>&1
}

ensure_tool_dependencies() {
  local code="$1"
  case "$code" in
    101) install_command_if_missing ping "iputils-ping" "iputils" "iputils" "iputils" "iputils" "iputils" || true ;;
    102) install_command_if_missing traceroute "traceroute" "traceroute" "traceroute" "traceroute" "traceroute" "traceroute" || true ;;
    103) install_command_if_missing mtr "mtr" "mtr" "mtr" "mtr" "mtr" "mtr" || true ;;
    104) install_command_if_missing curl "curl" "curl" "curl" "curl" "curl" "curl" || true ;;
    105)
      # Port check tool package names vary by distro; try multiple candidates.
      if ! command -v nc >/dev/null 2>&1 && ! command -v ncat >/dev/null 2>&1; then
        local pm
        pm="$(detect_pkg_manager)"
        case "$pm" in
          apt)
            apt-get update >/dev/null 2>&1 || true
            apt-get install -y netcat-openbsd >/dev/null 2>&1 \
              || apt-get install -y netcat-traditional >/dev/null 2>&1 \
              || apt-get install -y netcat >/dev/null 2>&1 \
              || true
            ;;
          dnf)
            dnf -y install nmap-ncat >/dev/null 2>&1 || dnf -y install nc >/dev/null 2>&1 || true
            ;;
          yum)
            yum -y install nmap-ncat >/dev/null 2>&1 || yum -y install nc >/dev/null 2>&1 || true
            ;;
          zypper)
            zypper --non-interactive in netcat-openbsd >/dev/null 2>&1 || zypper --non-interactive in netcat >/dev/null 2>&1 || true
            ;;
          pacman)
            pacman -Sy --noconfirm gnu-netcat >/dev/null 2>&1 || pacman -Sy --noconfirm openbsd-netcat >/dev/null 2>&1 || true
            ;;
          apk)
            apk add --no-cache netcat-openbsd >/dev/null 2>&1 || apk add --no-cache netcat-openbsd-bsd >/dev/null 2>&1 || true
            ;;
        esac
      fi
      ;;
    106)
      install_command_if_missing dig "dnsutils" "bind-utils" "bind-utils" "bind-utils" "bind" "bind-tools" || true
      install_command_if_missing nslookup "dnsutils" "bind-utils" "bind-utils" "bind-utils" "bind" "bind-tools" || true
      ;;
    303) install_command_if_missing ss "iproute2" "iproute" "iproute" "iproute2" "iproute2" "iproute2" || true ;;
    402) install_command_if_missing ssh "openssh-client" "openssh-clients" "openssh-clients" "openssh-clients" "openssh" "openssh-client" || true ;;
    501|502|503|504)
      install_command_if_missing ufw "ufw" "" "" "" "" "ufw" || true
      install_command_if_missing firewall-cmd "" "firewalld" "firewalld" "firewalld" "" "" || true
      ;;
    601|602|603)
      install_command_if_missing ssh "openssh-client openssh-server" "openssh-clients openssh-server" "openssh-clients openssh-server" "openssh-clients openssh" "openssh" "openssh-client openssh-server" || true
      ;;
    604) install_command_if_missing fail2ban-client "fail2ban" "fail2ban" "fail2ban" "fail2ban" "fail2ban" "fail2ban" || true ;;
    801|802) : ;;
    803)
      if ! command -v ntpdate >/dev/null 2>&1 && ! command -v chronyc >/dev/null 2>&1 && ! command -v timedatectl >/dev/null 2>&1; then
        local pm
        pm="$(detect_pkg_manager)"
        case "$pm" in
          apt)
            apt-get update >/dev/null 2>&1 || true
            apt-get install -y chrony >/dev/null 2>&1 \
              || apt-get install -y ntpdate >/dev/null 2>&1 \
              || apt-get install -y ntp >/dev/null 2>&1 \
              || true
            ;;
          dnf)
            dnf -y install chrony >/dev/null 2>&1 || dnf -y install ntpsec >/dev/null 2>&1 || true
            ;;
          yum)
            yum -y install chrony >/dev/null 2>&1 || yum -y install ntp >/dev/null 2>&1 || true
            ;;
          zypper)
            zypper --non-interactive in chrony >/dev/null 2>&1 || zypper --non-interactive in ntp >/dev/null 2>&1 || true
            ;;
          pacman)
            pacman -Sy --noconfirm chrony >/dev/null 2>&1 || pacman -Sy --noconfirm ntp >/dev/null 2>&1 || true
            ;;
          apk)
            apk add --no-cache chrony >/dev/null 2>&1 || apk add --no-cache openntpd >/dev/null 2>&1 || true
            ;;
        esac
      fi
      ;;
    807|808) install_command_if_missing tar "tar" "tar" "tar" "tar" "tar" "tar" || true ;;
    809) install_command_if_missing sysctl "procps" "procps-ng" "procps-ng" "procps" "procps-ng" "procps" || true ;;
  esac
}

show_header() {
  clear
  echo -e "${cyan}${bold}  ____   ___  ____  ____${white}"
  echo -e "${cyan}${bold} / ___| / _ \\|  _ \\/ ___|${white}"
  echo -e "${cyan}${bold} \\___ \\| | | | |_) \\___ \\${white}"
  echo -e "${cyan}${bold}  ___) | |_| |  __/ ___) |${white}"
  echo -e "${cyan}${bold} |____/ \\___/|_|   |____/${white}"
  echo -e "${cyan}${bold} SOPS Script Toolbox v${sh_v}${white}"
  echo -e "${cyan} Current shortcut key: ${yellow}s${white}"
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

list_installed_software_and_uninstall() {
  require_root || return
  show_header
  echo "Installed Software"
  echo "------------------------"

  local manager=""
  local -a packages=()
  local max_list=30
  local i=0

  if command -v apt >/dev/null 2>&1; then
    manager="apt"
    mapfile -t packages < <(apt list --installed 2>/dev/null | awk -F/ 'NR>1{print $1}' | head -n "$max_list")
  elif command -v dnf >/dev/null 2>&1; then
    manager="dnf"
    mapfile -t packages < <(dnf -q list installed 2>/dev/null | awk 'NR>1{print $1}' | sed 's/\.[^.]*$//' | head -n "$max_list")
  elif command -v yum >/dev/null 2>&1; then
    manager="yum"
    mapfile -t packages < <(yum -q list installed 2>/dev/null | awk 'NR>1{print $1}' | sed 's/\.[^.]*$//' | head -n "$max_list")
  elif command -v zypper >/dev/null 2>&1; then
    manager="zypper"
    mapfile -t packages < <(zypper se -i 2>/dev/null | awk 'NR>4{print $3}' | head -n "$max_list")
  elif command -v pacman >/dev/null 2>&1; then
    manager="pacman"
    mapfile -t packages < <(pacman -Qq 2>/dev/null | head -n "$max_list")
  elif command -v apk >/dev/null 2>&1; then
    manager="apk"
    mapfile -t packages < <(apk list -I 2>/dev/null | awk -F- '{print $1}' | head -n "$max_list")
  fi

  if [ -z "$manager" ] || [ "${#packages[@]}" -eq 0 ]; then
    echo "No supported package manager found, or package list is empty."
    pause
    return
  fi

  for pkg in "${packages[@]}"; do
    i=$((i + 1))
    printf "%2d. %s\n" "$i" "$pkg"
  done

  echo "------------------------"
  echo "0. Cancel"
  echo "------------------------"
  read_numeric_choice uninstall_idx "Software number to uninstall: "

  if [ "$uninstall_idx" -eq 0 ]; then
    return
  fi
  if [ "$uninstall_idx" -lt 1 ] || [ "$uninstall_idx" -gt "${#packages[@]}" ]; then
    echo "Invalid software number."
    pause
    return
  fi

  local selected_pkg
  selected_pkg="${packages[$((uninstall_idx - 1))]}"
  echo "------------------------"
  echo "Uninstalling: $selected_pkg"

  case "$manager" in
    apt) apt-get -y remove "$selected_pkg" ;;
    dnf) dnf -y remove "$selected_pkg" ;;
    yum) yum -y remove "$selected_pkg" ;;
    zypper) zypper --non-interactive rm "$selected_pkg" ;;
    pacman) pacman -R --noconfirm "$selected_pkg" ;;
    apk) apk del "$selected_pkg" ;;
  esac

  echo "Operation complete."
  pause
}

check_open_ports_and_close() {
  require_root || return
  show_header
  echo "Open Ports"
  echo "------------------------"

  local -a ports=()
  mapfile -t ports < <(ss -lntupH 2>/dev/null | awk '{print $5}' | awk -F: '{print $NF}' | sed 's/[^0-9].*$//' | grep -E '^[0-9]+$' | sort -n -u)

  if [ "${#ports[@]}" -eq 0 ]; then
    echo "No open TCP/UDP listening ports found."
    pause
    return
  fi

  local idx=0
  local p
  for p in "${ports[@]}"; do
    idx=$((idx + 1))
    printf "%2d. %s\n" "$idx" "$p"
  done

  echo "------------------------"
  echo "0. Cancel"
  echo "------------------------"
  read_numeric_choice close_port "Port to close: "

  if [ "$close_port" -eq 0 ]; then
    return
  fi

  if ! printf '%s\n' "${ports[@]}" | grep -qx "$close_port"; then
    echo "Port $close_port is not in the current open-port list."
    pause
    return
  fi

  echo "Applying firewall rule to close port $close_port ..."
  if command -v ufw >/dev/null 2>&1; then
    ufw deny "$close_port" >/dev/null 2>&1 || true
    ufw deny "${close_port}/tcp" >/dev/null 2>&1 || true
    ufw deny "${close_port}/udp" >/dev/null 2>&1 || true
  elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --remove-port="${close_port}/tcp" >/dev/null 2>&1 || true
    firewall-cmd --permanent --remove-port="${close_port}/udp" >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
  else
    iptables -D INPUT -p tcp --dport "$close_port" -j ACCEPT >/dev/null 2>&1 || true
    iptables -D INPUT -p udp --dport "$close_port" -j ACCEPT >/dev/null 2>&1 || true
  fi

  echo "Done. Please verify service-level config if the port is still reachable."
  pause
}

system_ops_coming_soon() {
  local code="$1"
  local name="$2"
  show_header
  echo "System Operation ${code}: ${name}"
  echo "------------------------"
  echo "SOPS local module placeholder."
  echo "No third-party remote script is used."
  pause
}

sops_sshd_conf_file() {
  if [ -f /etc/ssh/sshd_config ]; then
    echo "/etc/ssh/sshd_config"
  else
    echo "/etc/ssh/sshd_config"
  fi
}

sops_restart_sshd() {
  systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null || service sshd restart 2>/dev/null || true
}

set_sshd_kv() {
  local key="$1"
  local value="$2"
  local conf
  conf="$(sops_sshd_conf_file)"
  cp -f "$conf" "${conf}.bak.$(date +%s)" 2>/dev/null || true
  if grep -Eq "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]+" "$conf"; then
    sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}[[:space:]].*|${key} ${value}|g" "$conf"
  else
    echo "${key} ${value}" >>"$conf"
  fi
}

op_password_login_mode() {
  require_root || return
  while true; do
    show_header
    echo "Password Login Mode"
    echo "------------------------"
    echo "1. Enable password login"
    echo "2. Disable password login"
    echo "3. Show current auth settings"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice pl_choice "Please enter your choice: "
    case "${pl_choice}" in
      1)
        set_sshd_kv "PasswordAuthentication" "yes"
        set_sshd_kv "ChallengeResponseAuthentication" "no"
        sops_restart_sshd
        echo "Password login enabled."
        pause
        ;;
      2)
        set_sshd_kv "PasswordAuthentication" "no"
        set_sshd_kv "ChallengeResponseAuthentication" "no"
        sops_restart_sshd
        echo "Password login disabled."
        pause
        ;;
      3)
        local conf
        conf="$(sops_sshd_conf_file)"
        grep -Ei "^[[:space:]]*(PasswordAuthentication|PubkeyAuthentication|ChallengeResponseAuthentication|PermitRootLogin)[[:space:]]+" "$conf" || true
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_change_ssh_port() {
  require_root || return
  show_header
  echo "Change SSH Port"
  echo "------------------------"
  local old_port new_port
  old_port="$(ss -lntp 2>/dev/null | awk '/sshd/ {split($4,a,\":\"); print a[length(a)]}' | head -n 1)"
  [ -z "$old_port" ] && old_port="22"
  echo "Current SSH port: $old_port"
  read_numeric_choice new_port "New SSH port (1-65535): "
  if [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
    echo "Invalid port range."
    pause
    return
  fi

  set_sshd_kv "Port" "$new_port"
  set_sshd_kv "Protocol" "2"
  sops_restart_sshd

  if command -v ufw >/dev/null 2>&1; then
    ufw allow "${new_port}/tcp" >/dev/null 2>&1 || true
  elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port="${new_port}/tcp" >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
  else
    iptables -I INPUT -p tcp --dport "$new_port" -j ACCEPT >/dev/null 2>&1 || true
  fi

  echo "SSH port changed to $new_port."
  echo "Listening check:"
  ss -lnt 2>/dev/null | awk -v p=":$new_port" '$4 ~ p {print}'
  pause
}

op_firewall_manager() {
  require_root || return
  while true; do
    show_header
    echo "Advanced Firewall Manager"
    echo "------------------------"
    echo "1. Show firewall status"
    echo "2. Open TCP port"
    echo "3. Close TCP port"
    echo "4. List rules"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice fw_choice "Please enter your choice: "
    case "${fw_choice}" in
      1)
        if command -v ufw >/dev/null 2>&1; then
          ufw status verbose || true
        elif command -v firewall-cmd >/dev/null 2>&1; then
          firewall-cmd --state || true
          firewall-cmd --list-all || true
        else
          iptables -S || true
        fi
        pause
        ;;
      2)
        read_numeric_choice p "Port to open: "
        if command -v ufw >/dev/null 2>&1; then
          ufw allow "${p}/tcp" || true
        elif command -v firewall-cmd >/dev/null 2>&1; then
          firewall-cmd --permanent --add-port="${p}/tcp" || true
          firewall-cmd --reload || true
        else
          iptables -I INPUT -p tcp --dport "$p" -j ACCEPT || true
        fi
        echo "Open rule applied for tcp/$p."
        pause
        ;;
      3)
        read_numeric_choice p "Port to close: "
        if command -v ufw >/dev/null 2>&1; then
          ufw deny "${p}/tcp" || true
        elif command -v firewall-cmd >/dev/null 2>&1; then
          firewall-cmd --permanent --remove-port="${p}/tcp" || true
          firewall-cmd --reload || true
        else
          iptables -D INPUT -p tcp --dport "$p" -j ACCEPT || true
        fi
        echo "Close rule applied for tcp/$p."
        pause
        ;;
      4)
        if command -v ufw >/dev/null 2>&1; then
          ufw status numbered || true
        elif command -v firewall-cmd >/dev/null 2>&1; then
          firewall-cmd --list-all || true
        else
          iptables -L -n --line-numbers || true
        fi
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_cron_manager() {
  while true; do
    show_header
    echo "Cron Manager"
    echo "------------------------"
    echo "1. List current crontab"
    echo "2. Add cron line"
    echo "3. Remove cron by line number"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice cron_choice "Please enter your choice: "
    case "${cron_choice}" in
      1)
        crontab -l 2>/dev/null || echo "No crontab entries."
        pause
        ;;
      2)
        echo "Enter a full cron line (example: */5 * * * * /usr/bin/echo hello)"
        read -r cron_line
        (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
        echo "Cron line added."
        pause
        ;;
      3)
        local tmpf idx
        tmpf="$(mktemp)"
        crontab -l 2>/dev/null >"$tmpf" || true
        if [ ! -s "$tmpf" ]; then
          echo "No crontab entries."
          rm -f "$tmpf"
          pause
          continue
        fi
        nl -ba "$tmpf"
        read_numeric_choice idx "Line number to remove: "
        sed -i "${idx}d" "$tmpf"
        crontab "$tmpf"
        rm -f "$tmpf"
        echo "Cron line removed."
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_key_login_mode() {
  require_root || return
  while true; do
    show_header
    echo "Key Login Mode"
    echo "------------------------"
    echo "1. Enable key login (keep password)"
    echo "2. Key login only (disable password)"
    echo "3. Show SSH auth settings"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice key_choice "Please enter your choice: "
    case "${key_choice}" in
      1)
        set_sshd_kv "PubkeyAuthentication" "yes"
        sops_restart_sshd
        echo "Key login enabled."
        pause
        ;;
      2)
        set_sshd_kv "PubkeyAuthentication" "yes"
        set_sshd_kv "PasswordAuthentication" "no"
        set_sshd_kv "ChallengeResponseAuthentication" "no"
        sops_restart_sshd
        echo "Key-only login enabled."
        pause
        ;;
      3)
        local conf
        conf="$(sops_sshd_conf_file)"
        grep -Ei "^[[:space:]]*(PasswordAuthentication|PubkeyAuthentication|ChallengeResponseAuthentication|PermitRootLogin|Port)[[:space:]]+" "$conf" || true
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_set_script_shortcut() {
  require_root || return
  show_header
  echo "Set Script Shortcut"
  echo "------------------------"
  echo "Current script path: ${HOME}/sops.sh"
  echo "Choose command alias to launch SOPS."
  echo "Examples: s / so / sops"
  read -r -p "Alias name: " alias_name
  if ! [[ "$alias_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Invalid alias name."
    pause
    return
  fi
  cp -f "${HOME}/sops.sh" "/usr/local/bin/${alias_name}" 2>/dev/null || true
  chmod +x "/usr/local/bin/${alias_name}" 2>/dev/null || true
  ln -sf "/usr/local/bin/${alias_name}" "/usr/bin/${alias_name}" 2>/dev/null || true
  echo "Shortcut created: ${alias_name}"
  pause
}

op_change_login_password() {
  require_root || return
  show_header
  echo "Change Login Password"
  echo "------------------------"
  read -r -p "Username (empty = root): " u
  [ -z "$u" ] && u="root"
  if ! id "$u" >/dev/null 2>&1; then
    echo "User not found: $u"
    pause
    return
  fi
  passwd "$u"
  pause
}

op_open_all_ports() {
  require_root || return
  show_header
  echo "Open All Ports"
  echo "------------------------"
  if command -v ufw >/dev/null 2>&1; then
    ufw --force disable || true
    echo "UFW disabled."
  elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --set-default-zone=trusted >/dev/null 2>&1 || true
    firewall-cmd --permanent --zone=trusted --add-service=ssh >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
    echo "firewalld set to trusted zone."
  else
    iptables -P INPUT ACCEPT >/dev/null 2>&1 || true
    iptables -P FORWARD ACCEPT >/dev/null 2>&1 || true
    iptables -P OUTPUT ACCEPT >/dev/null 2>&1 || true
    echo "iptables default policy set to ACCEPT."
  fi
  pause
}

op_user_management() {
  require_root || return
  while true; do
    show_header
    echo "User Management"
    echo "------------------------"
    echo "1. List users"
    echo "2. Create user"
    echo "3. Delete user"
    echo "4. Lock user"
    echo "5. Unlock user"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice um_choice "Please enter your choice: "
    case "$um_choice" in
      1) awk -F: '{print $1}' /etc/passwd; pause ;;
      2) read -r -p "New username: " u; useradd -m "$u" && passwd "$u"; pause ;;
      3) read -r -p "Delete username: " u; userdel -r "$u" 2>/dev/null || userdel "$u" 2>/dev/null || true; pause ;;
      4) read -r -p "Lock username: " u; passwd -l "$u" || true; pause ;;
      5) read -r -p "Unlock username: " u; passwd -u "$u" || true; pause ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_password_generator() {
  show_header
  echo "User/Password Generator"
  echo "------------------------"
  local user pass
  user="u$(date +%H%M%S)"
  pass="$(tr -dc 'A-Za-z0-9@#%+=' </dev/urandom | head -c 16)"
  echo "Generated user: $user"
  echo "Generated pass: $pass"
  pause
}

op_timezone_settings() {
  require_root || return
  while true; do
    show_header
    echo "Timezone Settings"
    echo "------------------------"
    echo "Current timezone: $(timedatectl show -p Timezone --value 2>/dev/null || echo unknown)"
    echo "1. Set timezone"
    echo "2. Sync time (NTP)"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice tz_choice "Please enter your choice: "
    case "$tz_choice" in
      1) read -r -p "Timezone (e.g. Asia/Shanghai): " tz; timedatectl set-timezone "$tz" && echo "Timezone updated."; pause ;;
      2) timedatectl set-ntp true 2>/dev/null || true; echo "NTP sync requested."; pause ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_change_hostname() {
  require_root || return
  show_header
  echo "Change Hostname"
  echo "------------------------"
  echo "Current: $(hostname)"
  read -r -p "New hostname: " hn
  if [ -z "$hn" ]; then
    echo "Hostname cannot be empty."
    pause
    return
  fi
  hostnamectl set-hostname "$hn" 2>/dev/null || echo "$hn" >/etc/hostname
  echo "Hostname changed to: $hn"
  pause
}

op_hosts_manager() {
  require_root || return
  while true; do
    show_header
    echo "/etc/hosts Manager"
    echo "------------------------"
    echo "1. View hosts"
    echo "2. Add host record"
    echo "3. Remove by keyword"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice h_choice "Please enter your choice: "
    case "$h_choice" in
      1) cat /etc/hosts; pause ;;
      2)
        read -r -p "IP: " hip
        read -r -p "Domain: " hdn
        echo "$hip $hdn" >>/etc/hosts
        echo "Added."
        pause
        ;;
      3)
        read -r -p "Keyword to remove: " kw
        sed -i "/$kw/d" /etc/hosts
        echo "Removed matched lines."
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_command_history_tools() {
  show_header
  echo "Command History"
  echo "------------------------"
  history | tail -n 100
  echo "------------------------"
  echo "Clear current history file? (1=yes, 0=no)"
  read_numeric_choice hc "Please enter your choice: "
  if [ "$hc" -eq 1 ]; then
    : >"${HOME}/.bash_history"
    history -c || true
    echo "History cleared."
  fi
  pause
}

op_rsync_remote_sync() {
  require_root || return
  show_header
  echo "Rsync Remote Sync"
  echo "------------------------"
  if ! command -v rsync >/dev/null 2>&1; then
    install_package_for_current_pm "rsync" "rsync" "rsync" "rsync" "rsync" "rsync" || true
  fi
  echo "Example:"
  echo "rsync -avz /src/ user@host:/dst/"
  echo "Run one sync now (1=yes, 0=no)"
  read_numeric_choice rs "Please enter your choice: "
  if [ "$rs" -eq 1 ]; then
    read -r -p "Source path: " rsrc
    read -r -p "Destination (user@host:/path): " rdst
    rsync -avz "$rsrc" "$rdst"
  fi
  pause
}

op_optimize_dns() {
  require_root || return
  show_header
  echo "Optimize DNS"
  echo "------------------------"
  echo "1. Cloudflare + Google (1.1.1.1 / 8.8.8.8)"
  echo "2. Google only (8.8.8.8 / 8.8.4.4)"
  echo "3. Quad9 (9.9.9.9 / 149.112.112.112)"
  echo "------------------------"
  echo -e "${yellow}0. RTM${white}"
  echo "------------------------"
  read_numeric_choice dns_choice "Please enter your choice: "

  local dns1 dns2
  case "$dns_choice" in
    1) dns1="1.1.1.1"; dns2="8.8.8.8" ;;
    2) dns1="8.8.8.8"; dns2="8.8.4.4" ;;
    3) dns1="9.9.9.9"; dns2="149.112.112.112" ;;
    0) return ;;
    *) echo "Invalid choice"; pause; return ;;
  esac

  cp -f /etc/resolv.conf "/etc/resolv.conf.bak.$(date +%s)" 2>/dev/null || true

  if command -v resolvectl >/dev/null 2>&1; then
    local nic
    nic="$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')"
    if [ -n "$nic" ]; then
      resolvectl dns "$nic" "$dns1" "$dns2" >/dev/null 2>&1 || true
      resolvectl domain "$nic" "~." >/dev/null 2>&1 || true
    fi
  fi

  cat >/etc/resolv.conf <<EOF
nameserver $dns1
nameserver $dns2
EOF
  echo "DNS updated:"
  cat /etc/resolv.conf
  pause
}

op_enable_bbr3() {
  require_root || return
  show_header
  echo "Enable BBR3"
  echo "------------------------"

  local avail
  avail="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || echo "")"

  if echo "$avail" | grep -qw bbr3; then
    cat >/etc/sysctl.d/99-sops-bbr.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr3
EOF
    sysctl --system >/dev/null 2>&1 || true
    echo "BBR3 applied."
  elif echo "$avail" | grep -qw bbr; then
    cat >/etc/sysctl.d/99-sops-bbr.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl --system >/dev/null 2>&1 || true
    echo "BBR3 not available on this kernel. BBR applied instead."
  else
    echo "Neither bbr3 nor bbr is available on current kernel."
  fi

  echo "Current: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  echo "Available: $avail"
  pause
}

op_ssh_defense() {
  require_root || return
  show_header
  echo "SSH Defense"
  echo "------------------------"
  echo "Applying baseline hardening for SSH + fail2ban."

  install_package_for_current_pm "fail2ban" "fail2ban" "fail2ban" "fail2ban" "fail2ban" "fail2ban" >/dev/null 2>&1 || true

  set_sshd_kv "MaxAuthTries" "3"
  set_sshd_kv "LoginGraceTime" "30"
  set_sshd_kv "ClientAliveInterval" "300"
  set_sshd_kv "ClientAliveCountMax" "2"
  sops_restart_sshd

  mkdir -p /etc/fail2ban
  cat >/etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 5
findtime = 10m
bantime = 1h
EOF
  systemctl enable fail2ban >/dev/null 2>&1 || true
  systemctl restart fail2ban >/dev/null 2>&1 || true

  echo "SSH defense baseline applied."
  echo "fail2ban status:"
  fail2ban-client status 2>/dev/null || echo "fail2ban not available/running."
  pause
}

op_openssh_cve_fix() {
  require_root || return
  show_header
  echo "OpenSSH Security Update"
  echo "------------------------"
  local pm
  pm="$(detect_pkg_manager)"
  case "$pm" in
    apt)
      apt-get update
      apt-get install --only-upgrade -y openssh-server openssh-client || apt-get install -y openssh-server openssh-client
      ;;
    dnf) dnf -y upgrade openssh openssh-server openssh-clients || true ;;
    yum) yum -y update openssh openssh-server openssh-clients || true ;;
    zypper) zypper --non-interactive up openssh openssh-server || true ;;
    pacman) pacman -Sy --noconfirm openssh || true ;;
    apk) apk add --no-cache openssh openssh-server-common || true ;;
    *)
      echo "Unsupported package manager."
      pause
      return
      ;;
  esac
  sops_restart_sshd
  echo "OpenSSH update completed."
  ssh -V 2>&1 || true
  pause
}

op_backup_restore() {
  require_root || return
  while true; do
    show_header
    echo "Backup & Restore"
    echo "------------------------"
    echo "1. Create backup"
    echo "2. List backups"
    echo "3. Restore backup"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice br_choice "Please enter your choice: "
    case "$br_choice" in
      1)
        mkdir -p /etc/sops/backups
        local bk="/etc/sops/backups/sops-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "$bk" /etc "${HOME}/sops.sh" 2>/dev/null || true
        echo "Backup created: $bk"
        pause
        ;;
      2)
        ls -lh /etc/sops/backups 2>/dev/null || echo "No backups found."
        pause
        ;;
      3)
        ls -lh /etc/sops/backups 2>/dev/null || true
        read -r -p "Backup file full path: " bkf
        if [ ! -f "$bkf" ]; then
          echo "Backup file not found."
          pause
          continue
        fi
        tar -xzf "$bkf" -C / 2>/dev/null || true
        echo "Restore completed (best effort)."
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_install_python_version() {
  require_root || return
  show_header
  echo "Install Python Version"
  echo "------------------------"
  local ver pm
  pm="$(detect_pkg_manager)"
  read -r -p "Python major.minor (example: 3.11), empty = distro default: " ver

  case "$pm" in
    apt)
      apt-get update
      if [ -n "$ver" ]; then
        apt-get install -y "python${ver}" "python${ver}-venv" "python${ver}-distutils" || apt-get install -y python3 python3-venv
      else
        apt-get install -y python3 python3-venv
      fi
      ;;
    dnf|yum)
      if [ -n "$ver" ]; then
        ${pm} -y install "python${ver}" || ${pm} -y install python3
      else
        ${pm} -y install python3
      fi
      ;;
    zypper)
      zypper --non-interactive in python3 python3-pip || true
      ;;
    pacman)
      pacman -Sy --noconfirm python python-pip
      ;;
    apk)
      apk add --no-cache python3 py3-pip
      ;;
    *)
      echo "Unsupported package manager."
      pause
      return
      ;;
  esac
  python3 --version 2>/dev/null || true
  pause
}

op_disable_root_create_user() {
  require_root || return
  show_header
  echo "Disable Root + Create New User"
  echo "------------------------"
  read -r -p "New username: " newu
  if [ -z "$newu" ]; then
    echo "Username cannot be empty."
    pause
    return
  fi
  if id "$newu" >/dev/null 2>&1; then
    echo "User exists: $newu"
  else
    useradd -m -s /bin/bash "$newu"
    passwd "$newu"
  fi
  usermod -aG sudo "$newu" 2>/dev/null || usermod -aG wheel "$newu" 2>/dev/null || true
  set_sshd_kv "PermitRootLogin" "no"
  sops_restart_sshd
  echo "Root SSH login disabled. New user ready: $newu"
  pause
}

op_prefer_ipv4_ipv6() {
  require_root || return
  show_header
  echo "Prefer IPv4/IPv6"
  echo "------------------------"
  echo "1. Prefer IPv4"
  echo "2. Prefer IPv6"
  echo "3. Reset default"
  echo "------------------------"
  echo -e "${yellow}0. RTM${white}"
  echo "------------------------"
  read_numeric_choice ip_pref "Please enter your choice: "

  cp -f /etc/gai.conf "/etc/gai.conf.bak.$(date +%s)" 2>/dev/null || true
  sed -i '/^precedence ::ffff:0:0\/96/d' /etc/gai.conf 2>/dev/null || true
  sed -i '/^precedence ::\/0/d' /etc/gai.conf 2>/dev/null || true

  case "$ip_pref" in
    1) echo 'precedence ::ffff:0:0/96  100' >>/etc/gai.conf; echo "IPv4 preferred." ;;
    2) echo 'precedence ::/0  100' >>/etc/gai.conf; echo "IPv6 preferred." ;;
    3) echo "Preference reset." ;;
    0) return ;;
    *) echo "Invalid choice" ;;
  esac
  pause
}

op_switch_package_mirror() {
  require_root || return
  show_header
  echo "Switch Package Mirror"
  echo "------------------------"
  local pm
  pm="$(detect_pkg_manager)"
  case "$pm" in
    apt)
      cp -f /etc/apt/sources.list "/etc/apt/sources.list.bak.$(date +%s)" 2>/dev/null || true
      if [ -f /etc/os-release ] && grep -qi ubuntu /etc/os-release; then
        sed -i 's|http://[^ ]*archive.ubuntu.com/ubuntu/|https://archive.ubuntu.com/ubuntu/|g; s|http://[^ ]*security.ubuntu.com/ubuntu/|https://security.ubuntu.com/ubuntu/|g' /etc/apt/sources.list || true
      else
        sed -i 's|http://[^ ]*deb.debian.org/debian|https://deb.debian.org/debian|g; s|http://[^ ]*security.debian.org/debian-security|https://security.debian.org/debian-security|g' /etc/apt/sources.list || true
      fi
      apt-get update || true
      ;;
    dnf|yum)
      ${pm} clean all || true
      ${pm} makecache || true
      ;;
    zypper)
      zypper refresh || true
      ;;
    pacman)
      pacman -Syy || true
      ;;
    apk)
      apk update || true
      ;;
  esac
  echo "Mirror refresh completed."
  pause
}

op_command_favorites() {
  local fav="${HOME}/.sops_favorites"
  touch "$fav"
  while true; do
    show_header
    echo "Command Favorites"
    echo "------------------------"
    echo "1. Show favorites"
    echo "2. Add favorite command"
    echo "3. Remove by line number"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice cf "Please enter your choice: "
    case "$cf" in
      1) nl -ba "$fav"; pause ;;
      2) read -r -p "Command: " cmd; echo "$cmd" >>"$fav"; echo "Added."; pause ;;
      3) nl -ba "$fav"; read_numeric_choice ln "Line to remove: "; sed -i "${ln}d" "$fav"; echo "Removed."; pause ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_system_log_manager() {
  while true; do
    show_header
    echo "System Log Manager"
    echo "------------------------"
    echo "1. Show latest journal"
    echo "2. Vacuum logs older than 7 days"
    echo "3. Follow journal live"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice sl "Please enter your choice: "
    case "$sl" in
      1) journalctl -n 200 --no-pager 2>/dev/null || echo "journalctl not available"; pause ;;
      2) require_root || continue; journalctl --vacuum-time=7d 2>/dev/null || true; echo "Done."; pause ;;
      3) journalctl -f 2>/dev/null || true ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_env_variable_manager() {
  local envf="/etc/profile.d/sops-env.sh"
  while true; do
    show_header
    echo "Environment Variable Manager"
    echo "------------------------"
    echo "1. List global vars (sops file)"
    echo "2. Add variable"
    echo "3. Remove variable"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice ev "Please enter your choice: "
    case "$ev" in
      1) [ -f "$envf" ] && cat "$envf" || echo "No variables yet."; pause ;;
      2)
        require_root || continue
        read -r -p "Variable name: " k
        read -r -p "Variable value: " v
        mkdir -p /etc/profile.d
        touch "$envf"
        sed -i "/^export ${k}=/d" "$envf"
        echo "export ${k}=\"${v}\"" >>"$envf"
        echo "Added. Re-login to apply."
        pause
        ;;
      3)
        require_root || continue
        read -r -p "Variable name to remove: " k
        [ -f "$envf" ] && sed -i "/^export ${k}=/d" "$envf"
        echo "Removed."
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_privacy_security() {
  show_header
  echo "Privacy & Security"
  echo "------------------------"
  echo "Quick checklist:"
  echo "- SSH password login: $(grep -Ei '^[[:space:]]*PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null | tail -n1 || echo unknown)"
  echo "- Root login: $(grep -Ei '^[[:space:]]*PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null | tail -n1 || echo unknown)"
  echo "- Firewall cmd: $(command -v ufw >/dev/null 2>&1 && echo ufw || (command -v firewall-cmd >/dev/null 2>&1 && echo firewalld || echo iptables/manual))"
  echo "- fail2ban: $(command -v fail2ban-client >/dev/null 2>&1 && echo installed || echo missing)"
  echo "- Last SSH logins:"
  last -n 5 2>/dev/null || true
  pause
}

op_s_advanced_usage() {
  show_header
  echo "s Command Advanced Usage"
  echo "------------------------"
  echo "1) Launch script: s"
  echo "2) Direct run: bash ~/sops.sh"
  echo "3) Update from menu: 00"
  echo "4) If shortcut missing, recreate from [6] Set Script Shortcut"
  echo "5) Check shortcut target:"
  echo "   ls -l /usr/local/bin/s /usr/bin/s 2>/dev/null"
  pause
}

op_reinstall_os_local() {
  require_root || return
  show_header
  echo "Reinstall OS (Local Safe Mode)"
  echo "------------------------"
  echo "SOPS does not run unknown remote reinstall scripts."
  echo "Use your cloud provider panel reinstall feature for safety."
  echo "This module only provides local pre-check and backup reminder."
  echo "Hostname: $(hostname)"
  echo "Disk:"
  lsblk
  echo "Backups folder: /etc/sops/backups"
  pause
}

op_resize_swap() {
  require_root || return
  show_header
  echo "Resize Swap"
  echo "------------------------"
  read_numeric_choice swap_mb "New swap size (MB): "
  if [ "$swap_mb" -lt 256 ]; then
    echo "Swap too small."
    pause
    return
  fi
  swapoff -a 2>/dev/null || true
  rm -f /swapfile
  dd if=/dev/zero of=/swapfile bs=1M count="$swap_mb" status=none
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
  echo "Swap resized to ${swap_mb}MB."
  free -h
  pause
}

op_traffic_limit_shutdown() {
  require_root || return
  show_header
  echo "Traffic-limit Auto Shutdown"
  echo "------------------------"
  echo "Set monthly RX+TX threshold in GB. When exceeded, shutdown now."
  read_numeric_choice gb "Threshold (GB, 0=disable): "
  local script="/usr/local/bin/sops_traffic_guard.sh"
  local cronf="/etc/cron.d/sops-traffic-guard"
  if [ "$gb" -eq 0 ]; then
    rm -f "$script" "$cronf"
    echo "Traffic guard disabled."
    pause
    return
  fi
  cat >"$script" <<EOF
#!/usr/bin/env bash
set -e
limit_bytes=\$(( $gb * 1024 * 1024 * 1024 ))
usage=\$(awk -F'[: ]+' 'NR>2 {rx+=\$3; tx+=\$11} END{print rx+tx}' /proc/net/dev)
if [ "\${usage:-0}" -ge "\$limit_bytes" ]; then
  shutdown -h now "Traffic limit exceeded"
fi
EOF
  chmod +x "$script"
  cat >"$cronf" <<EOF
*/10 * * * * root $script
EOF
  echo "Traffic guard enabled at ${gb}GB."
  pause
}

op_tg_bot_monitoring() {
  show_header
  echo "TG-bot Monitoring"
  echo "------------------------"
  echo "Local setup only (no third-party script)."
  local cfg="${HOME}/.sops_tg.conf"
  echo "1. Configure bot token/chat id"
  echo "2. Send test message"
  echo "3. Show config file"
  echo "------------------------"
  echo -e "${yellow}0. RTM${white}"
  echo "------------------------"
  read_numeric_choice tg "Please enter your choice: "
  case "$tg" in
    1)
      read -r -p "Bot token: " t
      read -r -p "Chat ID: " c
      cat >"$cfg" <<EOF
BOT_TOKEN="$t"
CHAT_ID="$c"
EOF
      chmod 600 "$cfg"
      echo "Saved: $cfg"
      pause
      ;;
    2)
      if [ ! -f "$cfg" ]; then echo "Configure first."; pause; return; fi
      # shellcheck disable=SC1090
      . "$cfg"
      curl -fsSL -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" -d "text=SOPS monitoring test from $(hostname)" >/dev/null \
        && echo "Test sent." || echo "Send failed."
      pause
      ;;
    3) [ -f "$cfg" ] && sed 's/BOT_TOKEN=.*/BOT_TOKEN=\"***\"/' "$cfg" || echo "No config."; pause ;;
    0) return ;;
    *) echo "Invalid choice"; pause ;;
  esac
}

op_rhel_kernel_upgrade() {
  require_root || return
  show_header
  echo "RHEL Kernel Upgrade"
  echo "------------------------"
  if command -v dnf >/dev/null 2>&1; then
    dnf -y upgrade kernel || true
  elif command -v yum >/dev/null 2>&1; then
    yum -y update kernel || true
  else
    echo "Not a RHEL-family package manager."
    pause
    return
  fi
  echo "Kernel update finished. Reboot may be required."
  pause
}

op_kernel_param_optimize() {
  require_root || return
  show_header
  echo "Kernel Parameter Optimize"
  echo "------------------------"
  cat >/etc/sysctl.d/99-sops-kernel-opt.conf <<'EOF'
fs.file-max = 1000000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 600
vm.swappiness = 10
EOF
  sysctl --system >/dev/null 2>&1 || true
  echo "Kernel parameters optimized."
  pause
}

op_virus_scanner() {
  require_root || return
  show_header
  echo "Virus Scanner"
  echo "------------------------"
  install_package_for_current_pm "clamav" "clamav" "clamav" "clamav" "clamav" "clamav" >/dev/null 2>&1 || true
  if command -v clamscan >/dev/null 2>&1; then
    echo "Running quick scan on /root ..."
    clamscan -r --infected --exclude-dir='^/sys|^/proc|^/dev' /root 2>/dev/null || true
  else
    echo "clamav not available."
  fi
  pause
}

op_file_manager() {
  while true; do
    show_header
    echo "File Manager"
    echo "------------------------"
    echo "1. List directory"
    echo "2. Copy file"
    echo "3. Move file"
    echo "4. Delete file"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice fm "Please enter your choice: "
    case "$fm" in
      1) read -r -p "Path: " p; ls -lah "${p:-.}"; pause ;;
      2) read -r -p "Source: " s; read -r -p "Dest: " d; cp -rf "$s" "$d"; echo "Done."; pause ;;
      3) read -r -p "Source: " s; read -r -p "Dest: " d; mv -f "$s" "$d"; echo "Done."; pause ;;
      4) read -r -p "Path to delete: " p; rm -rf "$p"; echo "Deleted."; pause ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_switch_system_language() {
  require_root || return
  show_header
  echo "Switch System Language"
  echo "------------------------"
  echo "1. en_US.UTF-8"
  echo "2. zh_CN.UTF-8"
  echo "------------------------"
  echo -e "${yellow}0. RTM${white}"
  echo "------------------------"
  read_numeric_choice lg "Please enter your choice: "
  case "$lg" in
    1) localectl set-locale LANG=en_US.UTF-8 2>/dev/null || true; echo 'LANG=en_US.UTF-8' >/etc/default/locale 2>/dev/null || true ;;
    2) localectl set-locale LANG=zh_CN.UTF-8 2>/dev/null || true; echo 'LANG=zh_CN.UTF-8' >/etc/default/locale 2>/dev/null || true ;;
    0) return ;;
    *) echo "Invalid choice"; pause; return ;;
  esac
  echo "Language setting updated. Re-login to apply."
  pause
}

op_cli_beautifier() {
  require_root || return
  show_header
  echo "CLI Beautifier"
  echo "------------------------"
  install_package_for_current_pm "bash-completion" "bash-completion" "bash-completion" "bash-completion" "bash-completion" "bash-completion" >/dev/null 2>&1 || true
  grep -q "bash_completion" "${HOME}/.bashrc" 2>/dev/null || cat >>"${HOME}/.bashrc" <<'EOF'
if [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
fi
EOF
  echo "Bash completion enabled (new shell required)."
  pause
}

op_recycle_bin_setup() {
  show_header
  echo "Recycle Bin Setup"
  echo "------------------------"
  local rb="${HOME}/.trash"
  mkdir -p "$rb"
  if ! grep -q "alias rm='mv -t \$HOME/.trash'" "${HOME}/.bashrc" 2>/dev/null; then
    echo "alias rm='mv -t \$HOME/.trash'" >>"${HOME}/.bashrc"
  fi
  echo "Recycle bin path: $rb"
  echo "rm is now aliased to move files into trash (new shell required)."
  pause
}

op_ssh_remote_tool() {
  show_header
  echo "SSH Remote Tool"
  echo "------------------------"
  echo "1. Show SSH client version"
  echo "2. Generate key pair"
  echo "3. Print SSH connect example"
  echo "------------------------"
  echo -e "${yellow}0. RTM${white}"
  echo "------------------------"
  read_numeric_choice sr "Please enter your choice: "
  case "$sr" in
    1) ssh -V 2>&1; pause ;;
    2) ssh-keygen -t ed25519 -f "${HOME}/.ssh/id_ed25519" -N ""; echo "Key generated."; pause ;;
    3) read -r -p "Host/IP: " h; read -r -p "User: " u; echo "ssh ${u}@${h}"; pause ;;
    0) return ;;
    *) echo "Invalid choice"; pause ;;
  esac
}

op_disk_partition_tool() {
  require_root || return
  show_header
  echo "Disk Partition Tool"
  echo "------------------------"
  lsblk
  echo "------------------------"
  fdisk -l 2>/dev/null || true
  echo "For safety, partition edits are manual (fdisk/parted)."
  pause
}

op_nic_manager() {
  require_root || return
  while true; do
    show_header
    echo "NIC Manager"
    echo "------------------------"
    ip -br a
    echo "------------------------"
    echo "1. Bring interface down"
    echo "2. Bring interface up"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice nc "Please enter your choice: "
    case "$nc" in
      1) read -r -p "Interface: " ifn; ip link set "$ifn" down; echo "Done."; pause ;;
      2) read -r -p "Interface: " ifn; ip link set "$ifn" up; echo "Done."; pause ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

op_full_tuning() {
  require_root || return
  show_header
  echo "One-click Full Tuning"
  echo "------------------------"
  echo "Applying: update, cleanup, kernel optimize, BBR."
  system_update || true
  system_cleanup || true
  op_kernel_param_optimize || true
  op_enable_bbr3 || true
}

system_operations_menu() {
  while true; do
    show_header
    echo "System Operations"
    echo "------------------------"
    echo " 1. System Query                      2. System Update"
    echo " 3. System Cleanup                    4. Installed Software"
    echo " 5. Open Ports                        6. Set Script Shortcut"
    echo " 7. Change Login Password             8. Password Login Mode"
    echo " 9. Install Python Version            10. Open All Ports"
    echo "------------------------"
    echo "11. Change SSH Port                   12. Optimize DNS"
    echo "13. Reinstall OS *                   14. Disable Root + New User"
    echo "15. Prefer IPv4/IPv6                 16. Resize Swap"
    echo "17. User Management                   18. User/Password Generator"
    echo "19. Timezone Settings                 20. Enable BBR3"
    echo "------------------------"
    echo "21. Advanced Firewall Manager         22. Change Hostname"
    echo "23. Switch Package Mirror             24. Cron Manager"
    echo "25. Local /etc/hosts Manager          26. SSH Defense"
    echo "27. Traffic-limit Auto Shutdown       28. Key Login Mode"
    echo "29. TG-bot Monitoring                 30. OpenSSH CVE Fix"
    echo "------------------------"
    echo "31. RHEL Kernel Upgrade               32. Kernel Parameter Optimize *"
    echo "33. Virus Scanner *                   34. File Manager"
    echo "35. Switch System Language            36. CLI Beautifier *"
    echo "37. Recycle Bin                       38. Backup & Restore"
    echo "39. SSH Remote Tool                   40. Disk Partition Tool"
    echo "------------------------"
    echo "41. Command History                   42. Rsync Remote Sync"
    echo "43. Command Favorites *               44. NIC Manager"
    echo "45. System Log Manager *              46. Env Variable Manager"
    echo "47. One-click Full Tuning *           48. Privacy & Security"
    echo "49. s Command Advanced Usage *"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice sub_choice "Please enter your choice: "
    case "${sub_choice}" in
      1) system_query ;;
      2) system_update ;;
      3) system_cleanup ;;
      4) list_installed_software_and_uninstall ;;
      5) check_open_ports_and_close ;;
      6) op_set_script_shortcut ;;
      7) op_change_login_password ;;
      8) op_password_login_mode ;;
      9) op_install_python_version ;;
      10) op_open_all_ports ;;
      11) op_change_ssh_port ;;
      12) op_optimize_dns ;;
      13) op_reinstall_os_local ;;
      14) op_disable_root_create_user ;;
      15) op_prefer_ipv4_ipv6 ;;
      16) op_resize_swap ;;
      17) op_user_management ;;
      18) op_password_generator ;;
      19) op_timezone_settings ;;
      20) op_enable_bbr3 ;;
      21) op_firewall_manager ;;
      22) op_change_hostname ;;
      23) op_switch_package_mirror ;;
      24) op_cron_manager ;;
      25) op_hosts_manager ;;
      26) op_ssh_defense ;;
      27) op_traffic_limit_shutdown ;;
      28) op_key_login_mode ;;
      29) op_tg_bot_monitoring ;;
      30) op_openssh_cve_fix ;;
      31) op_rhel_kernel_upgrade ;;
      32) op_kernel_param_optimize ;;
      33) op_virus_scanner ;;
      34) op_file_manager ;;
      35) op_switch_system_language ;;
      36) op_cli_beautifier ;;
      37) op_recycle_bin_setup ;;
      38) op_backup_restore ;;
      39) op_ssh_remote_tool ;;
      40) op_disk_partition_tool ;;
      41) op_command_history_tools ;;
      42) op_rsync_remote_sync ;;
      43) op_command_favorites ;;
      44) op_nic_manager ;;
      45) op_system_log_manager ;;
      46) op_env_variable_manager ;;
      47) op_full_tuning ;;
      48) op_privacy_security ;;
      49) op_s_advanced_usage ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

basic_tool_todo() {
  local code="$1"
  local name="$2"
  require_root || return
  echo "Checking/installing dependencies..."
  ensure_tool_dependencies "$code"
  show_header
  echo "Tool ${code}: ${name}"
  echo "------------------------"
  echo "This tool is reserved and will be implemented next."
  pause
}

base_tools_menu() {
  while true; do
    show_header
    echo "Basic Tools"
    echo "------------------------"
    echo "C1 Network"
    echo -e "101. Ping Test$(basic_star 101) [$(status_mark 'ping')]                    102. Traceroute$(basic_star 102) [$(status_mark 'traceroute|tracepath')]"
    echo -e "103. MTR Test$(basic_star 103) [$(status_mark 'mtr')]                     104. HTTP Connectivity Check$(basic_star 104) [$(status_mark 'curl|wget')]"
    echo -e "105. Port Connectivity Check$(basic_star 105) [$(status_mark 'nc|ncat')]      106. DNS Lookup$(basic_star 106) [$(status_mark 'dig|nslookup')]"
    echo "------------------------"
    echo "C2 Disk"
    echo -e "201. Disk Usage Overview$(basic_star 201) [$(status_mark 'df')]          202. Large Files Scan$(basic_star 202) [$(status_mark 'find')]"
    echo -e "203. Inode Usage Check$(basic_star 203) [$(status_mark 'df')]            204. Mount Info$(basic_star 204) [$(status_mark 'mount')]"
    echo "------------------------"
    echo "C3 Process"
    echo -e "301. Top Processes$(basic_star 301) [$(status_mark 'ps')]                302. Kill Process$(basic_star 302) [$(status_mark 'kill')]"
    echo -e "303. Listening Ports$(basic_star 303) [$(status_mark 'ss|netstat')]              304. Service Status$(basic_star 304) [$(status_mark 'systemctl|service')]"
    echo "------------------------"
    echo "C4 Logs"
    echo -e "401. System Journal (latest)$(basic_star 401) [$(status_mark 'journalctl')]      402. SSH Log Quick View$(basic_star 402) [$(status_mark 'ssh')]"
    echo -e "403. Nginx/Apache Log Quick View$(basic_star 403) [$(status_mark 'nginx|apache2|httpd')]"
    echo "------------------------"
    echo "C5 Firewall"
    echo -e "501. Firewall Status$(basic_star 501) [$(status_mark 'ufw|firewall-cmd|iptables')]              502. Open Port$(basic_star 502) [$(status_mark 'ufw|firewall-cmd|iptables')]"
    echo -e "503. Close Port$(basic_star 503) [$(status_mark 'ufw|firewall-cmd|iptables')]                   504. Firewall Rules List$(basic_star 504) [$(status_mark 'ufw|firewall-cmd|iptables')]"
    echo "------------------------"
    echo "C6 SSH"
    echo -e "601. SSH Security Check$(basic_star 601) [$(status_mark 'ssh|sshd')]           602. Change SSH Port$(basic_star 602) [$(status_mark 'ssh|sshd')]"
    echo -e "603. Password/Key Auth Check$(basic_star 603) [$(status_mark 'ssh|ssh-keygen')]      604. Fail2ban Status$(basic_star 604) [$(status_mark 'fail2ban-client')]"
    echo "------------------------"
    echo "C7 Users"
    echo -e "701. Create User$(basic_star 701) [$(status_mark 'useradd')]                  702. Delete User$(basic_star 702) [$(status_mark 'userdel')]"
    echo -e "703. Grant Sudo$(basic_star 703) [$(status_mark 'usermod')]                   704. Revoke Sudo$(basic_star 704) [$(status_mark 'usermod')]"
    echo -e "705. Manage authorized_keys$(basic_star 705) [$(status_mark 'ssh|ssh-copy-id')]"
    echo "------------------------"
    echo "C8 Maint"
    echo -e "801. Show Timezone$(basic_star 801) [$(status_mark 'timedatectl')]                802. Set Timezone$(basic_star 802) [$(status_mark 'timedatectl')]"
    echo -e "803. NTP Sync$(basic_star 803) [$(status_mark 'timedatectl|ntpdate')]                     804. Package Install$(basic_star 804) [$(status_mark 'apt-get|dnf|yum|zypper|pacman|apk')]"
    echo -e "805. Package Remove$(basic_star 805) [$(status_mark 'apt-get|dnf|yum|zypper|pacman|apk')]               806. Package Search$(basic_star 806) [$(status_mark 'apt-cache|dnf|yum|zypper|pacman|apk')]"
    echo -e "807. Backup Create$(basic_star 807) [$(status_mark 'tar')]                808. Backup Restore$(basic_star 808) [$(status_mark 'tar')]"
    echo -e "809. Security Hardening Preset$(basic_star 809) [$(status_mark 'sysctl')]    810. Diagnostics Bundle$(basic_star 810) [$(status_mark 'bash')]"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice bt_choice "Please enter your choice: "
    case "${bt_choice}" in
      101) basic_tool_todo 101 "Ping Test" ;;
      102) basic_tool_todo 102 "Traceroute" ;;
      103) basic_tool_todo 103 "MTR Test" ;;
      104) basic_tool_todo 104 "HTTP Connectivity Check" ;;
      105) basic_tool_todo 105 "Port Connectivity Check" ;;
      106) basic_tool_todo 106 "DNS Lookup" ;;
      201) basic_tool_todo 201 "Disk Usage Overview" ;;
      202) basic_tool_todo 202 "Large Files Scan" ;;
      203) basic_tool_todo 203 "Inode Usage Check" ;;
      204) basic_tool_todo 204 "Mount Info" ;;
      301) basic_tool_todo 301 "Top Processes" ;;
      302) basic_tool_todo 302 "Kill Process" ;;
      303) basic_tool_todo 303 "Listening Ports" ;;
      304) basic_tool_todo 304 "Service Status" ;;
      401) basic_tool_todo 401 "System Journal (latest)" ;;
      402) basic_tool_todo 402 "SSH Log Quick View" ;;
      403) basic_tool_todo 403 "Nginx/Apache Log Quick View" ;;
      501) basic_tool_todo 501 "Firewall Status" ;;
      502) basic_tool_todo 502 "Open Port" ;;
      503) basic_tool_todo 503 "Close Port" ;;
      504) basic_tool_todo 504 "Firewall Rules List" ;;
      601) basic_tool_todo 601 "SSH Security Check" ;;
      602) basic_tool_todo 602 "Change SSH Port" ;;
      603) basic_tool_todo 603 "Password/Key Auth Check" ;;
      604) basic_tool_todo 604 "Fail2ban Status" ;;
      701) basic_tool_todo 701 "Create User" ;;
      702) basic_tool_todo 702 "Delete User" ;;
      703) basic_tool_todo 703 "Grant Sudo" ;;
      704) basic_tool_todo 704 "Revoke Sudo" ;;
      705) basic_tool_todo 705 "Manage authorized_keys" ;;
      801) basic_tool_todo 801 "Show Timezone" ;;
      802) basic_tool_todo 802 "Set Timezone" ;;
      803) basic_tool_todo 803 "NTP Sync" ;;
      804) basic_tool_todo 804 "Package Install" ;;
      805) basic_tool_todo 805 "Package Remove" ;;
      806) basic_tool_todo 806 "Package Search" ;;
      807) basic_tool_todo 807 "Backup Create" ;;
      808) basic_tool_todo 808 "Backup Restore" ;;
      809) basic_tool_todo 809 "Security Hardening Preset" ;;
      810) basic_tool_todo 810 "Diagnostics Bundle" ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

coming_soon_main() {
  show_header
  echo "Coming soon...."
  pause
}

bbr_safe_placeholder() {
  local title="$1"
  show_header
  echo "$title"
  echo "------------------------"
  echo "SOPS safe mode: this item is reserved."
  echo "No third-party remote script is executed."
  pause
}

bbr_apply_cc_qdisc() {
  local cc="$1"
  local qdisc="$2"
  modprobe tcp_bbr 2>/dev/null || true
  modprobe sch_fq 2>/dev/null || true
  modprobe sch_fq_codel 2>/dev/null || true
  modprobe sch_cake 2>/dev/null || true
  cat >/etc/sysctl.d/99-sops-bbr.conf <<EOF
net.core.default_qdisc=${qdisc}
net.ipv4.tcp_congestion_control=${cc}
EOF
  sysctl --system >/dev/null 2>&1 || true
}

bbr_set_ecn() {
  local val="$1"
  cat >/etc/sysctl.d/99-sops-ecn.conf <<EOF
net.ipv4.tcp_ecn=${val}
EOF
  sysctl --system >/dev/null 2>&1 || true
}

bbr_set_ipv6_state() {
  local disable="$1"
  cat >/etc/sysctl.d/99-sops-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6=${disable}
net.ipv6.conf.default.disable_ipv6=${disable}
EOF
  sysctl --system >/dev/null 2>&1 || true
}

bbr_kernel_list() {
  dpkg -l 2>/dev/null | awk '/^ii  linux-image/ {print $2}' || true
  rpm -qa 2>/dev/null | grep -E '^kernel' || true
}

bbr_menu() {
  require_root || return
  while true; do
    show_header
    local cc qd avail ker
    cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
    qd="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
    avail="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || echo unknown)"
    ker="$(uname -r)"

    echo "TCP Acceleration / Kernel Toolbox (SOPS)"
    echo "------------------------"
    echo "9. Switch to kernel-remove mode"
    echo "10. Switch to one-click DD mode      60. Switch to IP quality/media/mail tests"
    echo "------------ Kernel Install ------------"
    echo "1. Install BBR kernel                7. Install Zen kernel"
    echo "2. Install BBRplus kernel            5. Install BBRplus new kernel"
    echo "3. Install Lotserver kernel          8. Install cloud kernel"
    echo "30. Install official stable kernel   31. Install official latest kernel"
    echo "32. Install XANMOD main              33. Install XANMOD LTS"
    echo "36. Install XANMOD EDGE              37. Install XANMOD RT"
    echo "----------- Acceleration -----------"
    echo "11. Use BBR+FQ                       12. Use BBR+FQ_PIE"
    echo "13. Use BBR+CAKE                     14. Use BBR2+FQ"
    echo "15. Use BBR2+FQ_PIE                  16. Use BBR2+CAKE"
    echo "19. Use BBRplus+FQ                   20. Use Lotserver"
    echo "28. Build brutal module"
    echo "------------ System Config ------------"
    echo "17. Enable ECN                       18. Disable ECN"
    echo "21. Sysctl optimize (old)            22. Sysctl optimize (new)"
    echo "23. Disable IPv6                     24. Enable IPv6"
    echo "61. Print kernel params              62. Edit kernel params"
    echo "------------- Kernel Management -------------"
    echo "51. List kernels                     52. Remove old kernels"
    echo "25. Reset acceleration"
    echo "------------------------"
    echo "Info: $(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '\"' || echo unknown)  kernel: ${ker}"
    echo "Status: cc=${cc}  qdisc=${qd}"
    echo "Available cc: ${avail}"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice bbr_choice "Please enter number: "
    case "${bbr_choice}" in
      0) return ;;
      1|2|3|5|7|8|32|33|36|37) bbr_safe_placeholder "Kernel install source not enabled in SOPS safe mode" ;;
      9) bbr_safe_placeholder "Kernel remove mode (reserved)" ;;
      10) bbr_safe_placeholder "One-click DD mode (reserved)" ;;
      11) bbr_apply_cc_qdisc bbr fq; echo "Applied: BBR + FQ"; pause ;;
      12) bbr_apply_cc_qdisc bbr fq_pie; echo "Applied: BBR + FQ_PIE"; pause ;;
      13) bbr_apply_cc_qdisc bbr cake; echo "Applied: BBR + CAKE"; pause ;;
      14)
        if echo "$avail" | grep -qw bbr2; then bbr_apply_cc_qdisc bbr2 fq
        elif echo "$avail" | grep -qw bbr3; then bbr_apply_cc_qdisc bbr3 fq
        else bbr_apply_cc_qdisc bbr fq; fi
        echo "Applied: BBR2/3 + FQ (fallback handled)."; pause ;;
      15)
        if echo "$avail" | grep -qw bbr2; then bbr_apply_cc_qdisc bbr2 fq_pie
        elif echo "$avail" | grep -qw bbr3; then bbr_apply_cc_qdisc bbr3 fq_pie
        else bbr_apply_cc_qdisc bbr fq_pie; fi
        echo "Applied: BBR2/3 + FQ_PIE (fallback handled)."; pause ;;
      16)
        if echo "$avail" | grep -qw bbr2; then bbr_apply_cc_qdisc bbr2 cake
        elif echo "$avail" | grep -qw bbr3; then bbr_apply_cc_qdisc bbr3 cake
        else bbr_apply_cc_qdisc bbr cake; fi
        echo "Applied: BBR2/3 + CAKE (fallback handled)."; pause ;;
      17) bbr_set_ecn 1; echo "ECN enabled."; pause ;;
      18) bbr_set_ecn 0; echo "ECN disabled."; pause ;;
      19) bbr_apply_cc_qdisc bbr fq; echo "Applied: BBRplus+FQ compatible profile."; pause ;;
      20) bbr_safe_placeholder "Lotserver is not integrated (closed-source/unsafe path blocked)." ;;
      21)
        cat >/etc/sysctl.d/99-sops-net-old.conf <<'EOF'
net.core.somaxconn=1024
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_tw_reuse=1
EOF
        sysctl --system >/dev/null 2>&1 || true
        echo "Old optimization applied."
        pause
        ;;
      22)
        cat >/etc/sysctl.d/99-sops-net-new.conf <<'EOF'
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_keepalive_time=600
EOF
        sysctl --system >/dev/null 2>&1 || true
        echo "New optimization applied."
        pause
        ;;
      23) bbr_set_ipv6_state 1; echo "IPv6 disabled."; pause ;;
      24) bbr_set_ipv6_state 0; echo "IPv6 enabled."; pause ;;
      25) bbr_apply_cc_qdisc cubic fq_codel; echo "Acceleration reset to cubic + fq_codel."; pause ;;
      28) bbr_safe_placeholder "brutal module build is reserved." ;;
      30)
        install_package_for_current_pm "linux-image-amd64" "kernel" "kernel" "kernel-default" "linux" "linux-lts" || true
        echo "Official stable kernel install command executed."
        pause
        ;;
      31)
        install_package_for_current_pm "linux-image-cloud-amd64 linux-image-amd64" "kernel" "kernel" "kernel-default" "linux" "linux-virt" || true
        echo "Official latest kernel install command executed."
        pause
        ;;
      51) show_header; echo "Installed kernels"; echo "------------------------"; bbr_kernel_list; pause ;;
      52)
        show_header
        echo "Remove old kernels"
        echo "------------------------"
        if command -v apt-get >/dev/null 2>&1; then
          apt-get -y autoremove --purge || true
        elif command -v dnf >/dev/null 2>&1; then
          dnf -y autoremove || true
        elif command -v yum >/dev/null 2>&1; then
          yum -y autoremove || true
        else
          echo "Kernel cleanup for this distro is manual."
        fi
        pause
        ;;
      60) test_suite_menu ;;
      61) show_header; echo "Kernel-related parameters"; echo "------------------------"; sysctl -a 2>/dev/null | grep -E 'net\\.(core|ipv4|ipv6)|fs\\.file-max|vm\\.'; pause ;;
      62)
        local target="/etc/sysctl.d/99-sops-custom.conf"
        touch "$target"
        if command -v nano >/dev/null 2>&1; then nano "$target";
        elif command -v vi >/dev/null 2>&1; then vi "$target";
        else echo "No editor found: $target"; pause; continue; fi
        sysctl --system >/dev/null 2>&1 || true
        echo "Custom kernel params applied."
        pause
        ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

docker_install_if_needed() {
  command -v docker >/dev/null 2>&1 && return 0
  local pm
  pm="$(detect_pkg_manager)"
  case "$pm" in
    apt) apt-get update && apt-get install -y docker.io ;;
    dnf) dnf -y install docker ;;
    yum) yum -y install docker ;;
    zypper) zypper --non-interactive in docker ;;
    pacman) pacman -Sy --noconfirm docker ;;
    apk) apk add --no-cache docker ;;
    *) return 1 ;;
  esac
}

docker_counts_line() {
  local c i n v
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker environment not installed"
    return
  fi
  c="$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')"
  i="$(docker images -q 2>/dev/null | sort -u | wc -l | tr -d ' ')"
  n="$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')"
  v="$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')"
  echo "Docker installed  containers: ${c}  images: ${i}  networks: ${n}  volumes: ${v}"
}

docker_global_status() {
  show_header
  echo "Docker Global Status"
  echo "------------------------"
  docker_counts_line
  echo "------------------------"
  docker info 2>/dev/null | sed -n '1,40p' || echo "Docker not available."
  pause
}

docker_container_manage() {
  while true; do
    show_header
    echo "Docker Container Manage"
    echo "------------------------"
    echo "1. List containers"
    echo "2. Start container"
    echo "3. Stop container"
    echo "4. Restart container"
    echo "5. Remove container"
    echo "6. Container logs"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice dc "Please enter your choice: "
    case "$dc" in
      1) docker ps -a; pause ;;
      2) read -r -p "Container id/name: " x; docker start "$x"; pause ;;
      3) read -r -p "Container id/name: " x; docker stop "$x"; pause ;;
      4) read -r -p "Container id/name: " x; docker restart "$x"; pause ;;
      5) read -r -p "Container id/name: " x; docker rm -f "$x"; pause ;;
      6) read -r -p "Container id/name: " x; docker logs --tail 200 "$x"; pause ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

docker_image_manage() {
  while true; do
    show_header
    echo "Docker Image Manage"
    echo "------------------------"
    echo "1. List images"
    echo "2. Pull image"
    echo "3. Remove image"
    echo "4. Prune dangling images"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice di "Please enter your choice: "
    case "$di" in
      1) docker images; pause ;;
      2) read -r -p "Image name:tag: " x; docker pull "$x"; pause ;;
      3) read -r -p "Image id/name: " x; docker rmi -f "$x"; pause ;;
      4) docker image prune -f; pause ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

docker_network_manage() {
  while true; do
    show_header
    echo "Docker Network Manage"
    echo "------------------------"
    echo "1. List networks"
    echo "2. Inspect network"
    echo "3. Remove network"
    echo "4. Prune unused networks"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice dn "Please enter your choice: "
    case "$dn" in
      1) docker network ls; pause ;;
      2) read -r -p "Network name: " x; docker network inspect "$x"; pause ;;
      3) read -r -p "Network name: " x; docker network rm "$x"; pause ;;
      4) docker network prune -f; pause ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

docker_volume_manage() {
  while true; do
    show_header
    echo "Docker Volume Manage"
    echo "------------------------"
    echo "1. List volumes"
    echo "2. Inspect volume"
    echo "3. Remove volume"
    echo "4. Prune unused volumes"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice dv "Please enter your choice: "
    case "$dv" in
      1) docker volume ls; pause ;;
      2) read -r -p "Volume name: " x; docker volume inspect "$x"; pause ;;
      3) read -r -p "Volume name: " x; docker volume rm "$x"; pause ;;
      4) docker volume prune -f; pause ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

docker_switch_mirror() {
  require_root || return
  local f="/etc/docker/daemon.json"
  show_header
  echo "Docker Registry Source (Official First)"
  echo "------------------------"
  echo "1. Use official Docker Hub (recommended)"
  echo "2. Disable mirror (official direct)"
  echo "3. Custom mirror URL (advanced)"
  echo "------------------------"
  echo -e "${yellow}0. RTM${white}"
  echo "------------------------"
  read_numeric_choice dm "Please enter your choice: "
  local m=""
  case "$dm" in
    1) m="" ;;
    2) m="" ;;
    3) read -r -p "Mirror URL: " m ;;
    0) return ;;
    *) echo "Invalid choice"; pause; return ;;
  esac
  mkdir -p /etc/docker
  if [ -z "$m" ]; then
    cat >"$f" <<'EOF'
{}
EOF
  else
    cat >"$f" <<EOF
{
  "registry-mirrors": ["$m"]
}
EOF
  fi
  systemctl restart docker >/dev/null 2>&1 || true
  echo "Docker source updated."
  pause
}

docker_edit_daemon_json() {
  require_root || return
  local f="/etc/docker/daemon.json"
  mkdir -p /etc/docker
  touch "$f"
  if command -v nano >/dev/null 2>&1; then
    nano "$f"
  elif command -v vi >/dev/null 2>&1; then
    vi "$f"
  else
    echo "No editor found: $f"
    pause
    return
  fi
  systemctl restart docker >/dev/null 2>&1 || true
  echo "docker daemon restarted."
  pause
}

docker_set_ipv6_mode() {
  require_root || return
  local mode="$1"
  local f="/etc/docker/daemon.json"
  mkdir -p /etc/docker
  if [ "$mode" = "on" ]; then
    cat >"$f" <<'EOF'
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:dead:beef::/48"
}
EOF
    echo "Docker IPv6 enabled."
  else
    cat >"$f" <<'EOF'
{
  "ipv6": false
}
EOF
    echo "Docker IPv6 disabled."
  fi
  systemctl restart docker >/dev/null 2>&1 || true
  pause
}

docker_backup_restore_env() {
  require_root || return
  while true; do
    show_header
    echo "Docker Backup/Restore"
    echo "------------------------"
    echo "1. Backup /var/lib/docker"
    echo "2. Restore /var/lib/docker"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice db "Please enter your choice: "
    case "$db" in
      1)
        mkdir -p /etc/sops/backups
        local bk="/etc/sops/backups/docker-env-$(date +%Y%m%d-%H%M%S).tar.gz"
        systemctl stop docker >/dev/null 2>&1 || true
        tar -czf "$bk" /var/lib/docker 2>/dev/null || true
        systemctl start docker >/dev/null 2>&1 || true
        echo "Backup: $bk"
        pause
        ;;
      2)
        ls -lh /etc/sops/backups/docker-env-*.tar.gz 2>/dev/null || echo "No backups found."
        read -r -p "Backup file path: " bkp
        [ -f "$bkp" ] || { echo "Not found."; pause; continue; }
        systemctl stop docker >/dev/null 2>&1 || true
        tar -xzf "$bkp" -C / 2>/dev/null || true
        systemctl start docker >/dev/null 2>&1 || true
        echo "Restore completed."
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

docker_uninstall_env() {
  require_root || return
  show_header
  echo "Uninstall Docker Environment"
  echo "------------------------"
  read_numeric_choice yn "Confirm uninstall Docker? (1=yes,0=no): "
  [ "$yn" -eq 1 ] || { echo "Cancelled."; pause; return; }
  local pm
  pm="$(detect_pkg_manager)"
  case "$pm" in
    apt) apt-get remove -y docker.io docker-ce docker-ce-cli containerd.io || true ;;
    dnf) dnf -y remove docker docker-ce docker-ce-cli containerd.io || true ;;
    yum) yum -y remove docker docker-ce docker-ce-cli containerd.io || true ;;
    zypper) zypper --non-interactive rm docker docker-ce docker-ce-cli containerd.io || true ;;
    pacman) pacman -R --noconfirm docker || true ;;
    apk) apk del docker docker-cli || true ;;
  esac
  rm -rf /var/lib/docker /etc/docker 2>/dev/null || true
  echo "Docker environment removed."
  pause
}

docker_menu() {
  require_root || return
  while true; do
    show_header
    echo "Docker Management"
    echo "------------------------"
    docker_counts_line
    echo "------------------------"
    echo "1.  Install/Update Docker env *"
    echo "------------------------"
    echo "2.  Docker global status *"
    echo "------------------------"
    echo "3.  Docker container manage *"
    echo "4.  Docker image manage"
    echo "5.  Docker network manage"
    echo "6.  Docker volume manage"
    echo "------------------------"
    echo "7.  Clean unused containers/images/networks/volumes"
    echo "------------------------"
    echo "8.  Switch Docker mirror"
    echo "9.  Edit daemon.json"
    echo "------------------------"
    echo "11. Enable Docker IPv6"
    echo "12. Disable Docker IPv6"
    echo "------------------------"
    echo "19. Backup/Restore Docker env"
    echo "20. Uninstall Docker env"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice docker_choice "Please enter your choice: "
    case "${docker_choice}" in
      1)
        docker_install_if_needed && echo "Docker installation completed." || echo "Docker install failed."
        systemctl enable docker >/dev/null 2>&1 || true
        systemctl start docker >/dev/null 2>&1 || true
        pause
        ;;
      2) docker_global_status ;;
      3) docker_container_manage ;;
      4) docker_image_manage ;;
      5) docker_network_manage ;;
      6) docker_volume_manage ;;
      7) docker system prune -af --volumes; echo "Cleanup completed."; pause ;;
      8) docker_switch_mirror ;;
      9) docker_edit_daemon_json ;;
      11) docker_set_ipv6_mode on ;;
      12) docker_set_ipv6_mode off ;;
      19) docker_backup_restore_env ;;
      20) docker_uninstall_env ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

test_suite_menu() {
  while true; do
    show_header
    echo "Test Suite (SOPS)"
    echo "------------------------"
    echo "1. IP & Region Check"
    echo "2. Network Quality Quick Check"
    echo "3. System Benchmark Snapshot"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice test_choice "Please enter your choice: "
    case "${test_choice}" in
      1)
        show_header
        echo "Public IP: $(curl -fsSL --max-time 3 ipinfo.io/ip 2>/dev/null || echo unknown)"
        echo "Region: $(curl -fsSL --max-time 3 ipinfo.io/country 2>/dev/null || echo unknown) $(curl -fsSL --max-time 3 ipinfo.io/region 2>/dev/null || true)"
        pause
        ;;
      2)
        show_header
        ping -c 4 8.8.8.8 || true
        echo "------------------------"
        ss -s || true
        pause
        ;;
      3)
        show_header
        echo "Uptime: $(uptime -p 2>/dev/null || echo unknown)"
        echo "CPU: $(nproc 2>/dev/null || echo unknown) cores"
        free -h || true
        df -h / || true
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

ldnmp_menu() {
  require_root || return
  while true; do
    show_header
    echo "LDNMP Site Setup (SOPS)"
    echo "------------------------"
    echo "1. Install Nginx"
    echo "2. Install MariaDB"
    echo "3. Install PHP-FPM"
    echo "4. Install Full LDNMP"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice ldnmp_choice "Please enter your choice: "
    case "${ldnmp_choice}" in
      1) install_package_for_current_pm "nginx" "nginx" "nginx" "nginx" "nginx" "nginx" && echo "Nginx installed."; pause ;;
      2) install_package_for_current_pm "mariadb-server" "mariadb-server" "mariadb-server" "mariadb" "mariadb" "mariadb mariadb-client" && echo "MariaDB installed."; pause ;;
      3) install_package_for_current_pm "php-fpm php-cli php-mysql" "php-fpm php-cli php-mysqlnd" "php-fpm php-cli php-mysqlnd" "php8-fpm php8-cli php8-mysql" "php php-fpm" "php php-fpm php-mysqli" && echo "PHP-FPM installed."; pause ;;
      4)
        install_package_for_current_pm "nginx mariadb-server php-fpm php-cli php-mysql" "nginx mariadb-server php-fpm php-cli php-mysqlnd" "nginx mariadb-server php-fpm php-cli php-mysqlnd" "nginx mariadb php8-fpm php8-cli php8-mysql" "nginx mariadb php php-fpm" "nginx mariadb php php-fpm php-mysqli"
        echo "LDNMP package installation finished."
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

app_market_menu() {
  require_root || return
  while true; do
    show_header
    echo "App Market (SOPS)"
    echo "------------------------"
    echo "1. Install htop"
    echo "2. Install btop"
    echo "3. Install tmux"
    echo "4. Install git"
    echo "5. Install fail2ban"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice app_choice "Please enter your choice: "
    case "${app_choice}" in
      1) install_package_for_current_pm "htop" "htop" "htop" "htop" "htop" "htop" && echo "htop installed."; pause ;;
      2) install_package_for_current_pm "btop" "btop" "btop" "btop" "btop" "btop" && echo "btop installed."; pause ;;
      3) install_package_for_current_pm "tmux" "tmux" "tmux" "tmux" "tmux" "tmux" && echo "tmux installed."; pause ;;
      4) install_package_for_current_pm "git" "git" "git" "git" "git" "git" && echo "git installed."; pause ;;
      5) install_package_for_current_pm "fail2ban" "fail2ban" "fail2ban" "fail2ban" "fail2ban" "fail2ban" && echo "fail2ban installed."; pause ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

ensure_tmux_installed() {
  if command -v tmux >/dev/null 2>&1; then
    return 0
  fi
  require_root || return 1
  install_package_for_current_pm "tmux" "tmux" "tmux" "tmux" "tmux" "tmux" >/dev/null 2>&1 || true
  command -v tmux >/dev/null 2>&1
}

sops_ws_name() {
  local idx="$1"
  printf "ws%02d" "$idx"
}

workspace_ssh_resident_mode() {
  local bashrc="${HOME}/.bashrc"
  while true; do
    show_header
    echo "SSH Resident Mode"
    echo "------------------------"
    if grep -q "sops-auto-workspace" "$bashrc" 2>/dev/null; then
      echo "Status: enabled"
    else
      echo "Status: disabled"
    fi
    echo "1. Enable"
    echo "2. Disable"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice rm_choice "Please enter your choice: "
    case "$rm_choice" in
      1)
        ensure_tmux_installed || { echo "tmux install failed."; pause; continue; }
        sed -i '/# >>> sops-auto-workspace >>>/,/# <<< sops-auto-workspace <<</d' "$bashrc" 2>/dev/null || true
        cat >>"$bashrc" <<'EOF'
# >>> sops-auto-workspace >>>
if [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ] && command -v tmux >/dev/null 2>&1; then
  tmux has-session -t ws01 2>/dev/null || tmux new-session -d -s ws01
  exec tmux attach -t ws01
fi
# <<< sops-auto-workspace <<<
EOF
        echo "Enabled. Re-login via SSH to apply."
        pause
        ;;
      2)
        sed -i '/# >>> sops-auto-workspace >>>/,/# <<< sops-auto-workspace <<</d' "$bashrc" 2>/dev/null || true
        echo "Disabled."
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

workspace_create_or_enter() {
  ensure_tmux_installed || { echo "tmux install failed."; pause; return; }
  show_header
  echo "Create / Enter Workspace"
  echo "------------------------"
  read -r -p "Workspace name: " ws_name
  if ! [[ "$ws_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Invalid workspace name."
    pause
    return
  fi
  echo "Tip: detach with Ctrl+b then d"
  pause
  tmux new-session -A -s "$ws_name"
}

workspace_inject_command() {
  ensure_tmux_installed || { echo "tmux install failed."; pause; return; }
  show_header
  echo "Inject Command to Workspace"
  echo "------------------------"
  tmux ls 2>/dev/null || echo "No tmux sessions."
  echo "------------------------"
  read -r -p "Workspace name: " ws_name
  read -r -p "Command to run: " ws_cmd
  if [ -z "$ws_name" ] || [ -z "$ws_cmd" ]; then
    echo "Workspace name and command are required."
    pause
    return
  fi
  tmux has-session -t "$ws_name" 2>/dev/null || { echo "Workspace not found: $ws_name"; pause; return; }
  tmux send-keys -t "$ws_name" "$ws_cmd" C-m
  echo "Command injected."
  pause
}

workspace_delete_session() {
  ensure_tmux_installed || { echo "tmux install failed."; pause; return; }
  show_header
  echo "Delete Workspace"
  echo "------------------------"
  tmux ls 2>/dev/null || echo "No tmux sessions."
  echo "------------------------"
  read -r -p "Workspace name to delete: " ws_name
  if [ -z "$ws_name" ]; then
    echo "Workspace name is required."
    pause
    return
  fi
  tmux kill-session -t "$ws_name" 2>/dev/null || echo "Workspace not found."
  echo "Done."
  pause
}

workspace_menu() {
  while true; do
    show_header
    echo "Workspace (SOPS)"
    echo "Run long tasks in background. SSH disconnect will not stop jobs."
    echo "Tip: inside tmux press Ctrl+b then d to detach."
    echo "------------------------"
    echo "Current workspaces:"
    if ensure_tmux_installed; then
      tmux ls 2>/dev/null || echo "(none)"
    else
      echo "tmux not installed."
    fi
    echo "------------------------"
    echo " 1. Workspace-01                    2. Workspace-02"
    echo " 3. Workspace-03                    4. Workspace-04"
    echo " 5. Workspace-05                    6. Workspace-06"
    echo " 7. Workspace-07                    8. Workspace-08"
    echo " 9. Workspace-09                    10. Workspace-10"
    echo "------------------------"
    echo "21. SSH Resident Mode *"
    echo "22. Create/Enter Workspace"
    echo "23. Inject Command to Workspace"
    echo "24. Delete Workspace"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice ws_choice "Please enter your choice: "
    case "${ws_choice}" in
      1|2|3|4|5|6|7|8|9|10)
        ensure_tmux_installed || { echo "tmux install failed."; pause; continue; }
        ws_name="$(sops_ws_name "$ws_choice")"
        echo "Entering workspace: $ws_name"
        echo "Detach with Ctrl+b then d"
        pause
        tmux new-session -A -s "$ws_name"
        ;;
      21) workspace_ssh_resident_mode ;;
      22) workspace_create_or_enter ;;
      23) workspace_inject_command ;;
      24) workspace_delete_session ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

cluster_base_dir() {
  echo "${HOME}/.sops_cluster"
}

cluster_servers_file() {
  echo "$(cluster_base_dir)/servers.list"
}

cluster_ensure_env() {
  local d f
  d="$(cluster_base_dir)"
  f="$(cluster_servers_file)"
  mkdir -p "$d"
  touch "$f"
}

cluster_install_env() {
  require_root || return
  show_header
  echo "Install Cluster Environment"
  echo "------------------------"
  cluster_ensure_env
  install_package_for_current_pm "openssh-client rsync" "openssh-clients rsync" "openssh-clients rsync" "openssh rsync" "openssh rsync" "openssh-client rsync" >/dev/null 2>&1 || true
  echo "Cluster environment ready."
  echo "Servers file: $(cluster_servers_file)"
  echo "Format: name|host|port|user|key_path"
  pause
}

cluster_list_servers() {
  cluster_ensure_env
  local f
  f="$(cluster_servers_file)"
  if [ ! -s "$f" ]; then
    echo "(no servers)"
    return
  fi
  nl -ba "$f"
}

cluster_add_server() {
  cluster_ensure_env
  local name host port user key
  show_header
  echo "Add Cluster Server"
  echo "------------------------"
  read -r -p "Name: " name
  read -r -p "Host/IP: " host
  read_numeric_choice port "SSH Port: "
  read -r -p "SSH User: " user
  read -r -p "Key path (default ~/.ssh/id_ed25519): " key
  [ -z "$key" ] && key="${HOME}/.ssh/id_ed25519"
  if [ -z "$name" ] || [ -z "$host" ] || [ -z "$user" ]; then
    echo "Name/Host/User cannot be empty."
    pause
    return
  fi
  echo "${name}|${host}|${port}|${user}|${key}" >>"$(cluster_servers_file)"
  echo "Server added."
  pause
}

cluster_remove_server() {
  cluster_ensure_env
  show_header
  echo "Remove Cluster Server"
  echo "------------------------"
  cluster_list_servers
  echo "------------------------"
  read -r -p "Keyword to remove: " kw
  if [ -z "$kw" ]; then
    echo "Keyword cannot be empty."
    pause
    return
  fi
  sed -i "/$kw/d" "$(cluster_servers_file)"
  echo "Removed matched rows."
  pause
}

cluster_edit_servers() {
  cluster_ensure_env
  local f
  f="$(cluster_servers_file)"
  if command -v nano >/dev/null 2>&1; then
    nano "$f"
  elif command -v vi >/dev/null 2>&1; then
    vi "$f"
  else
    echo "No editor found. File: $f"
    pause
  fi
}

cluster_run_batch() {
  cluster_ensure_env
  local cmd="$1"
  local title="$2"
  local f
  f="$(cluster_servers_file)"
  show_header
  echo "$title"
  echo "------------------------"
  if [ ! -s "$f" ]; then
    echo "No servers configured."
    pause
    return
  fi

  while IFS='|' read -r name host port user key; do
    [ -z "${host:-}" ] && continue
    [ -z "${port:-}" ] && port=22
    [ -z "${user:-}" ] && user=root
    [ -z "${key:-}" ] && key="${HOME}/.ssh/id_ed25519"
    echo "[$name] ${user}@${host}:${port}"
    ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -i "$key" -p "$port" "${user}@${host}" "$cmd" </dev/null && echo "  -> OK" || echo "  -> FAILED"
    echo "------------------------"
  done <"$f"
  pause
}

cluster_push_sops() {
  cluster_ensure_env
  local f local_script
  f="$(cluster_servers_file)"
  local_script="${HOME}/sops.sh"
  show_header
  echo "Batch install/update SOPS (local push mode)"
  echo "------------------------"
  if [ ! -f "$local_script" ]; then
    echo "Local script not found: $local_script"
    pause
    return
  fi
  if [ ! -s "$f" ]; then
    echo "No servers configured."
    pause
    return
  fi

  while IFS='|' read -r name host port user key; do
    [ -z "${host:-}" ] && continue
    [ -z "${port:-}" ] && port=22
    [ -z "${user:-}" ] && user=root
    [ -z "${key:-}" ] && key="${HOME}/.ssh/id_ed25519"
    echo "[$name] ${user}@${host}:${port}"
    scp -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -i "$key" -P "$port" "$local_script" "${user}@${host}:~/sops.sh" </dev/null \
      && ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -i "$key" -p "$port" "${user}@${host}" "chmod +x ~/sops.sh && bash ~/sops.sh" </dev/null \
      && echo "  -> OK" || echo "  -> FAILED"
    echo "------------------------"
  done <"$f"
  pause
}

cluster_control_center() {
  while true; do
    show_header
    echo "Cluster Control Center"
    echo "------------------------"
    echo "Servers:"
    cluster_list_servers
    echo "------------------------"
    echo "1. Add server"
    echo "2. Remove server by keyword"
    echo "3. Edit servers list"
    echo "------------------------"
    echo "11. Batch install/update SOPS"
    echo "12. Batch system update"
    echo "13. Batch system cleanup"
    echo "14. Batch install Docker"
    echo "15. Batch enable BBR/BBR3"
    echo "16. Batch set 1024MB swap"
    echo "17. Batch set timezone Asia/Shanghai"
    echo "18. Batch close firewall (deny all incoming)"
    echo "------------------------"
    echo "51. Batch run custom command"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice cc "Please enter your choice: "
    case "$cc" in
      1) cluster_add_server ;;
      2) cluster_remove_server ;;
      3) cluster_edit_servers ;;
      11) cluster_push_sops ;;
      12) cluster_run_batch "apt-get update && apt-get -y upgrade || dnf -y upgrade --refresh || yum -y update || zypper --non-interactive update || pacman -Syu --noconfirm || apk upgrade" "Batch system update" ;;
      13) cluster_run_batch "apt-get -y autoremove --purge && apt-get -y clean || dnf -y autoremove && dnf -y clean all || yum -y autoremove && yum -y clean all || zypper --non-interactive clean --all || pacman -Sc --noconfirm || apk cache clean" "Batch system cleanup" ;;
      14) cluster_run_batch "apt-get update && apt-get install -y docker.io || dnf -y install docker || yum -y install docker || zypper --non-interactive in docker || pacman -Sy --noconfirm docker || apk add --no-cache docker; systemctl enable docker >/dev/null 2>&1 || true; systemctl start docker >/dev/null 2>&1 || true" "Batch install Docker" ;;
      15) cluster_run_batch "modprobe tcp_bbr 2>/dev/null || true; if sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr3; then sysctl -w net.core.default_qdisc=fq; sysctl -w net.ipv4.tcp_congestion_control=bbr3; else sysctl -w net.core.default_qdisc=fq; sysctl -w net.ipv4.tcp_congestion_control=bbr; fi" "Batch enable BBR/BBR3" ;;
      16) cluster_run_batch "swapoff -a 2>/dev/null || true; rm -f /swapfile; dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none; chmod 600 /swapfile; mkswap /swapfile >/dev/null; swapon /swapfile; grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab" "Batch set 1024MB swap" ;;
      17) cluster_run_batch "timedatectl set-timezone Asia/Shanghai 2>/dev/null || ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime" "Batch timezone set" ;;
      18) cluster_run_batch "ufw --force reset >/dev/null 2>&1 && ufw --force enable >/dev/null 2>&1 && ufw default deny incoming >/dev/null 2>&1 || (firewall-cmd --set-default-zone=drop >/dev/null 2>&1 && firewall-cmd --reload >/dev/null 2>&1) || (iptables -P INPUT DROP >/dev/null 2>&1)" "Batch close firewall" ;;
      51)
        show_header
        echo "Batch Custom Command"
        echo "------------------------"
        read -r -p "Command: " ccmd
        [ -n "$ccmd" ] && cluster_run_batch "$ccmd" "Batch custom command" || { echo "Command cannot be empty."; pause; }
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

cluster_backup_env() {
  cluster_ensure_env
  show_header
  echo "Backup Cluster Environment"
  echo "------------------------"
  local d bk
  d="$(cluster_base_dir)"
  bk="${d}/cluster-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  tar -czf "$bk" -C "$d" servers.list 2>/dev/null || true
  echo "Backup created: $bk"
  pause
}

cluster_restore_env() {
  cluster_ensure_env
  show_header
  echo "Restore Cluster Environment"
  echo "------------------------"
  ls -lh "$(cluster_base_dir)"/*.tar.gz 2>/dev/null || echo "No backup files found."
  read -r -p "Backup file path: " bk
  if [ ! -f "$bk" ]; then
    echo "Backup file not found."
    pause
    return
  fi
  tar -xzf "$bk" -C "$(cluster_base_dir)" 2>/dev/null || true
  echo "Restore complete."
  pause
}

cluster_uninstall_env() {
  require_root || return
  show_header
  echo "Uninstall Cluster Environment"
  echo "------------------------"
  read_numeric_choice yn "Confirm remove cluster workspace? (1=yes,0=no): "
  if [ "$yn" -ne 1 ]; then
    echo "Cancelled."
    pause
    return
  fi
  rm -rf "$(cluster_base_dir)"
  echo "Cluster workspace removed."
  pause
}

cluster_menu() {
  while true; do
    show_header
    echo "Server Cluster Control"
    echo "Remote control multiple VPS via SOPS local modules."
    echo "Supports key-based SSH batch operations."
    echo "------------------------"
    echo "1. Install cluster environment"
    echo "------------------------"
    echo "2. Cluster control center *"
    echo "------------------------"
    echo "7. Backup cluster environment"
    echo "8. Restore cluster environment"
    echo "9. Uninstall cluster environment"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice clu "Please enter your choice: "
    case "$clu" in
      1) cluster_install_env ;;
      2) cluster_control_center ;;
      7) cluster_backup_env ;;
      8) cluster_restore_env ;;
      9) cluster_uninstall_env ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

prosody_service_name() {
  if systemctl list-unit-files 2>/dev/null | grep -q '^prosody\.service'; then
    echo "prosody"
  else
    echo "prosody"
  fi
}

prosody_install() {
  require_root || return
  show_header

  local domain admin_user admin_pass admin_email svc
  local cfg_main cfg_domain cert_key cert_crt use_le

  echo "1. Preparation"
  read -r -p "Domain (e.g. xmpp.example.com): " domain
  if [ -z "$domain" ]; then
    echo "Domain cannot be empty."
    pause
    return
  fi

  read -r -p "Admin username (default: admin): " admin_user
  admin_user="${admin_user:-admin}"

  while true; do
    read -r -s -p "Admin password: " admin_pass
    echo
    [ -n "$admin_pass" ] && break
    echo "Password cannot be empty."
  done

  echo "2. Install Prosody"
  install_package_for_current_pm "prosody" "prosody" "prosody" "prosody" "prosody" "prosody" || true
  svc="$(prosody_service_name)"
  systemctl enable --now "$svc" >/dev/null 2>&1 || true

  echo "3. Trusted certificate (Let's Encrypt or CA cert)"
  echo "Port 80 must be reachable from the public Internet for Let's Encrypt standalone mode."
  read_numeric_choice use_le "Use Let's Encrypt now? (1=yes,0=no): "

  cert_key=""
  cert_crt=""

  if [ "$use_le" -eq 1 ]; then
    install_package_for_current_pm "certbot" "certbot" "certbot" "certbot" "certbot" "certbot" || true
    read -r -p "Email for Let's Encrypt (optional): " admin_email

    systemctl stop "$svc" >/dev/null 2>&1 || true
    if [ -n "$admin_email" ]; then
      certbot certonly --standalone -d "$domain" --non-interactive --agree-tos -m "$admin_email" --keep-until-expiring
    else
      certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --register-unsafely-without-email --keep-until-expiring
    fi
    systemctl start "$svc" >/dev/null 2>&1 || true

    cert_key="/etc/letsencrypt/live/${domain}/privkey.pem"
    cert_crt="/etc/letsencrypt/live/${domain}/fullchain.pem"
  fi

  if [ ! -s "$cert_key" ] || [ ! -s "$cert_crt" ]; then
    echo "Let's Encrypt not ready. Provide existing trusted CA cert paths."
    read -r -p "Private key path: " cert_key
    read -r -p "Full chain cert path: " cert_crt
  fi

  if [ ! -s "$cert_key" ] || [ ! -s "$cert_crt" ]; then
    echo "ERROR: Trusted certificate is required. Install aborted."
    pause
    return
  fi

  cfg_main="/etc/prosody/prosody.cfg.lua"
  cfg_domain="/etc/prosody/conf.d/${domain}.cfg.lua"
  mkdir -p /etc/prosody/conf.d >/dev/null 2>&1 || true

  cat >"$cfg_domain" <<EOF
admins = { "${admin_user}@${domain}" }

VirtualHost "${domain}"
    authentication = "internal_hashed"

    ssl = {
        key = "${cert_key}";
        certificate = "${cert_crt}";
    }

    modules_enabled = {
        "roster";
        "saslauth";
        "tls";
        "disco";
        "private";
        "pep";
        "vcard4";
    }

    c2s_require_encryption = false
EOF

  if [ -f "$cfg_main" ] && ! grep -q 'Include "conf.d/\*.cfg.lua"' "$cfg_main"; then
    printf '\nInclude "conf.d/*.cfg.lua"\n' >> "$cfg_main"
  fi

  prosodyctl register "$admin_user" "$domain" "$admin_pass" >/dev/null 2>&1 || true

  echo "4. Go-live checks"
  if ! prosodyctl check config; then
    echo "ERROR: config check failed."
    pause
    return
  fi

  systemctl restart "$svc" >/dev/null 2>&1 || true
  if systemctl is-active --quiet "$svc"; then
    echo "OK: Prosody is running with trusted certificate."
  else
    echo "ERROR: Prosody is not running. Check logs in Daily management."
    pause
    return
  fi

  echo "Configured domain: $domain"
  echo "Admin user: ${admin_user}@${domain}"
  echo "Config file: $cfg_domain"
  echo "Open ports: 5222 (client), 5269 (federation)."
  pause
}

prosody_config_lua() {
  require_root || return
  local cfg="/etc/prosody/prosody.cfg.lua"
  mkdir -p /etc/prosody >/dev/null 2>&1 || true
  touch "$cfg" >/dev/null 2>&1 || true
  if command -v nano >/dev/null 2>&1; then
    nano "$cfg"
  elif command -v vi >/dev/null 2>&1; then
    vi "$cfg"
  else
    echo "No editor found. File path: $cfg"
    pause
  fi
}

prosody_collect_user_jids() {
  local f user domain

  find /var/lib/prosody -type f -name '*.dat' 2>/dev/null | while read -r f; do
    user=""
    domain=""

    # Pattern A: .../prosody/<domain>/accounts/<user>.dat
    if [[ "$f" =~ /prosody/([^/]+)/accounts/([^/]+)\.dat$ ]]; then
      domain="${BASH_REMATCH[1]}"
      user="${BASH_REMATCH[2]}"
    # Pattern B: .../accounts/<domain>/<user>.dat
    elif [[ "$f" =~ /accounts/([^/]+)/([^/]+)\.dat$ ]]; then
      domain="${BASH_REMATCH[1]}"
      user="${BASH_REMATCH[2]}"
    # Pattern C: .../accounts/<user>@<domain>.dat
    elif [[ "$f" =~ /accounts/([^/]+)\.dat$ ]]; then
      user="${BASH_REMATCH[1]}"
    fi

    [ -z "$user" ] && continue

    if [[ "$user" == *@* ]]; then
      echo "$user"
    elif [ -n "$domain" ]; then
      echo "${user}@${domain}"
    fi
  done
}

PROSODY_SELECTED_JID=""
prosody_select_user_jid() {
  local prompt="$1"
  local pick
  local -a jids

  PROSODY_SELECTED_JID=""
  mapfile -t jids < <(prosody_collect_user_jids | sort -u)
  if [ "${#jids[@]}" -eq 0 ]; then
    echo "No Prosody users found."
    return 1
  fi

  echo "User list"
  echo "------------------------"
  local i=1
  for item in "${jids[@]}"; do
    echo "$i. $item"
    i=$((i+1))
  done
  echo "------------------------"

  read_numeric_choice pick "$prompt"
  if [ "$pick" -eq 0 ]; then
    return 1
  fi
  if [ "$pick" -lt 1 ] || [ "$pick" -gt "${#jids[@]}" ]; then
    echo "Invalid number."
    return 1
  fi

  PROSODY_SELECTED_JID="${jids[$((pick-1))]}"
  return 0
}
prosody_daily_manage() {
  require_root || return
  while true; do
    show_header
    local svc
    svc="$(prosody_service_name)"
    echo "Prosody Daily Management"
    echo "------------------------"
    echo "Service: $svc"
    echo "1. Start service"
    echo "2. Stop service"
    echo "3. Restart service"
    echo "4. Service status"
    echo "5. View latest log"
    echo "6. Follow live log"
    echo "7. Check config"
    echo "8. Add user"
    echo "9. Change user password"
    echo "10. Delete user"
    echo "11. Renew Let's Encrypt cert"
    echo "12. Open main config"
    echo "13. Open domain config"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice pmg "Please enter your choice: "
    case "$pmg" in
      1) systemctl start "$svc"; echo "Started."; pause ;;
      2) systemctl stop "$svc"; echo "Stopped."; pause ;;
      3) systemctl restart "$svc"; echo "Restarted."; pause ;;
      4) systemctl status "$svc" --no-pager; pause ;;
      5) journalctl -u "$svc" -n 100 --no-pager; pause ;;
      6) journalctl -u "$svc" -f ;;
      7) prosodyctl check config; pause ;;
      8)
        local u d p
        read -r -p "Username: " u
        read -r -p "Domain: " d
        read -r -s -p "Password: " p
        echo
        if [ -n "$u" ] && [ -n "$d" ] && [ -n "$p" ]; then
          prosodyctl register "$u" "$d" "$p"
        else
          echo "Invalid input."
        fi
        pause
        ;;
      9)
        if prosody_select_user_jid 'Select user number for password change (0 cancel): '; then
          prosodyctl passwd "$PROSODY_SELECTED_JID"
        fi
        pause
        ;;
      10)
        if prosody_select_user_jid 'Select user number to delete (0 cancel): '; then
          read_numeric_choice yn "Confirm delete $PROSODY_SELECTED_JID? (1=yes,0=no): "
          if [ "$yn" -eq 1 ]; then
            prosodyctl deluser "$PROSODY_SELECTED_JID"
          else
            echo "Cancelled."
          fi
        fi
        pause
        ;;
      11)
        if command -v certbot >/dev/null 2>&1; then
          certbot renew
          systemctl restart "$svc" >/dev/null 2>&1 || true
        else
          echo "certbot not found."
        fi
        pause
        ;;
      12)
        local cfg_main="/etc/prosody/prosody.cfg.lua"
        if command -v nano >/dev/null 2>&1; then nano "$cfg_main";
        elif command -v vi >/dev/null 2>&1; then vi "$cfg_main";
        else echo "No editor found: $cfg_main"; pause; fi
        ;;
      13)
        local dcfg
        read -r -p "Domain (e.g. xmpp.example.com): " dcfg
        local cfg_domain="/etc/prosody/conf.d/${dcfg}.cfg.lua"
        if [ -z "$dcfg" ]; then
          echo "Domain cannot be empty."
          pause
        elif [ ! -f "$cfg_domain" ]; then
          echo "Domain config not found: $cfg_domain"
          pause
        else
          if command -v nano >/dev/null 2>&1; then nano "$cfg_domain";
          elif command -v vi >/dev/null 2>&1; then vi "$cfg_domain";
          else echo "No editor found: $cfg_domain"; pause; fi
        fi
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

prosody_menu() {
  while true; do
    show_header
    echo "Prosody"
    echo "------------------------"
    echo "1. Install Prosody"
    echo "2. Daily management"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice pro_choice "Please enter your choice: "
    case "$pro_choice" in
      1) prosody_install ;;
      2) prosody_daily_manage ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

xmpp_menu() {
  while true; do
    show_header
    echo "XMPP"
    echo "------------------------"
    echo "server daemon"
    echo "1. Prosody"
    echo "2. ejabberd"
    echo "3. Openfire"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice xmpp_choice "Please enter your choice: "
    case "$xmpp_choice" in
      1) prosody_menu ;;
      2) coturn_menu ;;
      3) coming_soon_main ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

jitsi_install_and_debug() {
  require_root || return
  show_header

  local domain email
  local s_prosody s_jicofo s_jvb s_nginx

  echo "Jitsi Install & Debug"
  echo "------------------------"
  read -r -p "Jitsi domain (e.g. meet.example.com): " domain
  if [ -z "$domain" ]; then
    echo "Domain cannot be empty."
    pause
    return
  fi
  read -r -p "Email for Let's Encrypt (optional): " email

  if [ -f /etc/debian_version ]; then
    install_package_for_current_pm "apt-transport-https" "apt-transport-https" "apt-transport-https" "apt-transport-https" "apt-transport-https" "apt-transport-https" || true
    install_package_for_current_pm "gnupg" "gnupg" "gnupg" "gnupg" "gnupg" "gnupg" || true
    install_package_for_current_pm "curl" "curl" "curl" "curl" "curl" "curl" || true

    curl -fsSL https://download.jitsi.org/jitsi-key.gpg.key | gpg --dearmor >/usr/share/keyrings/jitsi-keyring.gpg 2>/dev/null || true
    cat >/etc/apt/sources.list.d/jitsi-stable.list <<EOF

deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/
EOF
    apt-get update -y || true

    DEBIAN_FRONTEND=noninteractive apt-get install -y jitsi-meet || true

    if [ -n "$email" ] && [ -x /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh ]; then
      /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh <<EOF
$email
EOF
    fi

    systemctl restart prosody jicofo jitsi-videobridge2 nginx 2>/dev/null || true

    s_prosody="$(systemctl is-active prosody 2>/dev/null || echo unknown)"
    s_jicofo="$(systemctl is-active jicofo 2>/dev/null || echo unknown)"
    s_jvb="$(systemctl is-active jitsi-videobridge2 2>/dev/null || echo unknown)"
    s_nginx="$(systemctl is-active nginx 2>/dev/null || echo unknown)"

    echo "Debug summary"
    echo "------------------------"
    echo "prosody: $s_prosody"
    echo "jicofo: $s_jicofo"
    echo "jvb: $s_jvb"
    echo "nginx: $s_nginx"
    ss -ltnup 2>/dev/null | grep -E ':443 |:10000 ' || true
    echo "Open URL: https://$domain"
  else
    echo "This installer currently targets Debian/Ubuntu family only."
  fi
  pause
}

jitsi_daily_manage() {
  require_root || return
  while true; do
    show_header
    echo "Jitsi Daily Management"
    echo "------------------------"
    echo "1. Restart all Jitsi services"
    echo "2. Service status overview"
    echo "3. Show recent logs"
    echo "4. Follow JVB live log"
    echo "5. Check listening ports"
    echo "6. Renew Let's Encrypt cert"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice jm "Please enter your choice: "
    case "$jm" in
      1) systemctl restart prosody jicofo jitsi-videobridge2 nginx 2>/dev/null || true; echo "Restart done."; pause ;;
      2)
        echo "prosody: $(systemctl is-active prosody 2>/dev/null || echo unknown)"
        echo "jicofo: $(systemctl is-active jicofo 2>/dev/null || echo unknown)"
        echo "jvb: $(systemctl is-active jitsi-videobridge2 2>/dev/null || echo unknown)"
        echo "nginx: $(systemctl is-active nginx 2>/dev/null || echo unknown)"
        pause
        ;;
      3)
        journalctl -u prosody -u jicofo -u jitsi-videobridge2 -u nginx -n 120 --no-pager
        pause
        ;;
      4) journalctl -u jitsi-videobridge2 -f ;;
      5) ss -ltnup 2>/dev/null | grep -E ':80 |:443 |:10000 |:3478 |:5349 ' || true; pause ;;
      6)
        if command -v certbot >/dev/null 2>&1; then
          certbot renew
          systemctl restart nginx prosody jicofo jitsi-videobridge2 2>/dev/null || true
        else
          echo "certbot not found."
        fi
        pause
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

jitsi_menu() {
  while true; do
    show_header
    echo "Jitsi"
    echo "------------------------"
    echo "1. Install and debug Jitsi"
    echo "2. Daily management"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice jitsi_choice "Please enter your choice: "
    case "$jitsi_choice" in
      1) jitsi_install_and_debug ;;
      2) jitsi_daily_manage ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

coturn_install_and_debug() {
  require_root || return
  show_header

  local turn_domain turn_user turn_pass link_jitsi jitsi_domain
  local cfg="/etc/turnserver.conf"

  echo "Coturn Install & Debug"
  echo "------------------------"
  read -r -p "TURN domain/IP (e.g. turn.example.com): " turn_domain
  if [ -z "$turn_domain" ]; then
    echo "TURN domain/IP cannot be empty."
    pause
    return
  fi

  read -r -p "TURN username (default: turnuser): " turn_user
  turn_user="${turn_user:-turnuser}"

  while true; do
    read -r -s -p "TURN password: " turn_pass
    echo
    [ -n "$turn_pass" ] && break
    echo "Password cannot be empty."
  done

  install_package_for_current_pm "coturn" "coturn" "coturn" "coturn" "coturn" "coturn" || true

  if [ -f /etc/default/coturn ]; then
    sed -i 's/^#\?TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn
  fi

  cat >"$cfg" <<EOF
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
fingerprint
use-auth-secret
static-auth-secret=$(openssl rand -hex 16)
realm=${turn_domain}
total-quota=100
stale-nonce=600
no-multicast-peers
no-loopback-peers
cert=/etc/ssl/certs/ssl-cert-snakeoil.pem
pkey=/etc/ssl/private/ssl-cert-snakeoil.key
log-file=/var/log/turnserver.log
simple-log
EOF

  # add static user as fallback
  echo "user=${turn_user}:${turn_pass}" >> "$cfg"

  systemctl enable --now coturn >/dev/null 2>&1 || true
  systemctl restart coturn >/dev/null 2>&1 || true

  echo "Debug summary"
  echo "------------------------"
  echo "coturn: $(systemctl is-active coturn 2>/dev/null || echo unknown)"
  ss -ltnup 2>/dev/null | grep -E ':3478 |:5349 ' || true

  read_numeric_choice link_jitsi "Configure quick Jitsi linkage now? (1=yes,0=no): "
  if [ "$link_jitsi" -eq 1 ]; then
    read -r -p "Jitsi domain (e.g. meet.example.com): " jitsi_domain
    local jitsi_cfg="/etc/jitsi/meet/${jitsi_domain}-config.js"
    if [ -f "$jitsi_cfg" ]; then
      if ! grep -q 'SOPS_COTURN_LINK_BEGIN' "$jitsi_cfg"; then
        cat >>"$jitsi_cfg" <<EOF

// SOPS_COTURN_LINK_BEGIN
if (typeof config !== 'undefined') {
  config.p2p = config.p2p || {};
  config.p2p.useStunTurn = true;
  config.p2p.stunServers = [
    { urls: 'stun:${turn_domain}:3478' },
    { urls: 'turn:${turn_domain}:3478?transport=udp', username: '${turn_user}', credential: '${turn_pass}' }
  ];
}
// SOPS_COTURN_LINK_END
EOF
      fi
      systemctl restart nginx 2>/dev/null || true
      echo "Jitsi linkage snippet added: $jitsi_cfg"
    else
      echo "Jitsi config not found: $jitsi_cfg"
      echo "You can link later from daily management by editing config manually."
    fi
  fi

  pause
}

coturn_daily_manage() {
  require_root || return
  while true; do
    show_header
    echo "Coturn Daily Management"
    echo "------------------------"
    echo "1. Start service"
    echo "2. Stop service"
    echo "3. Restart service"
    echo "4. Service status"
    echo "5. View latest log"
    echo "6. Follow live log"
    echo "7. Check listening ports"
    echo "8. Open turnserver config"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice ct "Please enter your choice: "
    case "$ct" in
      1) systemctl start coturn; echo "Started."; pause ;;
      2) systemctl stop coturn; echo "Stopped."; pause ;;
      3) systemctl restart coturn; echo "Restarted."; pause ;;
      4) systemctl status coturn --no-pager; pause ;;
      5) journalctl -u coturn -n 120 --no-pager; pause ;;
      6) journalctl -u coturn -f ;;
      7) ss -ltnup 2>/dev/null | grep -E ':3478 |:5349 ' || true; pause ;;
      8)
        local cfg="/etc/turnserver.conf"
        if command -v nano >/dev/null 2>&1; then nano "$cfg";
        elif command -v vi >/dev/null 2>&1; then vi "$cfg";
        else echo "No editor found: $cfg"; pause; fi
        ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

coturn_menu() {
  while true; do
    show_header
    echo "Coturn"
    echo "------------------------"
    echo "1. Install and debug Coturn"
    echo "2. Daily management"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice coturn_choice "Please enter your choice: "
    case "$coturn_choice" in
      1) coturn_install_and_debug ;;
      2) coturn_daily_manage ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}
webrtc_menu() {
  while true; do
    show_header
    echo "WebRTC"
    echo "------------------------"
    echo "1. Jitsi"
    echo "2. Coturn"
    echo "3. Diagnostics"
    echo "------------------------"
    echo -e "${yellow}0. RTM${white}"
    echo "------------------------"
    read_numeric_choice rtc_choice "Please enter your choice: "
    case "$rtc_choice" in
      1) jitsi_menu ;;
      2) coturn_menu ;;
      3) coming_soon_main ;;
      0) return ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

show_main_menu() {
  echo "1.  System Operations"
  echo "2.  Basic Tools"
  echo "3.  BBR Management"
  echo "4.  Docker Management"
  echo "5.  Test Suite"
  echo "6.  LDNMP Site Setup"
  echo "7.  App Market"
  echo "8.  Workspace"
  echo "9.  Server Cluster Control"
  echo "10. WebRTC"
  echo "11. XMPP"
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
    read_numeric_choice choice "Please enter your choice: "
    case "${choice}" in
      1) system_operations_menu ;;
      2) base_tools_menu ;;
      3) bbr_menu ;;
      4) docker_menu ;;
      5) test_suite_menu ;;
      6) ldnmp_menu ;;
      7) app_market_menu ;;
      8) workspace_menu ;;
      9) cluster_menu ;;
      10) webrtc_menu ;;
      11) xmpp_menu ;;
      00) update_script ;;
      0) exit 0 ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

main "$@"










