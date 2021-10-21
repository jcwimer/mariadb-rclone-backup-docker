#!/bin/bash

check_vars()
{
    var_names=("$@")
    local var_unset="false"
    for var_name in "${var_names[@]}"; do
        if [ -z "${!var_name}" ]; then
          echo "$var_name is unset." 
          var_unset="true"
        fi
    done
    if [ "$var_unset" == "true" ]; then
      exit 1
    fi
    return 0
}

echo Checking environment for needed variables...
check_vars CRON_SCHEDULE DB_USERNAME DB_PASSWORD DB_HOST DAYS_TO_KEEP

echo Creating rclone config...
bash /root/create-rclone-conf.sh

echo Creating a cron to run...

# > /proc/1/fd/1 2>/proc/1/fd/2
# logs to stdout
cat > /etc/cron.d/backup-cron << EOF
${CRON_SCHEDULE} /root/backup.sh > /proc/1/fd/1 2>/proc/1/fd/2
# An empty line is required at the end of this file for a valid cron file.

EOF
cat /etc/cron.d/backup-cron

chmod 0644 /etc/cron.d/backup-cron
crontab /etc/cron.d/backup-cron
echo Setting up cron environment variables...
env >> /etc/environment
echo Running cron in the foreground...
cron -f
