#!/bin/bash

FILE="$HOME/Nextcloud/Notes/car_battery.txt.old"

nano $FILE
#cat $FILE | grep -Ev '^#'| grep . | ~/work/clintwebb/misc/bash/plot/plot.sh --min 1215 --max 1350 --marker 'x'
#exit 1


V_START=$(cat "$FILE" | grep -Ev '^#'| grep . | sort --key=2| awk '{print $2}'|head -n 1)
V_END=$(cat "$FILE" | grep -Ev '^#'| grep . | sort --key=2| awk '{print $2}'|tail -n 1)

NEXT_DATE=$(date -d "$V_START - 1 day" +%Y-%m-%d)


DDAYS=0
START_DAY=""
START_VAL=0

while [[ $NEXT_DATE != $V_END ]]; do
  NEXT_DATE=$(date -d "$NEXT_DATE + 1 day" +%Y-%m-%d)
#  declare -p NEXT_DATE

  VV=$(grep "$NEXT_DATE" "$FILE" | grep -Ev '^#'| grep . )
  ((DDAYS++))

  if [[ -n $VV ]]; then
    XX=$(echo "$VV" | awk '{ print $1 }' )
    XY=$(echo "$VV" | awk '{ print $2 }' )

    if [[ -z $START_DAY ]]; then
      echo "$XX $NEXT_DATE"
    elif [[ $DDAYS -gt 1 ]]; then
      GD=$((START_VAL * 1000))
      GF=$((XX * 1000))
      GG=$(( (GF - GD) / DDAYS ))


      CURR_DATE=$(date -d "$START_DAY + 1 day" +%Y-%m-%d)
      while [[ $CURR_DATE != $NEXT_DATE ]]; do
        GD=$((GD + GG))
        
        # Format output divided back to standard integer
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

#done 

done | ~/work/clintwebb/misc/bash/plot/plot.sh --min 1215 --max 1335 --marker 'x'
#done | ~/work/clintwebb/misc/bash/plot/plot.sh --min 1215 --max 1350 --marker 'x'



