#!/bin/bash
## Author: Harish Nischal
## https://github.com/harish-nischal/scriptforce/raw/main/cPanelPasswordChangeLogs.sh
## Objective: Find cPanel user password change events from relevant logs
##
## How to use:
## ./cPanelPasswordChangeLogs.sh <username>
## Example:
## ./cPanelPasswordChangeLogs.sh exampleuserbob
## Or run via:
## bash <(curl -s https://github.com/harish-nischal/scriptforce/raw/main/cPanelPasswordChangeLogs.sh) exampleuserbob

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

OUTPUT_FILE="${HOMEDIR}/${USERNAME}-cPanelPasswordChangeLogs.txt"

sudo touch "$OUTPUT_FILE"
sudo chown "${USERNAME}:${USERNAME}" "$OUTPUT_FILE"

LOG_FILES=(
  "/usr/local/cpanel/logs/access_log"
  "/usr/local/cpanel/logs/session_log"
)

echo -e "\e[36mYou can optionally filter by date (e.g. 29/Jun/2025). Leave empty for all dates.\e[0m"
read -rp "Date filter: " DATE_FILTER

echo -e "\e[1;34m$CURRENTDATE\e[0m"
echo -e "\e[1;35m=============================================================\e[0m"
echo -e "\e[1;32mSearching for password change events for user: $USERNAME\e[0m"

main_function() {
  for LOG in "${LOG_FILES[@]}"; do
    echo -e "\n\e[1;33mLog file: $LOG\e[0m"
    if [[ -n "$DATE_FILTER" ]]; then
      sudo grep "$USERNAME" "$LOG" | grep -i "passwd" | grep "$DATE_FILTER" || echo -e "\e[33mNo records found for date $DATE_FILTER.\e[0m"
    else
      sudo grep "$USERNAME" "$LOG" | grep -i "passwd" || echo -e "\e[33mNo records found.\e[0m"
    fi
  done
  echo -e "\n\e[1;35m=============================================================\e[0m"
  echo -e "\e[1;34mResults saved to ${OUTPUT_FILE}\e[0m"
}

main_function 2>&1 | tee -a "${OUTPUT_FILE}"
