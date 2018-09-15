#!/usr/bin/env bash
set -x

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}

if [ -d /vagrant ]; then
  LOG="/vagrant/logs/secret_service_${HOSTNAME}.log"
else
  LOG="secret_service.log"
fi

if [ "${TRAVIS}" == "true" ]; then
IP=${IP:-127.0.0.1}
fi

sudo killall VaultServiceIDFactory &>/dev/null

# check VaultServiceIDFactory binary
[ -f /usr/local/bin/VaultServiceIDFactory ] &>/dev/null || {
    pushd /usr/local/bin
    # download binary and template file from latest release
    curl -s https://api.github.com/repos/allthingsclowd/VaultServiceIDFactory/releases/latest \
    | grep "browser_download_url" \
    | cut -d : -f 2,3 \
    | tr -d \" | sudo wget -i -
    sudo chmod +x VaultServiceIDFactory
    popd
}

#sudo /usr/local/bin/VaultServiceIDFactory -vault="http://${IP}:8200" &> ${LOG} &
sudo /usr/local/bin/VaultServiceIDFactory -vault="bananas" &> ${LOG} &

sleep 5
# initialise the factory service with the provisioner token
WRAPPED_TOKEN=`cat /usr/local/bootstrap/.wrapped-provisioner-token`
curl --header 'Content-Type: application/json' \
    --request POST \
    --data "{\"token\":\""${WRAPPED_TOKEN}"\"}" \
    http://${IP}:8314/initialiseme
