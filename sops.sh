#!/usr/bin/env bash
set -euo pipefail

sh_v="0.1.3"

cyan='\033[96m'
green='\033[32m'
white='\033[0m'

pause() {
  echo
  read -r -n 1 -s -p "闁圭顦幑銏ゅ箛韫囨稒鏆涚紓浣堝懐鏁?.."
  echo
}

show_header() {
  clear
  echo -e "${cyan}SOPS Script Toolbox v${sh_v}${white}"
  echo "------------------------"
}

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "閻犲洢鍎辨慨娑㈡嚄娴犲浠橀悷?root 闁哄鍟村娲Υ?
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
  echo "缂侇垵宕电划鐑樼┍閳╁啩绱栭柡灞诲劥椤?
  echo "-------------"

  local host os_pretty kernel
  host="$(hostname)"
  os_pretty="$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
  [ -z "$os_pretty" ] && os_pretty="Unknown"
  kernel="$(uname -r)"

  echo "濞戞挾绮┃鈧柛?        ${host}"
  echo "缂侇垵宕电划娲偋閸喐鎷?      ${os_pretty}"
  echo "Linux闁绘鐗婂﹢?     ${kernel}"
  echo "-------------"

  local cpu_arch cpu_model cpu_cores cpu_freq
  cpu_arch="$(uname -m)"
  cpu_model="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
  [ -z "$cpu_model" ] && cpu_model="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^[ \t]*//')"
  [ -z "$cpu_model" ] && cpu_model="Unknown"
  cpu_cores="$(nproc 2>/dev/null || echo 0)"
  cpu_freq="$(lscpu 2>/dev/null | awk -F: '/CPU MHz/ {gsub(/^[ \t]+/,"",$2); printf "%.1f MHz",$2; exit}')"
  [ -z "$cpu_freq" ] && cpu_freq="Unknown"

  echo "CPU闁哄鍩栭悗?       ${cpu_arch}"
  echo "CPU闁搞劌顑呰ぐ?       ${cpu_model}"
  echo "CPU闁哄秶顭堢缓楣冨极?     ${cpu_cores}"
  echo "CPU濡増鍨瑰?       ${cpu_freq}"
  echo "-------------"

  local cpu_usage load_avg tcp_conn udp_conn
  cpu_usage="$(cpu_usage_percent)"
  load_avg="$(awk '{print $1", "$2", "$3}' /proc/loadavg)"
  tcp_conn="$(ss -ant 2>/dev/null | awk 'NR>1 {c++} END{print c+0}')"
  udp_conn="$(ss -anu 2>/dev/null | awk 'NR>1 {c++} END{print c+0}')"

  echo "CPU闁告濮烽弫?       ${cpu_usage}"
  echo "缂侇垵宕电划铏规嫻閻旂粯绁?      ${load_avg}"
  echo "TCP/UDP閺夆晝鍋炵敮鎾极? ${tcp_conn}|${udp_conn}"

  local mem_total mem_used swap_total swap_used
  mem_total="$(free -b | awk '/^Mem:/ {print $2}')"
  mem_used="$(free -b | awk '/^Mem:/ {print $3}')"
  swap_total="$(free -b | awk '/^Swap:/ {print $2}')"
  swap_used="$(free -b | awk '/^Swap:/ {print $3}')"

  echo "闁绘せ鏅濋幃濠囧礃閸涱厾鎽?      $(to_human "$mem_used")/$(to_human "$mem_total") ($(percent "$mem_used" "$mem_total"))"
  echo "闁惧繑纰嶇€氭瑩宕橀崨顓犳憼:      $(to_human "$swap_used")/$(to_human "$swap_total") ($(percent "$swap_used" "$swap_total"))"

  local disk_total disk_used
  disk_total="$(df -B1 / | awk 'NR==2 {print $2}')"
  disk_used="$(df -B1 / | awk 'NR==2 {print $3}')"
  echo "缁绢収鍓涘ú蹇涘础閻樺灚鏆?      $(to_human "$disk_used")/$(to_human "$disk_total") ($(percent "$disk_used" "$disk_total"))"
  echo "-------------"

  local rx_total tx_total
  rx_total="$(awk -F'[: ]+' 'NR>2 {rx+=$3} END{print rx+0}' /proc/net/dev)"
  tx_total="$(awk -F'[: ]+' 'NR>2 {tx+=$11} END{print tx+0}' /proc/net/dev)"
  echo "闁诡剛绮敮鎾绩?        $(to_human "$rx_total")"
  echo "闁诡剝顕цぐ鍌炴焻?        $(to_human "$tx_total")"
  echo "-------------"

  local cc qdisc
  cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
  echo "缂傚啯鍨圭划鍓佺不濡や胶銆?      ${cc} ${qdisc}"
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

  echo "閺夆晜鍔橀幆鈧柛?        ${org:-Unknown}"
  echo "IPv4闁革附婢樺?      ${ip:-Unknown}"
  echo "DNS闁革附婢樺?       ${dns:-Unknown}"
  echo "闁革附澹嗛幃濠冩媴瀹ュ洨鏋?      ${country:-Unknown} ${region:-} ${city:-}"
  echo "缂侇垵宕电划娲籍閸洘锛?      ${tz}  ${now}"
  echo "-------------"

  local up
  up="$(uptime -p 2>/dev/null | sed 's/^up //')"
  [ -z "$up" ] && up="Unknown"
  echo "閺夆晜鍔橀、鎴﹀籍閸洘姣?      ${up}"
  echo
  echo -e "${green}闁瑰灝绉崇紞鏃傗偓鐟版湰閸?{white}"
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
  echo "缂侇垵宕电划娲即鐎涙ɑ鐓€"
  echo "------------------------"

  local cmd
  cmd="$(detect_update_cmd)"
  if [ -z "$cmd" ]; then
    echo "闁哄牜浜ｉ惁鎴﹀礆椤愩垹鐓傞柡鈧娑樼槷闁汇劌瀚€垫绮婚敍鍕€為柛锝庣厜缁辨繈寮悩宕囥€婇柤濂変簻婵晠寮寸€涙ɑ鐓€闁?
    pause
    return
  fi

  echo "閻忓繐妫欐晶鐣屾偘鐏炵偓绾柡鍌涙緲閹斥剝绂?"
  echo "$cmd"
  echo "------------------------"
  bash -lc "$cmd"
  echo "闁哄洤鐡ㄩ弻濠勨偓鐟版湰閸ㄦ岸濡?
  pause
}

system_cleanup() {
  require_root || return
  show_header
  echo "缂侇垵宕电划鍝勩€掗崨顖涘€?
  echo "------------------------"
  echo "闁煎浜滄慨鈺呭箥瑜戦、鎴犵磽閹惧磭鎽犻柕鍡曠劍濡倝鎮介妸銈囪穿閻犙勭墦閳ь兛鐒﹀Λ鈺勭疀濡も偓閹风増绋夌€涙ɑ顦ч柡鍌氭矗濞嗐垹銆掗崨顖涘€為柕?

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

  echo "缂侇垵宕电划鍝勩€掗崨顖涘€為悗鐟版湰閸ㄦ岸濡?
  pause
}

system_operations_menu() {
  while true; do
    show_header
    echo "缂侇垵宕电划娲箼瀹ュ嫮绋?
    echo "------------------------"
    echo "1. 缂侇垵宕电划娲蓟閵夘煈鍤?
    echo "2. 缂侇垵宕电划娲即鐎涙ɑ鐓€"
    echo "3. 缂侇垵宕电划鍝勩€掗崨顖涘€?
    echo "------------------------"
    echo "0. 閺夆晜鏌ㄥú鏍ㄧ▔閺勫繐缍呴柛?
    echo "------------------------"
    read -r -p "閻犲洨鏌夌欢顓㈠礂閵夈倗绋戦柣銊ュ閳ь剙顦扮€? " sub_choice
    case "${sub_choice}" in
      1) system_query ;;
      2) system_update ;;
      3) system_cleanup ;;
      0) return ;;
      *) echo "闁哄啰濮甸弲銉╂焻婢跺顏?; pause ;;
    esac
  done
}

base_tools_menu() {
  while true; do
    show_header
    echo "閸╄櫣顢呭銉ュ徔"
    echo "------------------------"
    echo "1. 闂堟瑧鐡戝鈧崣鎴滆厬...."
    echo "------------------------"
    echo "0. 鏉╂柨娲栨稉鏄忓綅閸?
    echo "------------------------"
    read -r -p "鐠囩柉绶崗銉ょ稑閻ㄥ嫰鈧瀚? " bt_choice
    case "${bt_choice}" in
      1)
        show_header
        echo "闂堟瑧鐡戝鈧崣鎴滆厬...."
        pause
        ;;
      0) return ;;
      *) echo "閺冪姵鏅ラ柅澶嬪"; pause ;;
    esac
  done
}

show_main_menu() {
  echo "1.  缁崵绮洪幙宥勭稊"
  echo "2.  閸╄櫣顢呭銉ュ徔"
  echo "------------------------"
  echo "00. 閼存碍婀伴弴瀛樻煀"
  echo "------------------------"
  echo "0.  闁偓閸戦缚鍓奸張?
  echo "------------------------"
}
update_script() {
  show_header
  echo "闁艰鲸姊荤紞澶愬即鐎涙ɑ鐓€闁煎瓨纰嶅﹢鐗堢▔?.."

  local update_url tmp_file target_file
  update_url="https://raw.githubusercontent.com/stone086/sops/main/sops.sh"
  tmp_file="/tmp/sops.sh.$$"
  target_file="${HOME}/sops.sh"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$update_url" -o "$tmp_file"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp_file" "$update_url"
  else
    echo "闁哄牜浜濋ˉ鍛圭€ｎ亜鐓?curl/wget闁挎稑鏈Λ銈呪枖閺団€茬矒缂傚啯鍨跺ú鍧楀棘閼割兘鍋?
    pause
    return
  fi

  if [ ! -s "$tmp_file" ]; then
    echo "濞戞挸顑堝ù鍥ㄥ緞鏉堫偉袝闁挎稒纰嶅ú鍧楀棘閻楀牊鐎ù鐘虫构鐠愮喓绮氶幁鎺嗗亾?
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

  echo "鐎规瓕寮撶划?GitHub 闁哄洤鐡ㄩ弻濠勨偓鐟版湰閸ㄦ岸鏁嶇仦缁㈠妧闁革负鍔戦崳鎼佸触椤栨繂澹栭柡?.."
  exec bash "$target_file"
}

main() {
  while true; do
    show_header
    show_main_menu
    read -r -p "閻犲洨鏌夌欢顓㈠礂閵夈倗绋戦柣銊ュ閳ь剙顦扮€? " choice
    case "${choice}" in
      1) system_operations_menu ;;
      2) base_tools_menu ;;
      00) update_script ;;
      0) exit 0 ;;
      *) echo "无效选择"; pause ;;
    esac
  done
}

main "$@"