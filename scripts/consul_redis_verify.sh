#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

set -x

echo "running client test"

# read redis database password from vault
VAULT_TOKEN=`cat /usr/local/bootstrap/.provisioner-token`
VAULT_ADDR="http://${LEADER_IP}:8200"

TESTIP=${REDIS_MASTER_IP}
TESTPASSWORD=`sudo VAULT_ADDR="http://${LEADER_IP}:8200" VAULT_TOKEN=${VAULT_TOKEN} vault kv get -field=value kv/development/redispassword`

redis-cli -h ${REDIS_MASTER_IP} -p ${REDIS_HOST_PORT} -a ${TESTPASSWORD} set mykey bananas

# initialise VALUE to ensure correct parameter is received from KV store
VALUE="notbananas"
VALUE=`redis-cli -h ${REDIS_MASTER_IP} -p ${REDIS_HOST_PORT} -a ${TESTPASSWORD} get mykey`

if [ "${VALUE}" == "bananas" ]; then
  echo "we got the value ${VALUE}, all good"
else
  echo "warn: not able to get the value, something is not good"
  exit 1
fi