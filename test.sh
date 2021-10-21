#!/bin/bash
project_dir="$( dirname $(readlink -f ${BASH_SOURCE[0]}))"

docker build -t jcwimer/mariadb-rclone-backup-docker:10.3 .

if ! docker network ls | grep mariadb > /dev/null; then
  echo Creating mariadb docker network
  docker network create mariadb
else
  echo mariadb docker network already exists
fi

if docker inspect minio > /dev/null; then
  docker stop minio
fi
mkdir -p ${project_dir}/test-files/minio
sudo chown 1001:1001 ${project_dir}/test-files/minio
docker run -d --rm --name minio \
    --env MINIO_ROOT_USER="root" \
    --env MINIO_ROOT_PASSWORD="password" \
    --network mariadb \
    -v ${project_dir}/test-files/minio:/data \
    bitnami/minio:latest
    
until docker exec -it minio mc ls | grep "bin/"; do
  echo Waiting on minio to start...
  sleep 10s
done

docker exec -it minio mc mb mariadb/

if docker inspect mariadb > /dev/null; then
  docker stop mariadb
  sleep 5s
fi
docker run --rm -v ${project_dir}/test-files/mariadb:/var/lib/mysql --net mariadb --name mariadb -e MARIADB_ROOT_PASSWORD=password -d mariadb:10.3

until docker exec -it mariadb mysql -u root -ppassword -e "show databases;"; do
  echo Waiting on mariadb to start...
  sleep 10s
done

if docker inspect mariadb-backup > /dev/null; then
  docker stop mariadb-backup
fi

# every 1 minute
docker run --rm -d \
  --name mariadb-backup \
  -v ${project_dir}/test-files/mariadb-backup:/backup \
  -v ${project_dir}/test-files//mariadb:/var/lib/mysql \
  --net mariadb \
  -e CRON_SCHEDULE="*/1 * * * *" \
  -e DB_USERNAME="root" \
  -e DB_PASSWORD="password" \
  -e DB_HOST="mariadb" \
  -e DAYS_TO_KEEP="5" \
  -e RCLONE_TYPE="s3" \
  -e S3_ACCESS_ID="root" \
  -e S3_ACCESS_KEY="password" \
  -e S3_ENDPOINT="http://minio:9000" \
  -e S3_REGION="us-east1" \
  -e RCLONE_EXTRA_ARGS="--no-check-certificate" \
  -e RCLONE_PATH="mariadb" \
  jcwimer/mariadb-rclone-backup-docker:10.3

echo Waiting a few minutes for cron to run...
sleep 180s

filename=$(date +"%Y-%m-%d")
echo Files in backup folder
ls ${project_dir}/test-files/mariadb-backup | grep $filename
echo Files in Minio
sudo ls ${project_dir}/test-files/minio/mariadb | grep $filename
cd ${project_dir}/test-files/mariadb-backup
# sudo unzip ${filename}*.zip
# sudo cat ${filename}*/xtrabackup_info

cd ${project_dir}
docker stop mariadb
docker stop minio
docker stop mariadb-backup
sudo rm -rf test-files
