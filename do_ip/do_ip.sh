#!/bin/bash
# Author: Clinton Webb, 2024
# (c) Copyright 2024, Clinton Webb.  All rights reserved.

source /etc/do_ip.conf

# When running the script from the systemd service, it weirdly doesn't allocate a $HOME variable, which the doctl tool requires.
# Assuming we running as root, but really dont need to (but what other default account should we set the service to use?)
[[ -z "$HOME" ]] && export HOME=/root

function do_install() {
  cat > /etc/systemd/system/do_ip.service <<EOF
[Unit]
Description=DigitalOcean IP mapping

[Service]
Type=simple
ExecStart=/opt/do_ip/do_ip.sh

[Install]
WantedBy=multi-user.target
EOF
  cat > /etc/systemd/system/do_ip.timer <<EOF
[Unit]
Description=Trigger Timer for IP management

[Timer]
#OnCalendar=01:00:00
OnCalendar=*-*-* *:00,05,10,15,20,25,30,35,40,45,50,55:00

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now do_ip.timer
}

function do_update() {
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
    echo "Unable to find record ID.  Adding..."
    doctl compute domain records create $DO_DOMAIN --record-type A --record-name $DO_AREC --record-data $EXIP
    if [[ $? -gt 0 ]]; then
      echo "Unable to register domain record.  Investigate!"
      exit 1
    fi
    exit 0
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
}

case $1 in
  install)         do_install ;;
  *)               do_update ;;
esac
