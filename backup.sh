#!/bin/bash

filename=$(date +"%Y-%m-%dt%H-%M-%S") # 2021-02-03t140000 would be 2:00:00pm on February 3, 2021
mkdir -p /backup/$filename

echo Running mariabackup with the filename $filename
mariabackup --backup --user=${DB_USERNAME} --password=${DB_PASSWORD} --host=${DB_HOST} --target-dir=/backup/$filename

echo Zipping the backup to file $filename.zip
cd /backup
zip -r ${filename}.zip $filename/

echo Cleaning up backup directory after zip created.
rm -rf /backup/$filename/

# delete files more than x days old
echo Deleting files older than ${DAYS_TO_KEEP} days.
find /backup* -mtime +${DAYS_TO_KEEP} -exec rm {} \;

if ls /rclone.conf > /dev/null; then
  echo Running rclone copy...
  rclone -vv $RCLONE_EXTRA_ARGS --config /rclone.conf copy /backup/${filename}.zip backup:${RCLONE_PATH}
  echo Cleaning up remote backups older than ${DAYS_TO_KEEP} days...
  rclone -vv $RCLONE_EXTRA_ARGS --config /rclone.conf --min-age ${DAYS_TO_KEEP}d delete backup:${RCLONE_PATH}
else
  echo You did not specify RCLONE_TYPE... Skipping rclone sync.
fi
