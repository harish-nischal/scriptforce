#!/bin/bash

CPUSER=$(whoami)
ACCESS_LOGS_DIR="/home/${CPUSER}/access-logs"

if [[ ! -d "$ACCESS_LOGS_DIR" ]]; then
  echo "Error: Directory $ACCESS_LOGS_DIR does not exist for user: $CPUSER"
  exit 1
fi

# List available domlog files
echo "============================"
echo "Domlog files for user: $CPUSER"
echo "============================"

LOGFILES=()
INDEX=1
for file in "$ACCESS_LOGS_DIR"/*; do
  if [[ -f "$file" ]]; then
    FILENAME=$(basename "$file")
    echo "${INDEX}) $FILENAME"
    LOGFILES+=("$FILENAME")
    INDEX=$((INDEX + 1))
  fi
done

if [[ ${#LOGFILES[@]} -eq 0 ]]; then
  echo "No domlog files found for user: $CPUSER"
  exit 1
fi

# Ask user to select a file
while true; do
  read -p "Enter the number of the file to filter: " SELECTION < /dev/tty
  if [[ "$SELECTION" =~ ^[0-9]+$ ]] && (( SELECTION >= 1 && SELECTION <= ${#LOGFILES[@]} )); then
    CHOSEN_FILE="${LOGFILES[$((SELECTION - 1))]}"
    break
  else
    echo "Invalid selection. Please enter a valid number."
  fi
done

LOGFILE="${ACCESS_LOGS_DIR}/${CHOSEN_FILE}"

echo ""
echo "######################################"
echo "Processing domlog: $CHOSEN_FILE"
echo "######################################"

# Extract unique dates
DATES=$(grep -h -oP '^\d{1,3}(\.\d{1,3}){3} \S+ \S+ \[\K[0-9]{2}/\w{3}/[0-9]{4}' "$LOGFILE" 2>/dev/null | sort | uniq)

if [ -z "$DATES" ]; then
  echo "No valid log data in $CHOSEN_FILE"
  exit 0
fi

echo "Available dates in $CHOSEN_FILE:"
echo "$DATES"

for DATE in $(echo "$DATES" | tac); do
  echo ""
  echo "***** Stats for $CHOSEN_FILE :: $DATE *****"

  TMPFILE=$(mktemp)
  grep "\[$DATE" "$LOGFILE" > "$TMPFILE"

  if [ ! -s "$TMPFILE" ]; then
    echo "No data for $DATE in $CHOSEN_FILE"
    rm -f "$TMPFILE"
    continue
  fi

  TOTAL_HITS=$(wc -l < "$TMPFILE")
  echo "Total hits: $TOTAL_HITS"

  echo ""
  echo "Top 10 IPs:"
  awk '{print $1}' "$TMPFILE" | sort | uniq -c | sort -nr | head -10

  echo ""
  echo "Top 10 requested scripts:"
  awk '{print $7}' "$TMPFILE" | sort | uniq -c | sort -nr | head -10

  echo ""
  echo "Top crawler hits:"
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
