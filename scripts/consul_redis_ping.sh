#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

set -e

# read redis database password from vault
VAULT_TOKEN=`cat /usr/local/bootstrap/.vault-token`
VAULT_ADDR="http://${LEADER_IP}:8200"

TESTIP=${REDIS_MASTER_IP}
TESTPASSWORD=`curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    ${VAULT_ADDR}/v1/secret/data/development \
    | jq -r .data.data.REDIS_MASTER_PASSWORD`

echo "running client ping test"

RESULT=`redis-cli -h ${TESTIP} -p ${REDIS_HOST_PORT} -a ${TESTPASSWORD} ping`

if [ "$RESULT" == "PONG" ]; then
    echo 'Success Redis Ping resulted in '$RESULT
    exit 0
fi

echo 'Failed Redis Ping resulted in '$RESULT
exit 2