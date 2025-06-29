#!/bin/bash
## Author: Harish Nischal
## https://github.com/harish-nischal/scriptforce/raw/main/cPanelUserActivity.sh
## Objective: Find cPanel user's login records and activities with date filtering and color output
##
## How to use:
## ./cPanelUserActivity.sh <username>
## Example:
## ./cPanelUserActivity.sh exampleuserbob
## Or run via:
## bash <(wget -qO - https://github.com/harish-nischal/scriptforce/raw/main/cPanelUserActivity.sh) exampleuserbob

if [[ -z "$1" ]]; then
  echo -e "\e[31mUsage: $0 <cPanel-username>\e[0m"
  exit 1
fi

USERNAME=$1
CURRENTDATE=$(date +"%Y-%m-%d %T")
HOMEDIR=$(getent passwd "$USERNAME" | cut -d: -f6)

if [[ -z "$HOMEDIR" ]]; then
  echo -e "\e[31mUser '$USERNAME' does not exist.\e[0m"
  exit 1
fi

OUTPUT_FILE="${HOMEDIR}/${USERNAME}-cPanelUserActivity.txt"

sudo touch "$OUTPUT_FILE"
sudo chown "${USERNAME}:${USERNAME}" "$OUTPUT_FILE"

declare -A log_paths
log_paths["cpsrvd"]="/usr/local/cpanel/logs/login_log"
log_paths["ssh_sftp"]="/var/log/secure"
log_paths["cpanel_access"]="/usr/local/cpanel/logs/access_log"
log_paths["cpanel_session"]="/usr/local/cpanel/logs/session_log"
log_paths["ftp"]="/usr/local/apache/domlogs/ftpxferlog"

echo -e "\e[36mWhich logs do you want to check? Separate choices by space.\e[0m"
echo -e "\e[33mAvailable: cpsrvd ssh_sftp cpanel_access cpanel_session ftp all\e[0m"
read -rp "Your choice: " USER_CHOICE

if [[ "$USER_CHOICE" == "all" ]]; then
  USER_CHOICE="cpsrvd ssh_sftp cpanel_access cpanel_session ftp"
fi

read -rp $'\e[36mEnter date filter (e.g. 29/Jun/2025 or leave empty for all dates): \e[0m' DATE_FILTER

log_section() {
  local title="$1"
  local path="$2"
  echo -e "\n\e[1;35m=============================================================\e[0m"
  echo -e "\e[1;32m$title\e[0m"
  echo ""
  if [[ -n "$DATE_FILTER" ]]; then
    sudo grep "$USERNAME" "$path" | grep "$DATE_FILTER" || echo -e "\e[33mNo records found for date $DATE_FILTER.\e[0m"
  else
    sudo grep "$USERNAME" "$path" || echo -e "\e[33mNo records found.\e[0m"
  fi
}

main_function() {
  echo -e "\e[1;34m$CURRENTDATE\e[0m"
  for choice in $USER_CHOICE; do
    case $choice in
      cpsrvd)
        log_section "cpsrvd login attempts" "${log_paths[cpsrvd]}"
        ;;
      ssh_sftp)
        log_section "SSH/SFTP login attempts" "${log_paths[ssh_sftp]}"
        ;;
      cpanel_access)
        log_section "cPanel access records" "${log_paths[cpanel_access]}"
        ;;
      cpanel_session)
        log_section "cPanel session activities" "${log_paths[cpanel_session]}"
        ;;
      ftp)
        log_section "FTP logs" "${log_paths[ftp]}"
        ;;
      *)
        echo -e "\e[31mUnknown choice: $choice\e[0m"
        ;;
    esac
  done
  echo -e "\n\e[1;35m=============================================================\e[0m"
  echo -e "\e[1;34mContents have been saved to ${OUTPUT_FILE}\e[0m"
}

# Run and log
main_function 2>&1 | tee -a "${OUTPUT_FILE}"
