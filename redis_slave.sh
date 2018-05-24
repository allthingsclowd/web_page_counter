#!/usr/bin/env bash

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "/var/vagrant_redis_slave" ]; then
    exit 0
fi

touch /var/vagrant_redis_slave
sudo mv slave.redis.conf /etc/redis/redis.conf
sudo chown redis:redis /etc/redis/redis.conf
sudo chmod 640 /etc/redis/redis.conf
echo "requirepass $REDIS_SLAVE_PASSWORD" | sudo tee -a /etc/redis/redis.conf
echo "slaveof $REDIS_MASTER_IP 6379" | \
    sudo tee -a /etc/redis/redis.conf
echo "masterauth $REDIS_MASTER_PASSWORD" | sudo tee -a /etc/redis/redis.conf
sudo systemctl restart redis-server