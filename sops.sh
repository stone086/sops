#!/usr/bin/env bash
set -euo pipefail

sh_v="0.1.2"

cyan='\033[96m'
green='\033[32m'
yellow='\033[33m'
white='\033[0m'

pause() {
  echo
  read -r -n 1 -s -p "按任意键继续..."
  echo
}

show_header() {
  clear
  echo -e "${cyan}SOPS Script Toolbox v${sh_v}${white}"
  echo "------------------------"
}

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "该功能需要 root 权限。"
    pause
    return 1
  fi
  return 0
}

to_human() {
  local bytes="${1:-0}"
  awk -v b="$bytes" 'BEGIN{
    split("B KB MB GB TB",u," ");
    i=1;
    while (b>=1024 && i<5){b/=1024;i++}
    if (i==1) printf "%.0f%s", b, u[i];
    else printf "%.2f%s", b, u[i];
  }'
}

percent() {
  local used="$1" total="$2"
  if [ "${total:-0}" -eq 0 ]; then
    echo "0.00%"
  else
    awk -v u="$used" -v t="$total" 'BEGIN{printf "%.2f%%", (u/t)*100}'
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
    awk -v di="$diff_idle" -v dt="$diff_total" 'BEGIN{printf "%.0f%%", (1-di/dt)*100}'
  fi
}

system_query() {
  show_header
  echo "系统信息查询"
  echo "-------------"

  local host os_pretty kernel
  host="$(hostname)"
  os_pretty="$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
  [ -z "$os_pretty" ] && os_pretty="Unknown"
  kernel="$(uname -r)"

  echo "主机名：        ${host}"
  echo "系统版本：      ${os_pretty}"
  echo "Linux版本：     ${kernel}"
  echo "-------------"

  local cpu_arch cpu_model cpu_cores cpu_freq
  cpu_arch="$(uname -m)"
  cpu_model="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
  [ -z "$cpu_model" ] && cpu_model="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^[ \t]*//')"
  [ -z "$cpu_model" ] && cpu_model="Unknown"
  cpu_cores="$(nproc 2>/dev/null || echo 0)"
  cpu_freq="$(lscpu 2>/dev/null | awk -F: '/CPU MHz/ {gsub(/^[ \t]+/,"",$2); printf "%.1f MHz",$2; exit}')"
  [ -z "$cpu_freq" ] && cpu_freq="Unknown"

  echo "CPU架构：       ${cpu_arch}"
  echo "CPU型号：       ${cpu_model}"
  echo "CPU核心数：     ${cpu_cores}"
  echo "CPU频率：       ${cpu_freq}"
  echo "-------------"

  local cpu_usage load_avg tcp_conn udp_conn
  cpu_usage="$(cpu_usage_percent)"
  load_avg="$(awk '{print $1", "$2", "$3}' /proc/loadavg)"
  tcp_conn="$(ss -ant 2>/dev/null | awk 'NR>1 {c++} END{print c+0}')"
  udp_conn="$(ss -anu 2>/dev/null | awk 'NR>1 {c++} END{print c+0}')"

  echo "CPU占用：       ${cpu_usage}"
  echo "系统负载：      ${load_avg}"
  echo "TCP/UDP连接数： ${tcp_conn}|${udp_conn}"

  local mem_total mem_used swap_total swap_used
  mem_total="$(free -b | awk '/^Mem:/ {print $2}')"
  mem_used="$(free -b | awk '/^Mem:/ {print $3}')"
  swap_total="$(free -b | awk '/^Swap:/ {print $2}')"
  swap_used="$(free -b | awk '/^Swap:/ {print $3}')"

  echo "物理内存：      $(to_human "$mem_used")/$(to_human "$mem_total") ($(percent "$mem_used" "$mem_total"))"
  echo "虚拟内存：      $(to_human "$swap_used")/$(to_human "$swap_total") ($(percent "$swap_used" "$swap_total"))"

  local disk_total disk_used
  disk_total="$(df -B1 / | awk 'NR==2 {print $2}')"
  disk_used="$(df -B1 / | awk 'NR==2 {print $3}')"
  echo "硬盘占用：      $(to_human "$disk_used")/$(to_human "$disk_total") ($(percent "$disk_used" "$disk_total"))"
  echo "-------------"

  local rx_total tx_total
  rx_total="$(awk -F'[: ]+' 'NR>2 {rx+=$3} END{print rx+0}' /proc/net/dev)"
  tx_total="$(awk -F'[: ]+' 'NR>2 {tx+=$11} END{print tx+0}' /proc/net/dev)"
  echo "总接收：        $(to_human "$rx_total")"
  echo "总发送：        $(to_human "$tx_total")"
  echo "-------------"

  local cc qdisc
  cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
  echo "网络算法：      ${cc} ${qdisc}"
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

  echo "运营商：        ${org:-Unknown}"
  echo "IPv4地址：      ${ip:-Unknown}"
  echo "DNS地址：       ${dns:-Unknown}"
  echo "地理位置：      ${country:-Unknown} ${region:-} ${city:-}"
  echo "系统时间：      ${tz}  ${now}"
  echo "-------------"

  local up
  up="$(uptime -p 2>/dev/null | sed 's/^up //')"
  [ -z "$up" ] && up="Unknown"
  echo "运行时长：      ${up}"
  echo
  echo -e "${green}操作完成${white}"
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
  echo "系统更新"
  echo "------------------------"

  local cmd
  cmd="$(detect_update_cmd)"
  if [ -z "$cmd" ]; then
    echo "未识别到受支持的包管理器，无法自动更新。"
    pause
    return
  fi

  echo "将执行更新命令："
  echo "$cmd"
  echo "------------------------"
  read -r -p "确认执行更新？(y/N): " yn
  case "${yn}" in
    y|Y)
      echo "开始更新..."
      bash -lc "$cmd"
      echo "更新完成。"
      pause
      return
      ;;
    *)
      echo "已取消更新。"
      pause
      return
      ;;
  esac
}

system_cleanup() {
  require_root || return
  show_header
  echo "系统清理"
  echo "------------------------"
  echo "将执行：缓存清理、无用依赖清理、日志/临时文件清理（安全版）"
  read -r -p "确认执行清理？(y/N): " yn
  case "${yn}" in
    y|Y) ;;
    *) echo "已取消清理。"; pause; return ;;
  esac

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

  echo "系统清理完成。"
  pause
}

system_operations_menu() {
  while true; do
    show_header
    echo "系统操作"
    echo "------------------------"
    echo "1. 系统查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "0. 返回主菜单"
    echo "------------------------"
    read -r -p "请输入你的选择： " sub_choice
    case "${sub_choice}" in
      1) system_query ;;
      2) system_update ;;
      3) system_cleanup ;;
      0) return ;;
      *) echo "无效选择"; pause ;;
    esac
  done
}

show_main_menu() {
  echo "1.  系统操作"
  echo "2.  静等开发中...."
  echo "3.  静等开发中...."
  echo "4.  静等开发中...."
  echo "5.  静等开发中...."
  echo "6.  静等开发中...."
  echo "7.  静等开发中...."
  echo "8.  静等开发中...."
  echo "9.  静等开发中...."
  echo "10. 静等开发中...."
  echo "11. 静等开发中...."
  echo "12. 静等开发中...."
  echo "13. 静等开发中...."
  echo "14. 静等开发中...."
  echo "15. 静等开发中...."
  echo "16. 静等开发中...."
  echo "------------------------"
  echo "00. 脚本更新"
  echo "------------------------"
  echo "0.  退出脚本"
  echo "------------------------"
}

update_script() {
  local url="https://raw.githubusercontent.com/stone086/sops/main/sops.sh"
  echo "正在更新脚本..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "${HOME}/sops.sh"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${HOME}/sops.sh" "$url"
  else
    echo "更新失败：未找到 curl/wget"
    pause
    return 1
  fi
  chmod +x "${HOME}/sops.sh"
  echo "脚本更新完成。"
  pause
}

main() {
  while true; do
    show_header
    show_main_menu
    read -r -p "请输入你的选择： " choice
    case "${choice}" in
      1) system_operations_menu ;;
      2|3|4|5|6|7|8|9|10|11|12|13|14|15|16)
        show_header
        echo "静等开发中...."
        pause
        ;;
      00) show_header; update_script ;;
      0) exit 0 ;;
      *) echo "无效选择"; pause ;;
    esac
  done
}

main "$@"
