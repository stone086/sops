#!/usr/bin/env bash
set -euo pipefail

sh_v="0.1.2"

cyan='\033[96m'
green='\033[32m'
yellow='\033[33m'
white='\033[0m'

pause() {
  echo
  read -r -n 1 -s -p "閹稿鎹㈤幇蹇涙暛缂佈呯敾..."
  echo
}

show_header() {
  clear
  echo -e "${cyan}SOPS Script Toolbox v${sh_v}${white}"
  echo "------------------------"
}

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "鐠囥儱濮涢懗浠嬫付鐟?root 閺夊啴妾洪妴?
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
  echo "缁崵绮烘穱鈩冧紖閺屻儴顕?
  echo "-------------"

  local host os_pretty kernel
  host="$(hostname)"
  os_pretty="$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
  [ -z "$os_pretty" ] && os_pretty="Unknown"
  kernel="$(uname -r)"

  echo "娑撶粯婧€閸氬稄绱?       ${host}"
  echo "缁崵绮洪悧鍫熸拱閿?     ${os_pretty}"
  echo "Linux閻楀牊婀伴敍?    ${kernel}"
  echo "-------------"

  local cpu_arch cpu_model cpu_cores cpu_freq
  cpu_arch="$(uname -m)"
  cpu_model="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
  [ -z "$cpu_model" ] && cpu_model="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^[ \t]*//')"
  [ -z "$cpu_model" ] && cpu_model="Unknown"
  cpu_cores="$(nproc 2>/dev/null || echo 0)"
  cpu_freq="$(lscpu 2>/dev/null | awk -F: '/CPU MHz/ {gsub(/^[ \t]+/,"",$2); printf "%.1f MHz",$2; exit}')"
  [ -z "$cpu_freq" ] && cpu_freq="Unknown"

  echo "CPU閺嬭埖鐎敍?      ${cpu_arch}"
  echo "CPU閸ㄥ褰块敍?      ${cpu_model}"
  echo "CPU閺嶇绺鹃弫甯窗     ${cpu_cores}"
  echo "CPU妫版垹宸奸敍?      ${cpu_freq}"
  echo "-------------"

  local cpu_usage load_avg tcp_conn udp_conn
  cpu_usage="$(cpu_usage_percent)"
  load_avg="$(awk '{print $1", "$2", "$3}' /proc/loadavg)"
  tcp_conn="$(ss -ant 2>/dev/null | awk 'NR>1 {c++} END{print c+0}')"
  udp_conn="$(ss -anu 2>/dev/null | awk 'NR>1 {c++} END{print c+0}')"

  echo "CPU閸楃姷鏁ら敍?      ${cpu_usage}"
  echo "缁崵绮虹拹鐔绘祰閿?     ${load_avg}"
  echo "TCP/UDP鏉╃偞甯撮弫甯窗 ${tcp_conn}|${udp_conn}"

  local mem_total mem_used swap_total swap_used
  mem_total="$(free -b | awk '/^Mem:/ {print $2}')"
  mem_used="$(free -b | awk '/^Mem:/ {print $3}')"
  swap_total="$(free -b | awk '/^Swap:/ {print $2}')"
  swap_used="$(free -b | awk '/^Swap:/ {print $3}')"

  echo "閻椻晝鎮婇崘鍛摠閿?     $(to_human "$mem_used")/$(to_human "$mem_total") ($(percent "$mem_used" "$mem_total"))"
  echo "閾忔碍瀚欓崘鍛摠閿?     $(to_human "$swap_used")/$(to_human "$swap_total") ($(percent "$swap_used" "$swap_total"))"

  local disk_total disk_used
  disk_total="$(df -B1 / | awk 'NR==2 {print $2}')"
  disk_used="$(df -B1 / | awk 'NR==2 {print $3}')"
  echo "绾剛娲忛崡鐘垫暏閿?     $(to_human "$disk_used")/$(to_human "$disk_total") ($(percent "$disk_used" "$disk_total"))"
  echo "-------------"

  local rx_total tx_total
  rx_total="$(awk -F'[: ]+' 'NR>2 {rx+=$3} END{print rx+0}' /proc/net/dev)"
  tx_total="$(awk -F'[: ]+' 'NR>2 {tx+=$11} END{print tx+0}' /proc/net/dev)"
  echo "閹粯甯撮弨璁圭窗        $(to_human "$rx_total")"
  echo "閹褰傞柅渚婄窗        $(to_human "$tx_total")"
  echo "-------------"

  local cc qdisc
  cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
  echo "缂冩垹绮剁粻妤佺《閿?     ${cc} ${qdisc}"
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

  echo "鏉╂劘鎯€閸熷棴绱?       ${org:-Unknown}"
  echo "IPv4閸︽澘娼冮敍?     ${ip:-Unknown}"
  echo "DNS閸︽澘娼冮敍?      ${dns:-Unknown}"
  echo "閸︽壆鎮婃担宥囩枂閿?     ${country:-Unknown} ${region:-} ${city:-}"
  echo "缁崵绮洪弮鍫曟？閿?     ${tz}  ${now}"
  echo "-------------"

  local up
  up="$(uptime -p 2>/dev/null | sed 's/^up //')"
  [ -z "$up" ] && up="Unknown"
  echo "鏉╂劘顢戦弮鍫曟毐閿?     ${up}"
  echo
  echo -e "${green}閹垮秳缍旂€瑰本鍨?{white}"
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
  echo "缁崵绮洪弴瀛樻煀"
  echo "------------------------"

  local cmd
  cmd="$(detect_update_cmd)"
  if [ -z "$cmd" ]; then
    echo "閺堫亣鐦戦崚顐㈠煂閸欐鏁幐浣烘畱閸栧懐顓搁悶鍡楁珤閿涘本妫ゅ▔鏇″殰閸斻劍娲块弬鑸偓?
    pause
    return
  fi

  echo "鐏忓棙澧界悰灞炬纯閺傛澘鎳℃禒銈忕窗"
  echo "$cmd"
  echo "------------------------"
  echo "瀵偓婵娲块弬?.."
  bash -lc "$cmd"
  echo "閺囧瓨鏌婄€瑰本鍨氶妴?
  pause
  return
}

system_cleanup() {
  require_root || return
  show_header
  echo "缁崵绮哄〒鍛倞"
  echo "------------------------"
  echo "鐏忓棙澧界悰宀嬬窗缂傛挸鐡ㄥ〒鍛倞閵嗕焦妫ら悽銊ょ贩鐠ф牗绔婚悶鍡愨偓浣规）韫?娑撳瓨妞傞弬鍥︽濞撳懐鎮婇敍鍫濈暔閸忋劎澧楅敍?
  echo "瀵偓婵绔婚悶?.."

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

  echo "缁崵绮哄〒鍛倞鐎瑰本鍨氶妴?
  pause
}

system_operations_menu() {
  while true; do
    show_header
    echo "缁崵绮洪幙宥勭稊"
    echo "------------------------"
    echo "1. 缁崵绮洪弻銉嚄"
    echo "2. 缁崵绮洪弴瀛樻煀"
    echo "3. 缁崵绮哄〒鍛倞"
    echo "------------------------"
    echo "0. 鏉╂柨娲栨稉鏄忓綅閸?
    echo "------------------------"
    read -r -p "鐠囩柉绶崗銉ょ稑閻ㄥ嫰鈧瀚ㄩ敍?" sub_choice
    case "${sub_choice}" in
      1) system_query ;;
      2) system_update ;;
      3) system_cleanup ;;
      0) return ;;
      *) echo "閺冪姵鏅ラ柅澶嬪"; pause ;;
    esac
  done
}

show_main_menu() {
  echo "1.  缁崵绮洪幙宥勭稊"
  echo "2.  闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "3.  闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "4.  闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "5.  闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "6.  闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "7.  闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "8.  闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "9.  闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "10. 闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "11. 闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "12. 闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "13. 闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "14. 闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "15. 闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "16. 闂堟瑧鐡戝鈧崣鎴滆厬...."
  echo "------------------------"
  echo "00. 閼存碍婀伴弴瀛樻煀"
  echo "------------------------"
  echo "0.  闁偓閸戦缚鍓奸張?
  echo "------------------------"
}

update_script() {
  echo "Updating script from GitHub..."

  local update_url tmp_file target_file
  update_url="https://raw.githubusercontent.com/stone086/sops/main/sops.sh"
  tmp_file="/tmp/sops.sh.$"
  target_file="${HOME}/sops.sh"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$update_url" -o "$tmp_file"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp_file" "$update_url"
  else
    echo "curl/wget not found, cannot update online."
    pause
    return
  fi

  if [ ! -s "$tmp_file" ]; then
    echo "Download failed: empty update file."
    rm -f "$tmp_file" 2>/dev/null || true
    pause
    return
  fi

  mv -f "$tmp_file" "$target_file"
  chmod +x "$target_file" 2>/dev/null || true

  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    cp -f "$target_file" /usr/local/bin/s 2>/dev/null || true
    ln -sf /usr/local/bin/s /usr/bin/s 2>/dev/null || true
  fi

  echo "Updated from GitHub successfully."
  pause
}

main() {
  while true; do
    show_header
    show_main_menu
    read -r -p "鐠囩柉绶崗銉ょ稑閻ㄥ嫰鈧瀚ㄩ敍?" choice
    case "${choice}" in
      1) system_operations_menu ;;
      2|3|4|5|6|7|8|9|10|11|12|13|14|15|16)
        show_header
        echo "闂堟瑧鐡戝鈧崣鎴滆厬...."
        pause
        ;;
      00) show_header; update_script ;;
      0) exit 0 ;;
      *) echo "閺冪姵鏅ラ柅澶嬪"; pause ;;
    esac
  done
}

main "$@"
