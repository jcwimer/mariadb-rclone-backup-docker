# mariadb-rclone-backup-docker
This is a container used to run mariadb backups with maria-backup and has the ability to store those backups off site with rclone. It can be used with docker-compose or kubernetes (as a sidecar).

## Required Environment Variables
* `CRON_SCHEDULE`- How often should backups run? The image uses cron so for example: `"*/1 * * * *"` would be every minute
* `DB_USERNAME`- the database username used for backups
* `DB_PASSWORD`- the database password used for backups
* `DB_HOST`- the database hostname/ip address
* `DAYS_TO_KEEP`- how many days worth of backups to keep represented as a string. Example: `"5"`

## Optional Environment Variables
* `RCLONE_TYPE` - which type of backend to use for rclone... currently the only supported type is `"s3"`, but more will be supported later. See: [Rclone remote docs](https://rclone.org/overview/)
* `S3_ACCESS_ID`- *Required if RCLONE_TYPE="s3"* - the s3 access id for storing the backups remotely
* `S3_ACCESS_KEY`- *Required if RCLONE_TYPE="s3"* - the s3 access key for storing the backups remotely
* `S3_ENDPOINT`- *Required if RCLONE_TYPE="s3"* - the s3 hostname/ip address for storing the backups remotely
* `S3_REGION`- *Required if RCLONE_TYPE="s3"* - the s3 region for storing the backups remotely
* `RCLONE_EXTRA_ARGS`- optional extra arguments to pass to the rclone cli. Example: `"--no-check-certificate"` if using a self signed minio instance. See: [Rclone options docs](https://rclone.org/docs/#options)
* `RCLONE_PATH`- *Required if using rclone at all"* - the remote rclone path. For s3, this would be the bucket name. See: [Rclone copy docs](https://rclone.org/commands/rclone_copy/)

## Other configuration
* To properly run backups with maria-backup, this container needs to have the source database path mount to `/var/lib/mysql`.
* If you want to mount the backup directory somewhere, that is located at `/backups` inside the container.

## Run with docker-compose
This gives you a mariadb server container opened on port 3306, a backup container running, and a metrics container opened on port 9125 at the path /metrics.  Be sure to change the environment variables for the 3 containers given.

```
version: "2.2"
networks:
  database:

volumes:
  mysql:
  influxdb:

service:
  db:
    image: mariadb:10.3
    ports:
      - "3306:3306"
    volumes:
      - mariadb:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=password
    restart: always
    networks:
      database:
      
  db_backup:
    image: jcwimer/mariadb-rclone-backup-docker:10.3
    restart: always
    networks:
      database:
    environment:
      - DB_PASSWORD=password
      - CRON_SCHEDULE="@hourly"  # hourly
      - DB_USERNAME=root
      - DB_HOST="db" # dont change this
      - DAYS_TO_KEEP="7"
      - RCLONE_TYPE="s3"
      - S3_ACCESS_ID=ACCESS_ID
      - S3_ACCESS_KEY=ACCESS_KEY
      - S3_ENDPOINT=ENDPOINT
      - S3_REGION=REGION
      - RCLONE_EXTRA_ARGS="--no-check-certificate"
      - RCLONE_PATH="mariadb-backups"
  db_metrics:
    image: prom/mysqld-exporter:v0.11.0
    ports:
      - "9125:9215"
    environment:
      - name: DATA_SOURCE_NAME=root:password@(db)/ # only change user and password do not change after @
    command: --web.listen-address=0.0.0.0:9125 --web.telemetry-path=/metrics --collect.heartbeat --collect.heartbeat.database=sys_operator
```

## Run with Kubernetes
With this configuration, you would deploy a mariadb instance with a volume for the database and a volume for the backups. Be sure to change the environment variables for the 3 containers given.

```
apiVersion: v1
kind: Service
metadata:
  name: mariadb
  labels:
    app: mariadb
spec:
  ports:
    - port: 3306
  selector:
    app: mariadb
  clusterIP: None
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mariadb-pv-claim
  labels:
    app: mariadb
spec:
  storageClassName: standard
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mariadb-backups-pv-claim
  labels:
    app: mariadb
spec:
  storageClassName: standard
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mariadb
  labels:
    app: mariadb
spec:
  selector:
    matchLabels:
      app: mariadb
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mariadb
      annotations:
        prometheus.io/port: "9125"
        prometheus.io/scrape: "true"
    spec:
      containers:
      - image: mariadb:10.3
        name: mariadb
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: PASSWORD
        ports:
        - containerPort: 3306
          name: mariadb
        volumeMounts:
        - name: mariadb-persistent-storage
          mountPath: /var/lib/mysql
        resources:
          limits:
            cpu: "0.5"
            memory: "512Mi"
          requests:
            memory: "256Mi"
            cpu: "0.2"
      - image: jcwimer/mariadb-rclone-backup-docker:10.3
        name: mariadb-backup
        env:
        - name: DB_PASSWORD
          value: PASSWORD
        - name: CRON_SCHEDULE
          value: "@hourly"  # hourly
        - name: DB_USERNAME
          value: USERNAME
        - name: DB_HOST
          value: "127.0.0.1" # dont change this
        - name: DAYS_TO_KEEP
          value: "7"
        - name: RCLONE_TYPE
          value: "s3"
        - name: S3_ACCESS_ID
          value: ACCESS_ID
        - name: S3_ACCESS_KEY
          value: ACCESS_KEY
        - name: S3_ENDPOINT
          value: ENDPOINT
        - name: S3_REGION
          value: REGION
        - name: RCLONE_EXTRA_ARGS
          value: "--no-check-certificate"
        - name: RCLONE_PATH
          value: "mariadb-backups"
        volumeMounts:
        - name: mariadb-persistent-storage
          mountPath: /var/lib/mysql
        volumeMounts:
        - name: mariadb-backups-persistent-storage
          mountPath: /backups
        resources:
          limits:
            cpu: "0.2"
            memory: "100Mi"
          requests:
            memory: "50Mi"
            cpu: "0.1"
      - image: prom/mysqld-exporter:v0.11.0
        name: mariadb-exporter
        ports:
        - containerPort: 9125
          name: http"
        args:
        - --web.listen-address=0.0.0.0:9125
        - --web.telemetry-path=/metrics
        - --collect.heartbeat
        - --collect.heartbeat.database=sys_operator
        env:
        - name: DB_PASSWORD
          value: PASSWORD
        - name: DB_USERNAME
          value: USERNAME
        - name: DB_HOST
          value: "127.0.0.1:3306"
        - name: DATA_SOURCE_NAME
          value: $(DB_USERNAME):$(DB_PASSWORD)@($(DB_HOST))/ # don't change
        resources:
          limits:
            cpu: "100m"
            memory: "128Mi"
          requests:
            memory: "32Mi"
            cpu: "10m"
        livenessProbe:
          httpGet:
            path: /metrics
            port: 9125
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 30
      volumes:
      - name: mariadb-persistent-storage
        persistentVolumeClaim:
          claimName: mariadb-pv-claim
      - name: mariadb-backups-persistent-storage
        persistentVolumeClaim:
          claimName: mariadb-backups-pv-claim
```
