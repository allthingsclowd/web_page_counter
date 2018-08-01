#!/usr/bin/env bash
set -e

source /usr/local/bootstrap/var.env

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "/var/vagrant_redis" ]; then
    exit 0
fi

# install this package in base image in the future
which jq &>/dev/null || {
  sudo apt-get update
  sudo apt-get install -y jq
}

touch /var/vagrant_redis
REDIS_MASTER_PASSWORD=`openssl rand -base64 32`
echo "${REDIS_MASTER_IP}     ${REDIS_MASTER_NAME}" >> /etc/hosts
sudo cp /usr/local/bootstrap/conf/master.redis.conf /etc/redis/redis.conf
sudo chown redis:redis /etc/redis/redis.conf
sudo chmod 640 /etc/redis/redis.conf
echo "requirepass ${REDIS_MASTER_PASSWORD}" | sudo tee -a /etc/redis/redis.conf

# copy a consul service definition directory
sudo mkdir -p /etc/consul.d
sudo cp -p /usr/local/bootstrap/conf/consul.d/redis.json /etc/consul.d/redis.json
sudo systemctl restart redis-server
sudo killall -1 consul

# Put Redis Password in Vault

VAULT_TOKEN=`cat /usr/local/bootstrap/.vault-token`
VAULT_ADDR="http://${LEADER_IP}:8200"

curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data "{ \"data\" : { \"REDIS_MASTER_PASSWORD\" : \"${REDIS_MASTER_PASSWORD}\" } }" \
    ${VAULT_ADDR}/v1/secret/data/development
