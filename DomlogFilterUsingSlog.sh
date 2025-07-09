#!/bin/bash
#
# DomlogFilterUsingSlog.sh
# Version 1.2
#
# Description: Analyze Apache domlogs for a cPanel user by detecting main and addon domains.
#
# Author: Harish Nischal
# Repository: https://github.com/harish-nischal/scriptforce
# Script: https://github.com/harish-nischal/scriptforce/raw/main/DomlogFilterUsingSlog.sh
#
# Usage:  bash <(wget -qO - https://github.com/harish-nischal/scriptforce/raw/main/DomlogFilterUsingSlog.sh) MainDomain

#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ $# -ne 1 ]; then
  echo -e "${YELLOW}Usage:${NC} $0 <main_domain>"
  exit 1
fi

MAIN_DOMAIN="$1"

# Fetch addon subdomains
echo -e "${CYAN}Fetching addon domains for ${MAIN_DOMAIN}...${NC}"
ADDON_SUBS=$(sudo acctinfo --listaddons "$MAIN_DOMAIN" 2>/dev/null | grep -oP 'Sub: \K\S+')

# Build list of domains
DOMAINS=("$MAIN_DOMAIN")
for SUB in $ADDON_SUBS; do
  DOMAINS+=("$SUB")
done

# Show domain list
echo -e "${GREEN}Available domains:${NC}"
echo -e "${CYAN}0)${NC} All domains"
i=1
for DOMAIN in "${DOMAINS[@]}"; do
  echo -e "${CYAN}$i)${NC} $DOMAIN"
  ((i++))
done

# Ask user to select
echo ""
read -p "$(echo -e ${YELLOW}Select domain number to process logs:${NC} )" CHOICE

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 0 ] || [ "$CHOICE" -gt "${#DOMAINS[@]}" ]; then
  echo -e "${RED}❌ Invalid choice. Exiting.${NC}"
  exit 1
fi

# Build processing list
if [ "$CHOICE" -eq 0 ]; then
  echo -e "✅ ${GREEN}Selected:${NC} All domains"
  SELECTED_DOMAINS=("${DOMAINS[@]}")
else
  SELECTED_DOMAIN="${DOMAINS[$((CHOICE-1))]}"
  echo -e "✅ ${GREEN}Selected:${NC} $SELECTED_DOMAIN"
  SELECTED_DOMAINS=("$SELECTED_DOMAIN")
fi

# Function to process logs for a domain
process_logs_for_domain() {
  local DOMAIN="$1"

  for LOGPATH in "/usr/local/apache/domlogs/$DOMAIN" "/usr/local/apache/domlogs/${DOMAIN}-ssl_log"; do
    if [ ! -f "$LOGPATH" ]; then
      echo -e "${YELLOW}⚠ No log file: $LOGPATH${NC}"
      continue
    fi

    echo ""
    echo -e "${CYAN}==============================================${NC}"
    echo -e "${CYAN}Processing log: $LOGPATH${NC}"
    echo -e "${CYAN}==============================================${NC}"

    DATES=$(sudo slog cat "$LOGPATH" 2>/dev/null | grep -h -oP '^\d{1,3}(\.\d{1,3}){3} \S+ \S+ \[\K[0-9]{2}/\w{3}/[0-9]{4}' | sort | uniq)

    if [ -z "$DATES" ]; then
      echo -e "${YELLOW}No valid log data in $LOGPATH${NC}"
      continue
    fi

    echo -e "${GREEN}Available dates:${NC}"
    echo "$DATES"

    for DATE in $(echo "$DATES" | tac); do
      echo ""
      echo -e "${YELLOW}***** Stats for $DOMAIN :: $DATE *****${NC}"

      TMPFILE=$(mktemp)
      sudo slog cat "$LOGPATH" | grep "\[$DATE" > "$TMPFILE"

      if [ ! -s "$TMPFILE" ]; then
        echo -e "${YELLOW}No data for $DATE in $LOGPATH${NC}"
        rm -f "$TMPFILE"
        continue
      fi

      TOTAL_HITS=$(wc -l < "$TMPFILE")
      echo -e "${CYAN}Total hits for $DATE: ${GREEN}$TOTAL_HITS${NC}"

      echo ""
      echo -e "${GREEN}Top 10 IPs:${NC}"
      awk '{print $1}' "$TMPFILE" | sort | uniq -c | sort -nr | head -10

      echo ""
      echo -e "${GREEN}Top 10 requested scripts:${NC}"
      awk '{print $7}' "$TMPFILE" | sort | uniq -c | sort -nr | head -10

      echo ""
      echo -e "${GREEN}Top crawler hits:${NC}"
      grep -iE 'googlebot|bingbot|slurp|baiduspider|yandex' "$TMPFILE" | \
      awk -F\" '{print $1, $6}' | \
      sed -E 's/.*(Googlebot|Bingbot|Slurp|Baiduspider|Yandex).*/\1/i' | \
      paste -d' ' <(grep -iE 'googlebot|bingbot|slurp|baiduspider|yandex' "$TMPFILE" | awk '{print $1}') - | \
      sort | uniq -c | sort -nr | head -10

      rm -f "$TMPFILE"
    done
  done
}

# Loop through selected domains
for DOMAIN in "${SELECTED_DOMAINS[@]}"; do
  process_logs_for_domain "$DOMAIN"
done
