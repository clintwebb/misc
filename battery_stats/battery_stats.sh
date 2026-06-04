#!/bin/bash

# Battery stats.
# The main purpose is to track the battery standards, and maybe even graph them.

# upower -i /org/freedesktop/UPower/devices/battery_BAT0

while true; do upower -b|grep 'percentage:'|awk '{ print $2 }'|sed 's/%//g'; sleep ${1:-10};  done | ~/work/clintwebb/misc/bash/plot/plot.sh --min 0 --max 100 --time --marker x
