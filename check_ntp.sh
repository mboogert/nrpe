#!/bin/bash

#
# Author: Marcel Boogert
# Source: https://github.com/mboogert/nrpe/blob/master/check_ntp.sh
#

# define static variables
WARNING="0.5"
CRITICAL="1"
TIMEOUT=5
IPVERSION=4
NTPCONF="/etc/ntp.conf"

# get check_ntp binary
if [ -x /usr/lib64/nagios/plugins/check_ntp_time ]; then
  CHECK_NTP="/usr/lib64/nagios/plugins/check_ntp_time"
  DELAY=0
elif [ -x /usr/local/nagios/libexec/check_ntp_time ]; then
  CHECK_NTP="/usr/local/nagios/libexec/check_ntp_time"
else
  echo "UNKNOWN: cannot find a suitable check_ntp_time binary"
  exit 3
fi

# declare an array
declare -A arr_retout
declare -A arr_retval
declare -A arr_status_ok

status_ok=0
status_warning=0
status_critical=0
status_unknown=0

# get configured ntp servers
for SERVER in `grep -e '^server *' $NTPCONF | sed 's/^.*server //' | sed 's/ .*$//'`; do
  if [ -n "$DELAY" ]; then
    arr_retout[$SERVER]="$($CHECK_NTP --host=${SERVER} -${IPVERSION} --warning=${WARNING} --critical=${CRITICAL} --timeout=${TIMEOUT} --delay=${DELAY})"
  else
    arr_retout[$SERVER]="$($CHECK_NTP --host=${SERVER} -${IPVERSION} --warning=${WARNING} --critical=${CRITICAL} --timeout=${TIMEOUT})"
  fi
  arr_retval[$SERVER]="$?"
  case "${arr_retval[$SERVER]}" in
    0)
      ((status_ok++))
      ;;
    1)
      ((status_warning++))
      ;;
    2)
      ((status_critical++))
      ;;
    3)
      ((status_unknown++))
      ;;
  esac
done

SERVERCOUNT="${#arr_retval[@]}"

if [ $status_ok -eq $SERVERCOUNT ] || [ $status_ok -gt 1 ]; then
  echo "OK: Two or more configured NTP servers are responding correctly, server time is OK"
  RETVAL=0
elif [ $status_ok -eq 1 ]; then
  echo "WARNING: Only 1 NTP server is responding, server time is OK"
  RETVAL=1
else
  echo "CRITICAL: No NTP servers are responding"
  RETVAL=2
fi

echo ""
for SERVER in "${!arr_retval[@]}"
do
  DATA="$(echo ${arr_retout[$SERVER]} | sed 's/|.*$//')"
  PERFDATA="$(echo ${arr_retout[$SERVER]} | sed 's/^.*|//')"
  echo "$SERVER - $DATA | ${SERVER}_${PERFDATA}"
done

exit $RETVAL
