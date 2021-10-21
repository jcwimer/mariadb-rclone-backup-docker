FROM ubuntu:focal

RUN apt-get -qq update \
  && DEBIAN_FRONTEND=noninteractive apt-get -qq install -y \
    zip \
    unzip \
    mariadb-backup \
    curl \
    cron \
  && apt-get -qq clean \
  && apt-get autoremove -y \
  && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*
    
RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip \
  && unzip rclone-current-linux-amd64.zip \
  && cp rclone-*-linux-amd64/rclone /usr/bin/ \
  && chown root:root /usr/bin/rclone \
  && chmod 755 /usr/bin/rclone \
  && rm rclone-current-linux-amd64.zip \
  && rm -rf rclone-*-linux-amd64
  
COPY backup.sh /root/backup.sh
RUN chmod +x /root/backup.sh

COPY create-cron.sh /root/create-cron.sh
RUN chmod +x /root/create-cron.sh

COPY create-rclone-conf.sh /root/create-rclone-conf.sh
RUN chmod +x /root/create-rclone-conf.sh

CMD ["/root/create-cron.sh"]
