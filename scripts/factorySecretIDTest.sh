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
    if [ "${STATUS}" = "UNINITIALISED" ];then
        echo "Initialisng the Factory Service with a Provisioner Token"
            # Initialise with Vault Token
        WRAPPED_VAULT_TOKEN=`sudo VAULT_TOKEN=reallystrongpassword VAULT_ADDR="http://${LEADER_IP}:8200" vault kv get -field "value" kv/development/wrappedprovisionertoken`

        curl --header "Content-Type: application/json" \
        --request POST \
        --data "{\"token\":\"${WRAPPED_VAULT_TOKEN}\"}" \
        http://${FACTORY_IP}:8314/initialiseme
    fi
    # Get a secret ID and test access to the Vault KV Secret
    ROLENAME="id-factory"

    WRAPPED_SECRET_ID=`curl --header "Content-Type: application/json" \
    --request POST \
    --data "{\"RoleName\":\"${ROLENAME}\"}" \
    http://${FACTORY_IP}:8314/approlename`

    echo "WRAPPED_SECRET_ID : ${WRAPPED_SECRET_ID}"

    SECRET_ID=`curl --header "X-Vault-Token: ${WRAPPED_SECRET_ID}" \
        --request POST \
        ${VAULT_ADDR}/v1/sys/wrapping/unwrap | jq -r .data.secret_id`
    
    echo "SECRET_ID : ${SECRET_ID}"
    
    # retrieve the appRole-id from the approle - /usr/local/bootstrap/.appRoleID
    APPROLEID=`sudo VAULT_TOKEN=reallystrongpassword VAULT_ADDR="http://${LEADER_IP}:8200" vault kv get -field "value" kv/development/approleid`

    echo "APPROLEID : ${APPROLEID}"

    # login
    tee id-factory-secret-id-login.json <<EOF
    {
    "role_id": "${APPROLEID}",
    "secret_id": "${SECRET_ID}"
    }
EOF

    APPTOKEN=`curl \
        --request POST \
        --data @id-factory-secret-id-login.json \
        ${VAULT_ADDR}/v1/auth/approle/login | jq -r .auth.client_token`
    
    echo "Reading secret using newly acquired token"

    RESULT=`curl \
        --header "X-Vault-Token: ${APPTOKEN}" \
        ${VAULT_ADDR}/v1/kv/development/redispassword | jq -r .data.value`

    echo "SECRET : ${RESULT}"

    echo "APPLICATION VERIFICATION COMPLETE"

    curl http://${FACTORY_IP}:8314/health 

}

set -x
echo 'Start of Factory Service Test'
setup_environment
verify_factory_service
echo 'End of Factory Service Test'
exit 0
