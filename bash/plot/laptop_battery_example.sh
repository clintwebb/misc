#!/bin/bash

while true; do upower -b|grep 'percentage:'|awk '{ print $2 }'|sed 's/%//g'; sleep ${1:-60};  done | ./plot.sh --min 0 --max 100 --time
