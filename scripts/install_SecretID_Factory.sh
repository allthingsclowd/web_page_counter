#!/usr/bin/env bash
set -x

source /usr/local/bootstrap/var.env

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}
VAULT_IP=${LEADER_IP}

if [ "${TRAVIS}" == "true" ]; then
    IP="127.0.0.1"
    VAULT_IP=${IP}
fi

export VAULT_ADDR=http://${VAULT_IP}:8200
export VAULT_SKIP_VERIFY=true

if [ -d /vagrant ]; then
    LOG="/vagrant/logs/VaultServiceIDFactory_${HOSTNAME}.log"
else
    LOG="${TRAVIS_HOME}/VaultServiceIDFactory.log"
fi

sudo killall VaultServiceIDFactory &>/dev/null

# check VaultServiceIDFactory binary
[ -f /usr/local/bin/VaultServiceIDFactory ] &>/dev/null || {
    pushd /usr/local/bin
    # download binary and template file from latest release
    sudo bash -c 'curl -s https://api.github.com/repos/allthingsclowd/VaultServiceIDFactory/releases/latest \
    | grep "browser_download_url" \
    | cut -d : -f 2,3 \
    | tr -d \" | wget -i - '
    sudo chmod +x VaultServiceIDFactory
    popd
}

#sudo /usr/local/bin/VaultServiceIDFactory -vault="http://${IP}:8200" &> ${LOG} &
sudo /usr/local/bin/VaultServiceIDFactory -vault="${VAULT_ADDR}" &> ${LOG} &

sleep 5

cat ${LOG}

# initialise the factory service with the provisioner token
WRAPPED_TOKEN=`cat /usr/local/bootstrap/.wrapped-provisioner-token`
curl --header 'Content-Type: application/json' \
    --request POST \
    --data "{\"token\":\""${WRAPPED_TOKEN}"\"}" \
    http://${IP}:8314/initialiseme
