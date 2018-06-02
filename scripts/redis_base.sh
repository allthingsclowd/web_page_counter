#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "/var/vagrant_redis_base" ]; then
    exit 0
fi

touch /var/vagrant_redis_base
echo "$REDIS_MASTER_IP     $REDIS_MASTER_NAME" >> /etc/hosts
echo "$REDIS_SLAVE_IP     $REDIS_SLAVE_NAME" >> /etc/hosts

