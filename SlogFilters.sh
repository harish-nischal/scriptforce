#!/bin/bash
## Author: Harish Nischal
## https://github.com/harish-nischal/scriptforce/raw/main/SlogFilters.sh
## Objective: Filter logs with limited access. Trying to make slog easy to use
##
## How to use:
## ./SlogFilters.sh
## 
## Or run via:
## bash <(wget -qO - https://github.com/harish-nischal/scriptforce/raw/main/SlogFilters.sh) 

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# Show log type menu
show_log_menu() {
  echo -e "${GREEN}Select log file type:${RESET}"
  echo "1) Exim mainlog (/var/log/exim_mainlog)"
  echo "2) Apache error log (/etc/apache2/logs/error_log)"
  echo "3) cPanel error log (/usr/local/cpanel/logs/error_log)"
  echo "4) cPanel access log (/usr/local/cpanel/logs/access_log)"
}

# Show command menu
show_command_menu() {
  echo -e "${GREEN}Select command:${RESET}"
  echo "1) tailf"
  echo "2) cat"
  echo "3) tail"
  echo "4) head"
  echo "5) grep"
}

# Get log file path based on selection
get_log_path() {
  case $1 in
    1) echo "/var/log/exim_mainlog" ;;
    2) echo "/etc/apache2/logs/error_log" ;;
    3) echo "/usr/local/cpanel/logs/error_log" ;;
    4) echo "/usr/local/cpanel/logs/access_log" ;;
  esac
}

# Get command string
get_command() {
  case $1 in
    1) echo "tailf" ;;
    2) echo "cat" ;;
    3) echo "tail" ;;
    4) echo "head" ;;
    5) echo "grep" ;;
  esac
}

# Get valid log selection
get_valid_log_selection() {
  while true; do
    show_log_menu
    read -p "$(echo -e ${GREEN}Enter the number of the log type:${RESET} ) " LOGNUM
    case $LOGNUM in
      1|2|3|4) break ;;
      *) echo -e "${YELLOW}Invalid selection. Please try again.${RESET}" ;;
    esac
  done
}

# Get valid command selection
get_valid_command_selection() {
  while true; do
    show_command_menu
    read -p "$(echo -e ${GREEN}Enter the number of the command:${RESET} ) " CMDNUM
    case $CMDNUM in
      1|2|3|4|5) break ;;
      *) echo -e "${YELLOW}Invalid selection. Please try again.${RESET}" ;;
    esac
  done
}

# Main flow
get_valid_log_selection
LOGFILE=$(get_log_path "$LOGNUM")

get_valid_command_selection
COMMAND=$(get_command "$CMDNUM")

PATTERN=""
if [[ "$COMMAND" == "grep" ]]; then
  read -p "Enter search pattern: " PATTERN
fi

# Run the appropriate command
case "$COMMAND" in
  tailf)
    sudo slog tailf "$LOGFILE"
    ;;
  cat)
    sudo slog cat "$LOGFILE"
    ;;
  tail)
    sudo slog tail "$LOGFILE"
    ;;
  head)
    sudo slog head "$LOGFILE"
    ;;
  grep)
    sudo slog grep "$LOGFILE" "$PATTERN"
    ;;
esac
