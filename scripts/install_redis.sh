#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "/var/vagrant_redis" ]; then
    exit 0
fi

touch /var/vagrant_redis
echo "$REDIS_MASTER_IP     $REDIS_MASTER_NAME" >> /etc/hosts
echo "$REDIS_SLAVE_IP     $REDIS_SLAVE_NAME" >> /etc/hosts

# check for redis hostname => master
if [[ "${HOSTNAME}" =~ "master" ]]; then
 sudo cp /usr/local/bootstrap/conf/master.redis.conf /etc/redis/redis.conf
 sudo chown redis:redis /etc/redis/redis.conf
 sudo chmod 640 /etc/redis/redis.conf
 echo "requirepass $REDIS_MASTER_PASSWORD" | sudo tee -a /etc/redis/redis.conf
else 
 sudo cp /usr/local/bootstrap/conf/slave.redis.conf /etc/redis/redis.conf
 sudo chown redis:redis /etc/redis/redis.conf
 sudo chmod 640 /etc/redis/redis.conf
 echo "requirepass $REDIS_SLAVE_PASSWORD" | sudo tee -a /etc/redis/redis.conf
 echo "slaveof $REDIS_MASTER_IP 6379" | \
    sudo tee -a /etc/redis/redis.conf
 echo "masterauth $REDIS_MASTER_PASSWORD" | sudo tee -a /etc/redis/redis.conf
fi

sudo systemctl restart redis-server