#!/bin/bash
#
# cPanelstats.sh
# Description: Analyze Apache domlogs for a given cPanel user — grouped by domlog file and date, with IP, script, crawler stats.
#
# Author: Harish Nischal
# Repository: https://github.com/harish-nischal/scriptforce
#

# ============================
# How to use:
#
# ./cPanelstats.sh username
# Example:
# ./cPanelstats.sh exampleuserbob
#
# bash <(curl -s https://github.com/harish-nischal/scriptforce/raw/main/cPanelstats.sh) exampleuserbob
# bash <(wget -qO - https://github.com/harish-nischal/scriptforce/raw/main/cPanelstats.sh) exampleuserbob
# ============================

if [ $# -ne 1 ]; then
  echo "Usage: $0 <cPanel_username>"
  exit 1
fi

USER="$1"
DOMLOGS_DIR="/usr/local/apache/domlogs/$USER"

if [ ! -d "$DOMLOGS_DIR" ]; then
  echo "No domlogs found for user: $USER"
  exit 1
fi

echo "============================"
echo "Domlog files for user: $USER"
echo "============================"
ls -1 "$DOMLOGS_DIR"

echo ""

for LOGFILE in "$DOMLOGS_DIR"/*; do
  FILENAME=$(basename "$LOGFILE")
  echo ""
  echo "######################################"
  echo "Processing domlog: $FILENAME"
  echo "######################################"

  DATES=$(grep -h -oP '^\d{1,3}(\.\d{1,3}){3} \S+ \S+ \[\K[0-9]{2}/\w{3}/[0-9]{4}' "$LOGFILE" 2>/dev/null | sort | uniq)

  if [ -z "$DATES" ]; then
    echo "No valid log data in $FILENAME"
    continue
  fi

  echo "Available dates in $FILENAME:"
  echo "$DATES"

  for DATE in $(echo "$DATES" | tac); do
    echo ""
    echo "***** Stats for $FILENAME :: $DATE *****"

    TMPFILE=$(mktemp)
    grep "\[$DATE" "$LOGFILE" > "$TMPFILE"

    if [ ! -s "$TMPFILE" ]; then
      echo "No data for $DATE in $FILENAME"
      rm -f "$TMPFILE"
      continue
    fi

    echo "Top 10 IPs:"
    awk '{print $1}' "$TMPFILE" | sort | uniq -c | sort -nr | head -10

    echo ""
    echo "Top 10 requested scripts:"
    awk '{print $7}' "$TMPFILE" | sort | uniq -c | sort -nr | head -10

    echo ""
    echo "Top crawler hits:"
    grep -iE 'googlebot|bingbot|slurp|baiduspider|yandex' "$TMPFILE" | \
    awk -F\" '{print $1, $6}' | \
    sed -E 's/.*(Googlebot|Bingbot|Slurp|Baiduspider|Yandex).*/\1/i' | \
    paste -d' ' <(grep -iE 'googlebot|bingbot|slurp|baiduspider|yandex' "$TMPFILE" | awk '{print $1}') - | \
    sort | uniq -c | sort -nr | head -10


    rm -f "$TMPFILE"
  done

done
