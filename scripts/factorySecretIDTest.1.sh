#!/usr/bin/env bash

setup_environment () {

    
    source /usr/local/bootstrap/var.env
    
    IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
    CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
    IP=${CIDR%%/24}
    VAULT_IP=${LEADER_IP}
    FACTORY_IP=${LEADER_IP}
    
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

}

verify_factory_service () {

    curl http://${FACTORY_IP}:8314/health 

    STATUS=`curl http://${FACTORY_IP}:8314/health`
    if [ "${STATUS}" = "UNINITIALISED" ] || [ "${STATUS}" = "INITIALISED" ] || [ "${STATUS}" = "TOKENDELIVERED" ];then
        echo "APPLICATION VERIFICATION SUCCESSFUL"
        exit 0
    else
        echo "APPLICATION VERIFICATION FAILED"
        exit 1
    fi

}

set -x
echo 'Start of Factory Service Test'
setup_environment
verify_factory_service
