#!/bin/bash
# Copyright 2024, Clinton Webb
# This script is used to keep track of files contents and compare them if changed.
#
# To check if any file that was hashed has changed.
#  auto_comapre
#
# To Add files or folders to the hash:
#  auto_compare add somefile.txt
#  auto_compare add somefolder/
#
# To Remove files or folders from the hash:
#  ( NOTE that when removing folders, it will only remove files it actually finds in the real specified folder. )
#  auto_compare remove somefile.txt
#  auto_compare remove somefolder/
#
# To Save backups of the current files (incrementally)
#  auto_compare backup

HASH_FILE=~/.hash.md5
HASH_BAKDIR=~/.hash.bak

set -o pipefail


function compare() {
  md5sum -c ${HASH_FILE} &> ${HASH_FILE}.output
  if [[ $? -ne 0 ]]; then
    echo '------------------------------------------------'
    echo "FAILED!!"
    echo
    grep -v ': OK' ${HASH_FILE}.output
    echo
    echo '------------------------------------------------'
    return 1
  else
    rm ${HASH_FILE}.output
    return 0
  fi
}

function add_entry() {
  if [[ -z "$1" ]]; then
    echo "Need to provide files/folders wanting to add."
    sleep 1
    exit 1
  fi
  while [[ -n "$1" ]]; do
    # If a '/' is included in the end of the parameter, strip it out.
    local ENTRY="${1%/}"

    if [[ -d "$ENTRY" ]]; then
      for II in $ENTRY/*; do
        if [[ -e $II ]]; then add_entry $II; fi
      done
    elif [[ -r "$ENTRY" ]]; then

      # if ~/.hash.md5 doesn't exist, then make sure it does.
      [[ -e ${HASH_FILE} ]] || touch ${HASH_FILE}

      # Get current hash (the first one if multiple exist)
      local H_ORIG=$(grep -E " ${1}\$" ${HASH_FILE}|head -n 1)

      # Get New hash and compare.
      local H_NEW=$(md5sum "${1}")
      if [[ "$H_ORIG" != "$H_NEW" ]]; then
        echo "Changed: $ENTRY"

        grep -Ev " ${1}\$" ${HASH_FILE} > ${HASH_FILE}.new
        echo "$H_NEW" >> ${HASH_FILE}.new
        rm ${HASH_FILE}; mv ${HASH_FILE}.new ${HASH_FILE}
      fi
    else
      echo "Unable to Access: $1"
    fi

    shift
  done
}


function remove_entry() {
  if [[ -z "$1" ]]; then
    echo "Need to provide files/folders wanting to remove."
    sleep 1
    exit 1
  fi
  while [[ -n "$1" ]]; do
    # If a '/' is included in the end of the parameter, strip it out.
    local ENTRY="${1%/}"

    if [[ -d "$ENTRY" ]]; then
      for II in $ENTRY/*; do
        if [[ -e $II ]]; then remove_entry $II; fi
      done
    else
      echo "Removed: $ENTRY"

      grep -Ev " ${1}\$" ${HASH_FILE} > ${HASH_FILE}.new
      rm ${HASH_FILE}; mv ${HASH_FILE}.new ${HASH_FILE}
    fi

    shift
  done
}

function backup() {
  # if the BAK dir doesn't exist... create it.
  test -d $HASH_BAKDIR || mkdir -p $_

  # Store date.
  local DDT=$(date +%F-%H%M)
  local DDF=$HASH_BAKDIR/hash-$DDT.tar.gz
  local DDS=$HASH_BAKDIR/hash.snar

  if [[ -e $DDF ]]; then
    echo "Backup file already exists: $DDF"
    echo "Skipping..."
    exit 1
  fi

  if [[ ! -e ~/.hash.md5 ]]; then
    echo "Nothing to backup... ~/.hash.md5 doesn't exist"
    exit 1
  fi

  # First need to get the list of files being tracked.
#  declare DDL
  cat ~/.hash.md5 | awk '{print $2}' > ~/.hash.tmp
  readarray -t DDL < ~/.hash.tmp
  rm ~/.hash.tmp

  tar -z --verbose -p --warning=no-file-changed --create --file=$DDF --listed-incremental=$DDS "${DDL[@]}" > ~/.hash.out 2> ~/.hash.err
  local RES=$?
  if [[ $RES -eq 0 ]]; then
    cat ~/.hash.out
    rm ~/.hash.out ~/.hash.err
  else
    echo "Failure!!!  Investigate!  (RES: $RES)"
    cat ~/.hash.err
    sleep 1
    exit 1
  fi
}


case $1 in
  add|new)     add_entry "${@:2}"    ;;
  remove|del)  remove_entry "${@:2}" ;;
  backup)      backup                ;;
  compare|*)   compare; exit $?      ;;
esac
