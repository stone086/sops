#!/usr/bin/env bash
set -euo pipefail

sh_v="0.1.0"

cyan='"'"'\033[96m'"'"'
white='"'"'\033[0m'"'"'

pause() {
  read -r -p "按回车继续..." _
}

show_header() {
  clear
  echo -e "${cyan}SOPS Script Toolbox v${sh_v}${white}"
  echo "------------------------"
}

show_menu() {
  echo "1) 系统操作"
  echo "2) 静等开发中...."
  echo "3) 静等开发中...."
  echo "4) 静等开发中...."
  echo "5) 静等开发中...."
  echo "6) 静等开发中...."
  echo "7) 静等开发中...."
  echo "8) 静等开发中...."
  echo "9) 静等开发中...."
  echo "10) 静等开发中...."
  echo "11) 静等开发中...."
  echo "12) 静等开发中...."
  echo "13) 静等开发中...."
  echo "14) 静等开发中...."
  echo "15) 静等开发中...."
  echo "16) 静等开发中...."
  echo "0) 退出"
  echo "------------------------"
}

system_operations() {
  echo "系统信息:"
  echo "Hostname: $(hostname)"
  echo "Kernel:   $(uname -srmo 2>/dev/null || uname -a)"
}

main() {
  while true; do
    show_header
    show_menu
    read -r -p "请输入你的选择: " choice
    case "${choice}" in
      1) show_header; system_operations; pause ;;
      2|3|4|5|6|7|8|9|10|11|12|13|14|15|16)
        show_header
        echo "静等开发中...."
        pause
        ;;
      0) exit 0 ;;
      *) echo "无效选择"; pause ;;
    esac
  done
}

main "$@"
