#!/bin/bash

FILE="$HOME/Nextcloud/Notes/car_battery.txt"

nano "$FILE"


# Process file: strip comments/empty lines, take the LAST entry for duplicate dates, and sort by date
DATA=$(grep -Ev '^#' "$FILE" | grep . | awk '{last[$2]=$1} END {for (d in last) print last[d], d}' | sort -k2)

if [[ -z "$DATA" ]]; then
  echo "No valid data found."
  exit 1
fi

V_START=$(echo "$DATA" | head -n 1 | awk '{print $2}')
V_END=$(echo "$DATA" | tail -n 1 | awk '{print $2}')

NEXT_DATE=$(date -d "$V_START - 1 day" +%Y-%m-%d)

DDAYS=0
START_DAY=""
START_VAL=0

while [[ "$NEXT_DATE" != "$V_END" ]]; do
  NEXT_DATE=$(date -d "$NEXT_DATE + 1 day" +%Y-%m-%d)

  # Check extracted DATA for exact date match
  VV=$(echo "$DATA" | grep " $NEXT_DATE$")
  ((DDAYS++))

  if [[ -n "$VV" ]]; then
    XX=$(echo "$VV" | awk '{ print $1 }')

    if [[ -z "$START_DAY" ]]; then
      echo "$XX $NEXT_DATE"
    elif [[ $DDAYS -gt 1 ]]; then
      GD=$((START_VAL * 1000))
      GF=$((XX * 1000))
      GG=$(( (GF - GD) / DDAYS ))

      CURR_DATE=$(date -d "$START_DAY + 1 day" +%Y-%m-%d)
      while [[ "$CURR_DATE" != "$NEXT_DATE" ]]; do
        GD=$((GD + GG))
        echo "$((GD / 1000)) $CURR_DATE"
        CURR_DATE=$(date -d "$CURR_DATE + 1 day" +%Y-%m-%d)
      done

      echo "$XX $NEXT_DATE"
    else
      echo "$XX $NEXT_DATE"
    fi

    START_DAY=${NEXT_DATE}
    START_VAL=${XX}
    DDAYS=0
  fi
done | ~/work/clintwebb/misc/bash/plot/plot.sh --min 1215 --max 1335 --marker 'x'
