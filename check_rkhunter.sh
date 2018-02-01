#!/bin/bash

rkhunter_output="$(cat /var/log/rkhunter/rkhunter.log | grep 'Rootkit' | grep -v -e 'Checking for' -e 'Rootkits checked' -e 'Rootkit checks' -e 'Running Rootkit' | grep -v '[ Not found ]' | sed 's/  .*$//')"
rkhunter_rootkits_checked="$(grep 'Rootkits checked' /var/log/rkhunter/rkhunter.log)"

if [ "$rkhunter_output" == "" ]
then
  echo "OK - $rkhunter_rootkits_checked"
  exit 0
else
  echo "CRITICAL - $rkhunter_output"
  exit 2
fi
