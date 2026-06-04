#!/bin/bash
# (c) Clinton Webb, 2024.
# 
# Tool to take input and plot it.   Can be dynamic, or also have some options specified.
# As an example, can do something simple like this
#
#   while true; do upower -b|grep 'percentage:'|awk '{ print $2 }'|sed 's/%//g'; sleep ${1:-10};  done | ./plot.sh --min 0 --max 100

if [[ "$1" == '-h' ]] || [[ "$1" == '--help' ]]; then
  echo "--min [number] - indicate the minimum number the input range will be in"
  echo "--max [number] - indicate the maximum number the input range will be in"
  echo "--time         - add the current time to the left"
  echo "--marker [x]   - the letter that will be used to display."

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
VV_TIME=0
VV_MARK='.'

while [[ -n $1 ]]; do

  # Start with the options that do NOT have a value (eg, '--time')
  case $1 in
    --time)    VV_TIME=6 ;;
    *)  # If the paramters are done like --hostname="fred" then we want to handle that.
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
          --min)       VV_MIN=$(nextvar $ONE $TWO)  || exit $? ;;
          --max)       VV_MAX=$(nextvar $ONE $TWO)  || exit $? ;;
          --marker)    VV_MARK=$(nextvar $ONE $TWO) || exit $? ;;

          *)
            echo "Unknown Parameter: $1"
            echo "Exiting."
            sleep 1
            exit 1
            ;;
        esac
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
  printf -v line '%d\n' "$line" 2>/dev/null
#  echo "line: $line"

  if [[ $VV_AUTO -gt 0 ]]; then
    [[ $line -lt $xMIN ]] && xMIN=$line
    [[ $line -gt $xMAX ]] && xMAX=$line
  fi

  # Calculate the number of cells we have to display the plot.
  # xCELLS=$(( $xWIDTH - ${#line} - 2 - ${#xMIN} - 3 - ${#xMAX} - $VV_TIME ))
  xCELLS=$(( $xWIDTH - ${#xMAX} - 2 - ${#xMIN} - 3 - ${#xMAX} - $VV_TIME ))

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
    CHC=${VV_MARK:0:1}    # Only use the first digit of whatever string might have been provided.
  fi
  #declare -p line xWIDTH xCELLS xMIN xMAX
  if [[ $VV_TIME -gt 0 ]]; then
    echo -n "$(date "+%H:%M")"
    echo -n ' '
  fi
  if [[ $CHA -le 0 ]]; then
    printf "%*d: %d|%s%*s|%d\n" ${#xMAX} $line $xMIN $CHC $CHB ' ' $xMAX
  elif [[ $CHB -le 0 ]]; then
    printf "%*d: %d|%*s%s|%d\n" ${#xMAX} $line $xMIN $CHA ' ' $CHC $xMAX
  else
    printf "%*d: %d|%*s%s%*s|%d\n" ${#xMAX} $line $xMIN $CHA ' ' $CHC $CHB ' ' $xMAX
  fi
done
