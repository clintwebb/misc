#!/bin/bash
# (c) Copyright, Clinton Webb 2024.

# Add an entry to a config file... if it doesn't exist.
function addline() {
  local zFound=0
  if [[ -e $1 ]]; then
    grep -q "$2" $1 && zFound=1
  fi
  if [[ $zFound -eq 0 ]]; then
    echo "$2" >> $1
    echo "added - $1: \"$2\""
  else
    echo "exists - $1: \"$2\""
  fi
}

addline ~/.bashrc "bind 'set bell-style none'"
addline ~/.nanorc "set tabsize 2"
addline ~/.nanorc "set tabstospaces"
addline ~/.nanorc "#set autoindent"
addline ~/.nanorc "#set whitespace \"»·\""
addline ~/.nanorc "set whitespace \"» \""
