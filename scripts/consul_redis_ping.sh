#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

set -x

# read redis database password from vault
export VAULT_CLIENT_KEY=/usr/local/bootstrap/certificate-config/hashistack-client-key.pem
export VAULT_CLIENT_CERT=/usr/local/bootstrap/certificate-config/hashistack-client.pem
export VAULT_CACERT=/usr/local/bootstrap/certificate-config/hashistack-ca.pem
export VAULT_SKIP_VERIFY=true
export VAULT_ADDR="https://${LEADER_IP}:8322"
export VAULT_TOKEN=reallystrongpassword
VAULT_TOKEN=`vault kv get -field "value" kv/development/vaultdbtoken`

TESTPASSWORD=`VAULT_ADDR="https://${LEADER_IP}:8322" VAULT_TOKEN=${VAULT_TOKEN} /usr/local/bin/vault kv get -field=value kv/development/redispassword`

echo "running client ping test"

RESULT=`redis-cli -h 127.0.0.1 -p 6379 -a ${TESTPASSWORD} ping`

if [ "$RESULT" == "PONG" ]; then
    echo 'Success Redis Ping resulted in '$RESULT
    exit 0
fi

echo 'Failed Redis Ping resulted in '$RESULT
exit 2