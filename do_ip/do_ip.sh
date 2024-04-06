#!/bin/bash
# (c) Copyright, Clinton Webb, 2024
#
# 
#

source /etc/do_ip.conf

EXIP=$(curl -s icanhazip.com)
if [[ $EXIP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Current IP: $EXIP"
else
  echo "Unable to obtain current IP... skipping"
  exit 1
fi

# The external IP of the home internet is determined, and the A record needs to be updated.
# all other external DNS entries should be CNAME's pointing to that A record.  That way, we only update one.

while read -r zLINE; do 
  if [[ -z $DO_RECID ]]; then
    readarray -td ' ' ENTRY < <(echo $zLINE)
    if [[ "${ENTRY[2]}" == "$DO_AREC" ]] && [[ "${ENTRY[1]}" == "A" ]]; then
      DO_RECID="${ENTRY[0]}"
      DO_CURRIP="${ENTRY[3]}"
    fi
  fi
done < <(doctl compute domain records list $DO_DOMAIN --no-header)

if [[ -z $DO_RECID ]]; then
  echo "Unable to find record ID. Investigate!"
  exit 1
fi

if [[ "$DO_CURRIP" == "$EXIP" ]]; then
  echo "DNS Already set.  Nothing to do ($DO_CURRIP)"
else
  echo "DNS entry $DO_CURRIP is different."
   
  # Because the IP's are different, we need to update the DNS record.
  doctl compute domain records update $DO_DOMAIN --record-id $DO_RECID --record-name $DO_AREC --record-data $EXIP
  if [[ $? -eq 0 ]]; then 
    echo "DNS Updated"
    # we should also send out a notification.
  else
    echo "SOMETHING WENT WRONG"
  fi
fi


