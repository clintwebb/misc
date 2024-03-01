#!/bin/bash
# Copyright 2024, Clinton Webb
# This script is used to keep track of files contents and compare them if changed.
#
# To Add files to the hash:
#  auto_compare add somefile.txt
#
# To check if any file that was hashed has changed.
#  auto_comapre

HASH_FILE=~/.hash.md5

function compare() {
  md5sum -c ${HASH_FILE} &> ${HASH_FILE}.output
  if [[ $? -ne 0 ]]; then
    echo '------------------------------------------------'
    echo "FAILED!!"
    echo
    grep -v ': OK' ${HASH_FILE}.output
    echo
    echo '------------------------------------------------'
    sleep 2
  else
    rm ${HASH_FILE}.output
  fi
}

function add_entry() {
  if [[ -z "$1" ]]; then
    echo "Need to provide files/folder wanting to add."
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
    elif [[ -e "$ENTRY" ]]; then

      # Get current hash (the first one if multiple exist)
      local H_ORIG=$(grep -E " ${1}\$" ${HASH_FILE}|head -n 1)

      # Get New hash and compare.
      local H_NEW=$(md5sum "${1}")

      if [[ "$H_ORIG" != "$H_NEW" ]]; then
        echo "Change: $ENTRY"

        grep -Ev " ${1}\$" ${HASH_FILE} > ${HASH_FILE}.new
        echo "$H_NEW" >> ${HASH_FILE}.new
        rm ${HASH_FILE}; mv ${HASH_FILE}.new ${HASH_FILE}
      fi
    else
      echo "UNKNOWN: $1"
    fi
    shift
  done
}

case $1 in
  add)  add_entry "${@:2}" ;;
  *)    compare            ;;
esac
