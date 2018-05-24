#!/usr/bin/env bash

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "/var/vagrant_redis_base" ]; then
    exit 0
fi

touch /var/vagrant_redis_base
echo "$REDIS_MASTER_IP     $REDIS_MASTER_NAME" >> /etc/hosts
echo "$REDIS_SLAVE_IP     $REDIS_SLAVE_NAME" >> /etc/hosts
sudo apt-get update && \
    sudo apt-get upgrade -y && \
    sudo apt-get install -y redis-server=2:3.0.6-1