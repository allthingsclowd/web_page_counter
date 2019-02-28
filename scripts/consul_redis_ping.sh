#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

set -x

# read redis database password from vault
VAULT_TOKEN=`sudo VAULT_TOKEN=reallystrongpassword VAULT_ADDR="http://${IP}:8200" vault kv get -field "value" kv/development/vaultdbtoken`
VAULT_ADDR="http://${LEADER_IP}:8200"

TESTPASSWORD=`VAULT_ADDR="http://${LEADER_IP}:8200" VAULT_TOKEN=${VAULT_TOKEN} /usr/local/bin/vault kv get -field=value kv/development/redispassword`

echo "running client ping test"

RESULT=`redis-cli -h 127.0.0.1 -p 6379 -a ${TESTPASSWORD} ping`

if [ "$RESULT" == "PONG" ]; then
    echo 'Success Redis Ping resulted in '$RESULT
    exit 0
fi

echo 'Failed Redis Ping resulted in '$RESULT
exit 2