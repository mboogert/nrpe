#!/bin/bash

#
# Make sure the following cron is running at the gitlab host
#
# 00 */1 * * * rpm -q gitlab-ce | sed 's/gitlab-ce-//' | sed 's/\.x86_64//' > /tmp/gitlab_upgrade_status.current
# 00 */1 * * * yum --disableexcludes all check-update gitlab-ce | grep gitlab-ce | awk '{print $2}' > /tmp/gitlab_upgrade_status.available
#

report_datetime_end="$(grep 'report_datetime_end' /var/log/lynis-report.dat | sed 's/^.*=//')"
hardening_index="$(grep 'hardening_index' /var/log/lynis-report.dat | sed 's/^.*=//')"

if [ $hardening_index -lt 65 ]; then
    echo "CRITICAL Hardening index is $hardening_index | hardening_index=$hardening_index;;;0;"
    exit 2
elif [ $hardening_index -lt 70 ]; then
    echo "WARNING Hardening index is $hardening_index | hardening_index=$hardening_index;;;0;"
    exit 1
elif [ $hardening_index -gt 70 ]; then
    echo "OK Hardening index is $hardening_index | hardening_index=$hardening_index;;;0;"
    exit 0
else
    echo "UNKNOWN Hardening index 0 | hardening_index=0;;;0;"
    exit 3
fi
