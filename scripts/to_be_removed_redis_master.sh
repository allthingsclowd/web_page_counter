#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "/var/vagrant_redis_master" ]; then
    exit 0
fi

touch /var/vagrant_redis_master
sudo cp /usr/local/bootstrap/conf/master.redis.conf /etc/redis/redis.conf
sudo chown redis:redis /etc/redis/redis.conf
sudo chmod 640 /etc/redis/redis.conf
echo "requirepass $REDIS_MASTER_PASSWORD" | sudo tee -a /etc/redis/redis.conf
sudo systemctl restart redis-server
