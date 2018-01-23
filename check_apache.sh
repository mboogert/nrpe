#!/bin/bash

#
# Author: Marcel Boogert
# Source: https://github.com/mboogert/nrpe/blob/master/check_apache.sh
#

CHECK_PROCS="/usr/local/nagios/libexec/check_procs"

# Get apache server MPM (Multi-Processing Module)
SERVER_MPM="$(httpd -V 2>&1 | grep "Server MPM" | sed 's/^.*://' | sed 's/^[ \t]*//;s/[ \t]*$//' | tr '[:upper:]' '[:lower:]')"

# Get the systems memory size
SYSTEMMEMORY="$(grep MemTotal /proc/meminfo | sed 's/^.*://' | sed 's/^[ \t]*//;s/[ \t]*$//' | sed 's/ .*$//')"
SYSTEMMEMORYMB="$(echo $((SYSTEMMEMORY/1024)))"
    
case "$SERVER_MPM" in
  "prefork")
    # Get the average httpd memory footprint
    MEMORYFOOTPRINT="$(ps --no-headers -o "rss,cmd" -C httpd | awk '{ sum+=$1 } END { printf ("%d\n", sum/NR/1024) }' || ps --no-headers -o "rss,cmd" -C /usr/sbin/httpd | awk '{ sum+=$1 } END { printf ("%d\n", sum/NR/1024) }')"

    # Get serverlimit from configuration file
    CONFIGFILE="$(grep -i -r --include \*.conf -e "serverlimit" /etc/httpd/ | grep -v '^.*:.*#' | sed 's/:.*//' | uniq)"
    if [ "$CONFIGFILE" = "" ]
    then
      SERVERLIMIT=256
    else
      PREFORK_CONFIG="$(sed -n -e '/<IfModule mpm_prefork_module>/I,/<\/IfModule>/I p;/<IfModule prefork.c>/I,/<\/IfModule>/I p' $CONFIGFILE | uniq)"
      SERVERLIMIT="$(echo "$PREFORK_CONFIG" | grep -v "^.*#" | grep -i serverlimit | tr '[:upper:]' '[:lower:]' | sed 's/^.*serverlimit.*[ \t]//')"
    fi

    # Add 1 to correct the check_procs output
    SERVERLIMIT_CHECK="$(echo $((SERVERLIMIT+1)))"

    if [[ "$MEMORYFOOTPRINT" -eq 0 ]]
    then
      MEMORYFOOTPRINT=1
    fi
    
    # Calculate the adviced maximum memory assignment for apache,
    #     calculation: (system memory - 1GB) / average apache memory + 10%
    if [ $SYSTEMMEMORYMB -lt 1024 ] 
    then
      SERVERLIMIT_ADVICE_RAW="$(awk -vp=$SYSTEMMEMORYMB -vq=$MEMORYFOOTPRINT -vr=512 'BEGIN{printf "%.0f" ,(p - r) / q}')"
    else
      SERVERLIMIT_ADVICE_RAW="$(awk -vp=$SYSTEMMEMORYMB -vq=$MEMORYFOOTPRINT -vr=1024 'BEGIN{printf "%.0f" ,(p - r) / q}')"
    fi
    SERVERLIMIT_ADVICE="$(awk -vp=$SERVERLIMIT_ADVICE_RAW -vq=1.10 'BEGIN{printf "%.0f" ,p * q}')"
    ;;

  "event")
    MEMORYFOOTPRINT="1"
    SERVERLIMIT="256"
    SERVERLIMIT_CHECK="256"
    SERVERLIMIT_ADVICE="256"
    ;;

  *)
    SERVER_MPM="<access denied, using default values>"
    MEMORYFOOTPRINT="1"
    SERVERLIMIT="256"
    SERVERLIMIT_CHECK="256"
    SERVERLIMIT_ADVICE="256"
    ;;
    
esac
    
# Dynamically set warning and critical tresholds from configured serverlimit directive
HTTPD_WARNING="$(awk -vp=$SERVERLIMIT_CHECK -vq=0.90 'BEGIN{printf "%.0f" ,p * q}')"
HTTPD_CRITICAL="$SERVERLIMIT_CHECK"

# Get and return the actual check output
CHECK_OUTPUT="$($CHECK_PROCS -C httpd -w 1:$HTTPD_WARNING -c 1:$HTTPD_CRITICAL)"
RETURN_CODE="$?"
echo "$CHECK_OUTPUT"

# Generate a warning if configured serverlimit above calculated adviced serverlimit
if [ $SERVERLIMIT -gt $SERVERLIMIT_ADVICE ] && [ $RETURN_CODE = 0 ]
then
  echo "WARNING - Current ServerLimit($SERVERLIMIT) above adviced maximum ServerLimit +10% ($SERVERLIMIT_ADVICE)"
  echo ""
  RETURN_CODE=1
fi

echo "Apache MPM                                       : $SERVER_MPM"
echo "Apache ServerLimit                               : $SERVERLIMIT"
echo "Apache process memory footprint                  : ${MEMORYFOOTPRINT}M"
echo "Total system memory                              : ${SYSTEMMEMORYMB}M"
echo "Adviced maximum ServerLimit                      : $SERVERLIMIT_ADVICE"
echo " (SystemMemory - 1GB ) / MemoryFootprint + 10%"
exit $RETURN_CODE
