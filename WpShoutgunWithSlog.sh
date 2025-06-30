#!/bin/bash
## Author: Harish Nischal
## https://github.com/harish-nischal/scriptforce/raw/main/WpShoutgunWithSlog.sh
## Objective: Filter logs with limited access. Trying to make slog easy to use
##
## How to use:
## ./WpShoutgunWithSlog.sh cPanelPrimaryDomain
## 
## Or run via:
## bash <(wget -qO - https://github.com/harish-nischal/scriptforce/raw/main/WpShoutgunWithSlog.sh) cPanelPrimaryDomain

#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if main domain is provided
if [ $# -ne 1 ]; then
  echo -e "${YELLOW}Usage: $0 <main_domain>${NC}"
  exit 1
fi

MAIN_DOMAIN="$1"

# Fetch addon subdomains
echo -e "${CYAN}Fetching addon domains for ${MAIN_DOMAIN}...${NC}"
ADDON_SUBS=$(sudo acctinfo --listaddons "$MAIN_DOMAIN" 2>/dev/null | grep -oP 'Sub: \K\S+')

# Build domain list
DOMAINS=("$MAIN_DOMAIN")
for AD in $ADDON_SUBS; do
  DOMAINS+=("$AD")
done

# Prompt user to select domain or all
echo -e "${GREEN}Select a domain to analyze logs for:${NC}"
for i in "${!DOMAINS[@]}"; do
  echo -e "${CYAN}$((i+1)). ${DOMAINS[$i]}${NC}"
done
echo -e "${CYAN}$(( ${#DOMAINS[@]} + 1 )). All domains${NC}"
read -p "Enter choice number: " CHOICE

SELECTED_DOMAINS=()
if [[ "$CHOICE" -eq $(( ${#DOMAINS[@]} + 1 )) ]]; then
  SELECTED_DOMAINS=("${DOMAINS[@]}")
elif [[ "$CHOICE" -ge 1 && "$CHOICE" -le "${#DOMAINS[@]}" ]]; then
  SELECTED_DOMAINS=("${DOMAINS[$((CHOICE - 1))]}")
else
  echo -e "${RED}❌ Invalid selection.${NC}"
  exit 1
fi

# Loop through selected domains
for DOMAIN in "${SELECTED_DOMAINS[@]}"; do
  echo -e "\n${BLUE}Checking logs for: $DOMAIN${NC}"
  LOGFILES=()
  [ -f "/usr/local/apache/domlogs/$DOMAIN" ] && LOGFILES+=("/usr/local/apache/domlogs/$DOMAIN")
  [ -f "/usr/local/apache/domlogs/${DOMAIN}-ssl_log" ] && LOGFILES+=("/usr/local/apache/domlogs/${DOMAIN}-ssl_log")

  if [ ${#LOGFILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠ No log files found for $DOMAIN${NC}"
    continue
  fi

  # Collect all dates
  DATES_SET=()
  for LOGFILE in "${LOGFILES[@]}"; do
    DATES=$(sudo slog cat "$LOGFILE" | awk {'print$4'} | cut -d: -f1 | sed 's/\[//' | sort | uniq)
    DATES_SET+=($DATES)
  done

  UNIQUE_DATES=($(echo "${DATES_SET[@]}" | tr ' ' '\n' | sort -u))

  if [ ${#UNIQUE_DATES[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠ No dates found in logs for $DOMAIN${NC}"
    continue
  fi

  if [ ${#UNIQUE_DATES[@]} -eq 1 ]; then
    SELECTED_DATE="${UNIQUE_DATES[0]}"
    echo -e "${GREEN}Using available date: $SELECTED_DATE${NC}"
  else
    echo -e "${GREEN}Select date to filter logs for ${DOMAIN}:${NC}"
    for i in "${!UNIQUE_DATES[@]}"; do
      echo -e "${CYAN}$((i+1)). ${UNIQUE_DATES[$i]}${NC}"
    done
    read -p "Enter date choice number: " DATE_CHOICE
    if [[ "$DATE_CHOICE" -ge 1 && "$DATE_CHOICE" -le "${#UNIQUE_DATES[@]}" ]]; then
      SELECTED_DATE="${UNIQUE_DATES[$((DATE_CHOICE - 1))]}"
    else
      echo -e "${RED}❌ Invalid date selection.${NC}"
      exit 1
    fi
  fi

  for LOGFILE in "${LOGFILES[@]}"; do
    echo -e "\n${BLUE}=============================="
    echo -e "Details for: ${LOGFILE}"
    echo -e "Date: ${SELECTED_DATE}"
    echo -e "==============================${NC}"

    TOTAL_XMLRPC=$(sudo slog grep "$LOGFILE" "$SELECTED_DATE" | grep -c "xmlrpc\.php")
    echo -e "${GREEN}- xmlrpc.php requests: ${TOTAL_XMLRPC}${NC}"
    sudo slog grep "$LOGFILE" "$SELECTED_DATE" | grep "xmlrpc\.php" | awk '{print $1}' | sort | uniq -c | sort -n | tail

    # wp-cron.php
    TOTAL_WPCRON=$(sudo slog grep "$LOGFILE" "$SELECTED_DATE" | grep -c "wp-cron\.php")
    echo -e "${GREEN}- wp-cron.php requests: ${TOTAL_WPCRON}${NC}"
    sudo slog grep "$LOGFILE" "$SELECTED_DATE" | grep "wp-cron\.php" | awk '{print $1}' | sort | uniq -c | sort -n | tail

    # wp-login.php
    TOTAL_WPLOGIN=$(sudo slog grep "$LOGFILE" "$SELECTED_DATE" | grep -c "wp-login\.php")
    echo -e "${GREEN}- wp-login.php requests: ${TOTAL_WPLOGIN}${NC}"
    sudo slog grep "$LOGFILE" "$SELECTED_DATE" | grep "wp-login\.php" | awk '{print $1}' | sort | uniq -c | sort -n | tail

    # admin-ajax.php
    TOTAL_AJAX=$(sudo slog grep "$LOGFILE" "$SELECTED_DATE"| grep -c "admin-ajax\.php")
    echo -e "${GREEN}- admin-ajax.php requests: ${TOTAL_AJAX}${NC}"
    sudo slog grep "$LOGFILE" "$SELECTED_DATE" | grep "admin-ajax\.php" | awk '{print $1}' | sort | uniq -c | sort -n | tail


  done
done

echo -e "\n${RED}⚠ WARNING: OUTPUT IS NOT INTENDED FOR CUSTOMER REPLIES${NC}"
