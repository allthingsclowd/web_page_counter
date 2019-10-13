#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

set -x

echo "running client test"

# read redis database password from vault
export VAULT_CLIENT_KEY=/usr/local/bootstrap/certificate-config/hashistack-client-key.pem
export VAULT_CLIENT_CERT=/usr/local/bootstrap/certificate-config/hashistack-client.pem
export VAULT_CACERT=/usr/local/bootstrap/certificate-config/hashistack-ca.pem
export VAULT_SKIP_VERIFY=true
export VAULT_ADDR="https://${LEADER_IP}:8322"
export VAULT_TOKEN=reallystrongpassword
VAULT_TOKEN=`vault kv get -field "value" kv/development/vaultdbtoken`

TESTPASSWORD=`/usr/local/bin/vault kv get -field=value kv/development/redispassword`

redis-cli -h 127.0.0.1 -p 6379 -a ${TESTPASSWORD} set mykey bananas

# initialise VALUE to ensure correct parameter is received from KV store
VALUE="notbananas"
VALUE=`redis-cli -h 127.0.0.1 -p 6379 -a ${TESTPASSWORD} get mykey`

if [ "${VALUE}" == "bananas" ]; then
  echo "we got the value ${VALUE}, all good"
else
  echo "warn: not able to get the value, something is not good"
  exit 1
fi
exit 0