#!/usr/bin/env bash
set -euo pipefail

sh_v="0.1.0"

cyan='"'"'\033[96m'"'"'
white='"'"'\033[0m'"'"'

pause() {
  read -r -p "Press Enter to continue..." _
}

show_header() {
  clear
  echo -e "${cyan}SOPS Script Toolbox v${sh_v}${white}"
  echo "------------------------"
}

show_menu() {
  echo "1) System info"
  echo "2) Check updates"
  echo "0) Exit"
  echo "------------------------"
}

system_info() {
  echo "Hostname: $(hostname)"
  echo "Kernel:   $(uname -srmo 2>/dev/null || uname -a)"
}

check_updates() {
  echo "Current version: v${sh_v}"
  echo "Update source: https://raw.githubusercontent.com/stone086/sops/main/sops.sh"
}

main() {
  while true; do
    show_header
    show_menu
    read -r -p "Please enter your choice: " choice
    case "${choice}" in
      1) show_header; system_info; pause ;;
      2) show_header; check_updates; pause ;;
      0) exit 0 ;;
      *) echo "Invalid choice"; pause ;;
    esac
  done
}

main "$@"