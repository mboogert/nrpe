#!/bin/bash
patch_status_status="$(cat /var/tmp/patch_status | sed 's/|.*$//')"
patch_status_message="$(cat /var/tmp/patch_status | sed 's/^.*|//')"

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
