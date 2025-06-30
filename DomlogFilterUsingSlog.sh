#!/bin/bash

# Color codes
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

CPUSER=$(whoami)
ACCESS_LOGS_DIR="/home/${CPUSER}/access-logs"

if [[ ! -d "$ACCESS_LOGS_DIR" ]]; then
  echo -e "${RED}Error:${RESET} Directory $ACCESS_LOGS_DIR does not exist for user: $CPUSER"
  exit 1
fi

# List available domlog files
echo -e "${CYAN}============================"
echo -e "Domlog files for user: ${BOLD}${CPUSER}${RESET}${CYAN}"
echo -e "============================${RESET}"

LOGFILES=()
INDEX=1
for file in "$ACCESS_LOGS_DIR"/*; do
  if [[ -f "$file" ]]; then
    FILENAME=$(basename "$file")
    echo -e "${YELLOW}${INDEX})${RESET} $FILENAME"
    LOGFILES+=("$FILENAME")
    INDEX=$((INDEX + 1))
  fi
done

if [[ ${#LOGFILES[@]} -eq 0 ]]; then
  echo -e "${RED}No domlog files found for user: $CPUSER${RESET}"
  exit 1
fi

# Ask user to select a file
while true; do
  read -p "Enter the number of the file to filter: " SELECTION
  if [[ "$SELECTION" =~ ^[0-9]+$ ]] && (( SELECTION >= 1 && SELECTION <= ${#LOGFILES[@]} )); then
    CHOSEN_FILE="${LOGFILES[$((SELECTION - 1))]}"
    break
  else
    echo -e "${RED}Invalid selection. Please enter a valid number.${RESET}"
  fi
done

LOGFILE="${ACCESS_LOGS_DIR}/${CHOSEN_FILE}"

echo ""
echo -e "${MAGENTA}######################################"
echo -e "Processing domlog: ${BOLD}${CHOSEN_FILE}${RESET}${MAGENTA}"
echo -e "######################################${RESET}"

# Extract unique dates
DATES=$(grep -h -oP '^\d{1,3}(\.\d{1,3}){3} \S+ \S+ \[\K[0-9]{2}/\w{3}/[0-9]{4}' "$LOGFILE" 2>/dev/null | sort | uniq)

if [ -z "$DATES" ]; then
  echo -e "${RED}No valid log data in ${CHOSEN_FILE}${RESET}"
  exit 0
fi

echo -e "${BLUE}Available dates in ${CHOSEN_FILE}:${RESET}"
echo "$DATES"

for DATE in $(echo "$DATES" | tac); do
  echo ""
  echo -e "${GREEN}***** Stats for ${CHOSEN_FILE} :: ${DATE} *****${RESET}"

  TMPFILE=$(mktemp)
  grep "\[$DATE" "$LOGFILE" > "$TMPFILE"

  if [ ! -s "$TMPFILE" ]; then
    echo -e "${YELLOW}No data for $DATE in ${CHOSEN_FILE}${RESET}"
    rm -f "$TMPFILE"
    continue
  fi

  TOTAL_HITS=$(wc -l < "$TMPFILE")
  echo -e "${BOLD}Total hits for ${DATE}:${RESET} ${TOTAL_HITS}"

  echo ""
  echo -e "${BOLD}Top 10 IPs:${RESET}"
  awk '{print $1}' "$TMPFILE" | sort | uniq -c | sort -nr | head -10

  echo ""
  echo -e "${BOLD}Top 10 requested scripts:${RESET}"
  awk '{print $7}' "$TMPFILE" | sort | uniq -c | sort -nr | head -10

  echo ""
  echo -e "${BOLD}Top crawler hits:${RESET}"
  grep -iE 'googlebot|bingbot|slurp|baiduspider|yandex' "$TMPFILE" | \
  awk '{
    ip = $1
    agent = $0
    if (match(agent, /googlebot/i)) bot="Googlebot"
    else if (match(agent, /bingbot/i)) bot="Bingbot"
    else if (match(agent, /slurp/i)) bot="Slurp"
    else if (match(agent, /baiduspider/i)) bot="Baiduspider"
    else if (match(agent, /yandex/i)) bot="Yandex"
    else bot="Unknown"
    print ip, bot
  }' | sort | uniq -c | sort -nr | head -10

  rm -f "$TMPFILE"
done
