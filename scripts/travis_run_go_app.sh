#!/usr/bin/env bash
set -x

# delayed added to ensure consul has started on host - intermittent failures
sleep 2

AGENTTOKEN=`sudo VAULT_TOKEN=reallystrongpassword VAULT_ADDR="https://${LEADER_IP}:8322" vault kv get -field "value" kv/development/consulagentacl`
export CONSUL_HTTP_TOKEN=${AGENTTOKEN}

/usr/local/go/bin/go get ./...
/usr/local/go/bin/go build -o webcounter -i main.go
./webcounter -consulACL=${CONSUL_HTTP_TOKEN} \
             -ip="0.0.0.0" \
             -consulIP="127.0.0.1:8321" \
             -consulCA="/tmp/ssl/certs/consul-root-signed-intermediate-ca.pem" \
             -vaultCA="/tmp/ssl/certs/vault-agent-ca.pem" \
             -consulcert="/tmp/consul.d/pki/tls/certs/consul-cli.pem" \
             -vaultcert="/tmp/vault.d/pki/tls/certs/vault-client.pem" \
             -consulkey="/tmp/consul.d/pki/tls/private/consul-cli-key.pem" \
             -vaultkey="/tmp/vault.d/pki/tls/private/vault-client-key.pem" &

# delay added to allow webcounter startup
sleep 2

ps -ef | grep webcounter 

# check health
echo "APPLICATION HEALTH"
curl -s http://127.0.0.1:8314/health

curl -s http://localhost:8080/health

curl -s http://localhost:8080

curl -s http://127.0.0.1:8080/health

curl -s http://127.0.0.1:8080

page_hit_counter=`lynx --dump http://127.0.0.1:8080`
echo $page_hit_counter
next_page_hit_counter=`lynx --dump http://127.0.0.1:8080`

echo $next_page_hit_counter
if (( next_page_hit_counter > page_hit_counter )); then
 echo "Successful Page Hit Update"
 exit 0
else
 echo "Failed Page Hit Update"
 exit 1
fi
# The End
