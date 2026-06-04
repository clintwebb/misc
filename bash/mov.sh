#!/bin/bash

if [[ -n $6 ]]; then
  zcat ~/Nextcloud/movie_list.txt.gz |grep -v 'Kindle Mega Collection'| grep -i "$1" |grep -i "$2" |grep -i "$3" |grep -i "$4" |grep -i "$5" |grep -i "$6"
elif [[ -n $5 ]]; then
  zcat ~/Nextcloud/movie_list.txt.gz |grep -v 'Kindle Mega Collection'| grep -i "$1" |grep -i "$2" |grep -i "$3" |grep -i "$4" |grep -i "$5"
elif [[ -n $4 ]]; then
  zcat ~/Nextcloud/movie_list.txt.gz |grep -v 'Kindle Mega Collection'| grep -i "$1" |grep -i "$2" |grep -i "$3" |grep -i "$4"
elif [[ -n $3 ]]; then
  zcat ~/Nextcloud/movie_list.txt.gz |grep -v 'Kindle Mega Collection'| grep -i "$1" |grep -i "$2" |grep -i "$3"
elif [[ -n $2 ]]; then
  zcat ~/Nextcloud/movie_list.txt.gz |grep -v 'Kindle Mega Collection'| grep -i "$1" |grep -i "$2"
elif [[ -n $1 ]]; then
  zcat ~/Nextcloud/movie_list.txt.gz |grep -v 'Kindle Mega Collection'| grep -i "$1"
else
  echo "Need to provide some words to check"
fi



