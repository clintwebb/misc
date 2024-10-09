#!/bin/bash
# (c) Clinton Webb, 2024.
# 
# Tool to take input and plot it.   Can be dynamic, or also have some options specified.

if [[ "$1" == '-h' ]] || [[ "$1" == '--help' ]]; then
  echo "--min [number] - indicate the minimum number the input range will be in"
  echo "--max [number] - indicate the maximum number the input range will be in"
  exit 1
fi

function nextvar() {
  if [[ -n $2 ]] && [[ ${2:0:1} != '-' ]]; then
    echo "$2"
  else
    echo "Invalid Parameter: $1" 1>&2
    sleep 1
  fi
}

VV_MIN=0
VV_MAX=0
VV_AUTO=1

while [[ -n $1 ]]; do

  # If the paramters are done like --hostname="fred" then we want to handle that.
  # We also want to handle it if they done like --hostname fred.
  if [[ $1 == *=* ]]; then
    IFS='='; TT=($1); unset IFS;
    ONE=${TT[0]}
    TWO=${TT[1]}
  else
    ONE=$1
    TWO=$2
    shift
  fi

  case $ONE in
    --min)       VV_MIN=$(nextvar $ONE $TWO) || exit $? ;;
    --max)       VV_MAX=$(nextvar $ONE $TWO) || exit $? ;;

    *)
      echo "Unknown Parameter: $1"
      echo "Exiting."
      sleep 1
      exit 1
      ;;
  esac
  shift
done

# If either MIN or MAX is set, then remove the AUTO functionality.
if [[ $VV_MIN != 0 ]] || [[ $VV_MAX != 0 ]]; then
  VV_AUTO=0
fi

xMIN=$VV_MIN
xMAX=$VV_MAX



### Now process the input and plot the output.

while read -r line; do
  xWIDTH=$(tput cols)

  if [[ $VV_AUTO -gt 0 ]]; then
    [[ $line -lt $xMIN ]] && xMIN=$line
    [[ $line -gt $xMAX ]] && xMAX=$line
  fi

  # Calculate the number of cells we have to display the plot.
  xCELLS=$(( $xWIDTH - ${#line} - 2 - ${#xMIN} - 3 - ${#xMAX} ))

  if [[ $line -gt $xMAX ]]; then
    CHA=$((xCELLS))
    CHB=0
    [[ $VV_AUTO -gt 0 ]] && CHC='^' || CHC='X'
    #CHC='X'
  else
    (( xCELLS *= 10000 ))
    SPLIT=$(( xMAX - xMIN + 1 ))
    DIFF=$(( line - xMIN ))
    CHA=$(( xCELLS / SPLIT * DIFF ))
    (( CHA /= 10000 ))
    (( CHA-- ))
    (( xCELLS /= 10000 ))
    CHB=$((xCELLS - CHA))
    #CHB=1
    CHC='.'
  fi
  #declare -p line xWIDTH xCELLS xMIN xMAX
  if [[ $CHA -le 0 ]]; then
    printf "%d: %d|%s%*s|%d\n" $line $xMIN $CHC $CHB ' ' $xMAX
  elif [[ $CHB -le 0 ]]; then
    printf "%d: %d|%*s%s|%d\n" $line $xMIN $CHA ' ' $CHC $xMAX
  else
    printf "%d: %d|%*s%s%*s|%d\n" $line $xMIN $CHA ' ' $CHC $CHB ' ' $xMAX
  fi
done
