#!/usr/bin/env bash
set -x

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}

if [ -d /vagrant ]; then
  LOG="/vagrant/logs/vault_${HOSTNAME}.log"
else
  LOG="consul.log"
fi

if [ "${TRAVIS}" == "true" ]; then
IP=${IP:-127.0.0.1}
fi

which /usr/local/bin/vault &>/dev/null || {
    pushd /usr/local/bin
    [ -f vault_0.10.3_linux_amd64.zip ] || {
        sudo wget https://releases.hashicorp.com/vault/0.10.3/vault_0.10.3_linux_amd64.zip
    }
    sudo unzip vault_0.10.3_linux_amd64.zip
    sudo chmod +x vault
    popd
}

#vault

#lets kill past instance
sudo killall vault &>/dev/null

#lets delete old consul storage
sudo consul kv delete -recurse vault

sudo /usr/local/bin/vault server  -dev -dev-listen-address=${IP}:8200 -config=/usr/local/bootstrap/conf/vault.hcl &> ${LOG} &
echo vault started
sudo cp /root/.vault-token /usr/local/bootstrap/.vault-token
sleep 3
sudo VAULT_ADDR="http://${IP}:8200" vault kv put secret/hello value=world
sudo VAULT_ADDR="http://${IP}:8200" vault kv get secret/hello


export VAULT_TOKEN=`cat /usr/local/bootstrap/.vault-token`
VAULT_REDIS_PASSWORD=`cat -v /usr/local/bootstrap/var.env | grep -i 'export REDIS_MASTER_PASSWORD' | awk 'BEGIN {FS="="}{ print $2}'`
sudo VAULT_ADDR="http://${IP}:8200" vault kv put secret/development/REDIS_MASTER_PASSWORD value=${VAULT_REDIS_PASSWORD}
sudo VAULT_ADDR="http://${IP}:8200" vault kv get secret/development/REDIS_MASTER_PASSWORD

consul kv put "development/VAULT_ADDR" ${VAULT_ADDR}
consul kv put "development/VAULT_TOKEN" ${VAULT_TOKEN}

consul kv get "development/VAULT_ADDR"
consul kv get "development/VAULT_TOKEN"