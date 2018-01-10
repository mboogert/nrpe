#!/bin/bash

#CHECK_PROCS="/usr/lib64/nagios/plugins/check_procs"
CHECK_PROCS="/usr/local/nagios/libexec/check_procs"

# Get apache server mpm
SERVER_MPM="$(httpd -V | grep "Server MPM" | sed 's/^.*://' | sed 's/^[ \t]*//;s/[ \t]*$//')"

# Get serverlimit configuration file
CONFIGFILE="$(grep -i -r --include \*.conf -e "serverlimit" /etc/httpd/ | grep -v '^.*:.*#' | sed 's/:.*//')"
if [ "$CONFIGFILE" = "" ]
then
  SERVERLIMIT=256
else
  PREFORK_CONFIG="$(sed -n -e '/<IfModule mpm_prefork_module>/,/<\/IfModule>/ p;/<IfModule prefork.c>/,/<\/IfModule>/ p' $CONFIGFILE | uniq)"
  SERVERLIMIT="$(echo "$PREFORK_CONFIG" | grep -v "^.*#" | grep -i serverlimit | tr '[:upper:]' '[:lower:]' | sed 's/^.*serverlimit.*[ \t]//')"
fi

MEMORYFOOTPRINT="$(ps --no-headers -o "rss,cmd" -C httpd | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"M") }')"
SYSTEMMEMORY="$(grep MemTotal /proc/meminfo | sed 's/^.*://' | sed 's/^[ \t]*//;s/[ \t]*$//' | sed 's/ .*$//')"
SYSTEMMEMORYMB="$(echo $((SYSTEMMEMORY/1024)))"
SERVERLIMIT_ADVICE="$(awk -vp=$SYSTEMMEMORYMB -vq=$MEMORYFOOTPRINT -vr=1024 'BEGIN{printf "%.0f" ,(p - r) / q}')"

# Dynamically set warning and critical tresholds
HTTPD_WARNING="$(awk -vp=$SERVERLIMIT -vq=0.95 'BEGIN{printf "%.0f" ,p * q}')"
HTTPD_CRITICAL="$SERVERLIMIT"

# Get and return the actual check output
CHECK_OUTPUT="$($CHECK_PROCS -C httpd -w $HTTPD_WARNING -c $HTTPD_CRITICAL)"
RETURN_CODE="$?"
echo "$CHECK_OUTPUT"

# Generate a warning if serverlimit above advice
if [ $SERVERLIMIT -gt $SERVERLIMIT_ADVICE ] && [ $RETURN_CODE = 0 ]
then
  echo "WARNING - Current ServerLimit($SERVERLIMIT) above adviced maximum ServerLimit($SERVERLIMIT_ADVICE)"
  echo ""
  RETURN_CODE=1
fi

echo "Apache MPM: $SERVER_MPM"
echo "Apache ServerLimit: $SERVERLIMIT"
echo "Apache process memory footprint: $MEMORYFOOTPRINT"
echo "Total system memory: ${SYSTEMMEMORYMB}M"
echo "Adviced maximum ServerLimit: $SERVERLIMIT_ADVICE"
exit $RETURN_CODE
