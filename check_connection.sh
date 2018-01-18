#!/bin/sh

IP="$1"
PORT="$2"

if [ $# -lt 2 ]
then
  echo "UNKNOWN: Not enough arguments supplied"
  exit 3
fi

if [[ `echo | nc -z -w 3 -vvv $IP $PORT | grep succeeded` ]]
then
  echo "OK: connection to IP $IP port $PORT succeeded"
  exit 0
else
  echo "WARNING: connection to IP $IP port $PORT failed"
  exit 1
fi
