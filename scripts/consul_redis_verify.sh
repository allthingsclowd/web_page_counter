#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

set -x

if [ "${TRAVIS}" == "true" ]; then
  ROOTCERTPATH=tmp
  IP=${IP:-127.0.0.1}
  LEADER_IP=${IP}
else
  ROOTCERTPATH=etc
fi

export ROOTCERTPATH

echo "running client test"

# read redis database password from vault
export VAULT_CLIENT_KEY=/${ROOTCERTPATH}/vault.d/pki/tls/private/vault-cli-key.pem
export VAULT_CLIENT_CERT=/${ROOTCERTPATH}/vault.d/pki/tls/certs/vault-cli.pem
export VAULT_CACERT=/${ROOTCERTPATH}/ssl/certs/vault-ca-chain.pem
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