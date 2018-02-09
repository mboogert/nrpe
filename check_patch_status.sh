#!/bin/bash

#
# Author: Marcel Boogert
# Source: https://github.com/mboogert/nrpe/blob/master/check_patch_status.sh
#

patch_status_location="/var/run/patch_status"
patch_status_status="$(cat $patch_status_location | sed 's/|.*$//')"
patch_status_message="$(cat $patch_status_location | sed 's/^.*|//')"

case "$patch_status_status" in

"OK")
     echo "$patch_status_status: $patch_status_message"
     exit 0
     ;;
"WARNING")
     echo "$patch_status_status: $patch_status_message"
     exit 1
     ;;
"CRITICAL")
     echo "$patch_status_status: $patch_status_message"
     exit 2
     ;;
*)
    echo "UNKNOWN: Unknown status"
    exit 3
    ;;
esac
