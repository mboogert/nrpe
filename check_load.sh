#!/bin/bash

#
# Author: Marcel Boogert
# Source: https://github.com/mboogert/nrpe/blob/master/protim_check_load.sh
#

CHECK_LOAD="/usr/local/nagios/libexec/check_load"

CPU_COUNT="$(grep processor /proc/cpuinfo | wc -l)"

OPTIMAL_LOAD_WARNING="$(echo "$(( CPU_COUNT*3 )),$(( CPU_COUNT*2 )),$(( CPU_COUNT*1 ))")"
OPTIMAL_LOAD_CRITICAL="$(echo "$(( CPU_COUNT*6 )),$(( CPU_COUNT*4 )),$(( CPU_COUNT*2 ))")"

CHECK_OUTPUT="$($CHECK_LOAD -w "$OPTIMAL_LOAD_WARNING" -c "$OPTIMAL_LOAD_CRITICAL")"
RETURN_CODE="$?"

if [ "$RETURN_CODE" -gt "0" ]
then
  TOP_OUTPUT="$(top -bn 1 | grep -A10 ' PID')"
  echo "$CHECK_OUTPUT"
  echo "$TOP_OUTPUT"
  exit $RETURN_CODE
else
  echo $CHECK_OUTPUT
  exit $RETURN_CODE
fi
