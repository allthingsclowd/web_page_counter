#!/usr/bin/env bash

set -x
source /usr/local/bootstrap/var.env
echo 'Start Setup of Go App Deployment Environment'

IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8;exit}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.9" {print $2}'`
IP=${CIDR%%/24}

if [ -d /vagrant ]; then
  LOG="/vagrant/logs/go_app_${HOSTNAME}.log"
else
  LOG="go_app_${HOSTNAME}.log"
fi

if [ "${TRAVIS}" == "true" ]; then
  ROOTCERTPATH=tmp
  IP=${IP:-127.0.0.1}
  LEADER_IP=${IP}
else
  ROOTCERTPATH=etc
fi

export ROOTCERTPATH


# delayed added to ensure consul has started on host - intermittent failures
sleep 2

export BootStrapCertTool="https://raw.githubusercontent.com/allthingsclowd/BootstrapCertificateTool/${certbootstrap_version}/scripts/Generate_PKI_Certificates_For_Lab.sh"

wget -O - ${BootStrapCertTool} | sudo bash -s wpc "server.node.global.wpc" "client.node.global.wpc" "${IP}"


AGENTTOKEN=`sudo VAULT_TOKEN=reallystrongpassword VAULT_ADDR="https://${LEADER_IP}:8322" vault kv get -field "value" kv/development/consulagentacl`
export CONSUL_HTTP_TOKEN=${AGENTTOKEN}

/usr/local/go/bin/go get ./...
/usr/local/go/bin/go build -o webcounter -i main.go
./webcounter -consulACL=${CONSUL_HTTP_TOKEN} \
             -ip="0.0.0.0" \
             -consulIP="127.0.0.1:8321" \
             -consulCA="/tmp/ssl/certs/consul-ca-chain.pem" \
             -vaultCA="/tmp/ssl/certs/vault-ca-chain.pem" \
             -consulcert="/tmp/consul.d/pki/tls/certs/consul-cli.pem" \
             -vaultcert="/tmp/vault.d/pki/tls/certs/vault-cli.pem" \
             -consulkey="/tmp/consul.d/pki/tls/private/consul-cli-key.pem" \
             -appcert="/tmp/ssl/certs/wpc-ca-chain.pem" \
             -appkey="/tmp/wpc.d/pki/tls/private/wpc-server-key.pem" \
             -vaultkey="/tmp/vault.d/pki/tls/private/vault-cli-key.pem" &

# delay added to allow webcounter startup
sleep 2

ps -ef | grep webcounter 

ls -al /${ROOTCERTPATH}/ssl/certs/wpc-ca-chain.pem
ls -al /${ROOTCERTPATH}/wpc.d/pki/tls/private/wpc-cli-key.pem
ls -al /${ROOTCERTPATH}/wpc.d/pki/tls/certs/wpc-cli.pem


# check health
echo "APPLICATION HEALTH"
curl   \
    http://127.0.0.1:8314/health

openssl s_client -connect localhost:8080 -CAfile /${ROOTCERTPATH}/ssl/certs/wpc-ca-chain.pem

openssl s_client -connect localhost:8080/health -CAfile /${ROOTCERTPATH}/ssl/certs/wpc-ca-chain.pem

openssl s_client -connect localhost:8080/health -CAfile /tmp/ssl/CA.crt

curl \
    --cacert "/${ROOTCERTPATH}/ssl/certs/wpc-ca-chain.pem" \
    --key "/${ROOTCERTPATH}/wpc.d/pki/tls/private/wpc-cli-key.pem" \
    --cert "/${ROOTCERTPATH}/wpc.d/pki/tls/certs/wpc-cli.pem" \
    --verbose \
    https://localhost:8080/health

curl \
    --cacert "/${ROOTCERTPATH}/ssl/certs/wpc-ca-chain.pem" \
    --key "/${ROOTCERTPATH}/wpc.d/pki/tls/private/wpc-cli-key.pem" \
    --cert "/${ROOTCERTPATH}/wpc.d/pki/tls/certs/wpc-cli.pem" \
    --verbose \
    https://localhost:8080

curl \
    --cacert "/${ROOTCERTPATH}/ssl/certs/wpc-ca-chain.pem" \
    --key "/${ROOTCERTPATH}/wpc.d/pki/tls/private/wpc-cli-key.pem" \
    --cert "/${ROOTCERTPATH}/wpc.d/pki/tls/certs/wpc-cli.pem" \
    --verbose \
    https://127.0.0.1:8080/health

curl \
    --cacert "/${ROOTCERTPATH}/ssl/certs/wpc-ca-chain.pem" \
    --key "/${ROOTCERTPATH}/wpc.d/pki/tls/private/wpc-cli-key.pem" \
    --cert "/${ROOTCERTPATH}/wpc.d/pki/tls/certs/wpc-cli.pem" \
    --verbose \
    https://127.0.0.1:8080

# page_hit_counter=`lynx -accept_all_cookies --dump http://127.0.0.1:8080`
# echo $page_hit_counter
# next_page_hit_counter=`lynx -accept_all_cookies --dump http://127.0.0.1:8080`

# echo $next_page_hit_counter
# if (( next_page_hit_counter > page_hit_counter )); then
# echo "Successful Page Hit Update"
# exit 0
# else
#  echo "Failed Page Hit Update"
# exit 1
# fi
# The End
