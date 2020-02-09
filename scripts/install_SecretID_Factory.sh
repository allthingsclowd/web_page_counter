#!/usr/bin/env bash

register_secret_id_service_with_consul () {
    
    echo 'Start to register secret_id service with Consul Service Discovery'

    # configure web service definition
    tee secretid_service.json <<EOF
    {
      "Name": "approle",
      "Id": "approle",
      "Tags": [
        "approle",
        "secret-id"
      ],
      "Port": 8314,
      "Meta": {
        "SecretID-Factory-Service": "0.0.1"
      },
      "EnableTagOverride": false,
      "checks": [
          {
            "name": "Factory Service SecretID",
            "http": "http://127.0.0.1:8314/health",
            "tls_skip_verify": true,
            "method": "GET",
            "interval": "10s",
            "timeout": "5s"
          }
        ],
        "connect": { "sidecar_service": {} }
    }
EOF

  # Register the service in consul via the local Consul agent api
  sudo curl \
      --request PUT \
      --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
      --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
      --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --data @secretid_service.json \
      ${CONSUL_HTTP_ADDR}/v1/agent/service/register

  # List the locally registered services via local Consul api
  sudo curl \
    --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
    --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
    --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    ${CONSUL_HTTP_ADDR}/v1/agent/services | jq -r .

  # List the services regestered on the Consul server
  sudo curl \
    --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
    --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
    --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    ${CONSUL_HTTP_ADDR}/v1/catalog/services | jq -r .
   
    echo 'Register Vault Secret ID Factory Service with Consul Service Discovery Complete'

}

create_service () {
  # create a new systemd service
  # param 1 ${1}: service/serviceuser name
  # param 2 ${2}: service description
  # param 3 ${3}: service start command
  if [ ! -f /etc/systemd/system/${1}.service ]; then
    
    create_service_user ${1}
    
    sudo tee /etc/systemd/system/${1}.service <<EOF
### BEGIN INIT INFO
# Provides:          ${1}
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${1} service
# Description:       ${2}
### END INIT INFO

[Unit]
Description=${2}
Requires=network-online.target
After=network-online.target

[Service]
Type=simple
User=${1}
Group=${1}
PIDFile=/var/run/${1}/${1}.pid
PermissionsStartOnly=true
ExecStartPre=-/bin/mkdir -p /var/run/${1}
ExecStartPre=/bin/chown -R ${1}:${1} /var/run/${1}
ExecStart=${3}
ExecReload=/bin/kill -HUP ${MAINPID}
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload

  fi

}

create_service_user () {
  
  if ! grep ${1} /etc/passwd >/dev/null 2>&1; then
    echo "Creating ${1} user to run the ${1} service"
    sudo useradd --system --home /etc/${1}.d --shell /bin/false ${1}
    sudo mkdir --parents /opt/${1} /usr/local/${1} /etc/${1}.d
    sudo chown --recursive ${1}:${1} /opt/${1} /etc/${1}.d /usr/local/${1}
  fi

}

start_envoy_proxy_service () {
  # start the new service mesh proxy for the application
  # param 1 ${1}: app-proxy name
  # param 2 ${2}: app-proxy service description
  # param 3 ${3}: consul host service name
  # param 4 ${4}: envoy proxy admin port needs to be different if running multiple instances on same host network

  create_service "${1}" "${2}" "/usr/local/bin/consul connect envoy \
                                                        -http-addr=https://127.0.0.1:8321 \
                                                        -ca-file=/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem \
                                                        -client-cert=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem \
                                                        -client-key=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem \
                                                        -token=${CONSUL_HTTP_TOKEN} \
                                                        -sidecar-for ${3} \
                                                        -admin-bind localhost:${4}"
  sudo usermod -a -G webpagecountercerts ${1}
  sudo systemctl start ${1}
  #sudo systemctl status ${1}
  echo "${1} Proxy App Service Build Complete"
}


setup_environment () {

    
    source /usr/local/bootstrap/var.env
    
    IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8}'`
    CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.9" {print $2}'`
    IP=${CIDR%%/24}
    VAULT_IP=${LEADER_IP}
    
    if [ "${TRAVIS}" == "true" ]; then
        ROOTCERTPATH=tmp
        IP=${IP:-127.0.0.1}
        LEADER_IP=${IP}
    else
        ROOTCERTPATH=etc
    fi

    export ROOTCERTPATH

    sudo /usr/local/bootstrap/scripts/create_certificate.sh consul hashistack1 30 ${IP} client
    sudo chown -R consul:consul /${ROOTCERTPATH}/consul.d
    sudo chmod -R 755 /${ROOTCERTPATH}/consul.d  

    sudo /usr/local/bootstrap/scripts/create_certificate.sh vault hashistack1 30 ${IP} client
    sudo chown -R vault:vault /${ROOTCERTPATH}/vault.d
    sudo chmod -R 755 /${ROOTCERTPATH}/vault.d
    sudo chmod -R 755 /${ROOTCERTPATH}/ssl/certs
    sudo chmod -R 755 /${ROOTCERTPATH}/ssl/private

    echo 'Set environmental bootstrapping data in VAULT'

    export VAULT_ADDR=https://${VAULT_IP}:8322
    export VAULT_CLIENT_KEY=/${ROOTCERTPATH}/vault.d/pki/tls/private/vault-client-key.pem
    export VAULT_CLIENT_CERT=/${ROOTCERTPATH}/vault.d/pki/tls/certs/vault-client.pem
    export VAULT_CACERT=/${ROOTCERTPATH}/ssl/certs/vault-agent-ca.pem
    export VAULT_SKIP_VERIFY=true

    AGENTTOKEN=`VAULT_TOKEN=reallystrongpassword VAULT_ADDR="https://${LEADER_IP}:8322" vault kv get -field "value" kv/development/consulagentacl`
    export CONSUL_HTTP_TOKEN=${AGENTTOKEN}

    # Configure consul environment variables for use with certificates 
    export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
    export CONSUL_CACERT=/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem
    export CONSUL_CLIENT_CERT=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem
    export CONSUL_CLIENT_KEY=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem
    export CONSUL_HTTP_SSL=true
    export CONSUL_GRPC_ADDR=https://127.0.0.1:8502

    # Configure CA Certificates for APP on host OS
    sudo mkdir -p /usr/local/share/ca-certificates
    sudo apt-get install ca-certificates -y
    #sudo openssl x509 -outform der -in /etc/ssl/certs/consul-agent-ca.pem -out /usr/local/bootstrap/certificate-config/hashistack-ca.crt
    sudo cp /etc/ssl/certs/consul-agent-ca.pem /usr/local/share/ca-certificates/consul-ca.crt
    sudo cp /etc/ssl/certs/nomad-agent-ca.pem /usr/local/share/ca-certificates/nomad-ca.crt
    sudo cp /etc/ssl/certs/vault-agent-ca.pem /usr/local/share/ca-certificates/vault-ca.crt
    sudo update-ca-certificates

    if [ -d /vagrant ]; then
        LOG="/vagrant/logs/VaultServiceIDFactory_${HOSTNAME}.log"
    else
        LOG="${TRAVIS_HOME}/VaultServiceIDFactory.log"
    fi

}

install_secret_id_application () {
    
    sudo killall VaultServiceIDFactory &>/dev/null

    # Added loop below to overcome Travis-CI download issue
    RETRYDOWNLOAD="1"

    while [ ${RETRYDOWNLOAD} -lt 10 ] && [ ! -f /usr/local/bin/VaultServiceIDFactory ]
    do
        pushd /usr/local/bin
        echo 'Vault SecretID Service Download - Take ${RETRYDOWNLOAD}' 
        # download binary and template file from latest release
        sudo bash -c 'curl -s -L https://api.github.com/repos/allthingsclowd/VaultServiceIDFactory/releases/latest \
        | grep "browser_download_url" \
        | cut -d : -f 2,3 \
        | tr -d \" | wget -q -i - '
        
        popd
        RETRYDOWNLOAD=$[${RETRYDOWNLOAD}+1]
        sleep 5
    done

    [  -f /usr/local/bin/VaultServiceIDFactory  ] &>/dev/null || {
        echo 'Failed to download Vault Secret ID Factory Service'
        exit 1
    }

    sudo chmod +x /usr/local/bin/VaultServiceIDFactory

    if [ ! "${TRAVIS}" == "true" ]; then
        create_service factory "SecretID Factory Service" \
                               "/usr/local/bin/VaultServiceIDFactory \
                               -ip=127.0.0.1 \
                               -vault=\"${VAULT_ADDR}\" \
                               -vaultCA=\"/${ROOTCERTPATH}/ssl/certs/vault-agent-ca.pem\" \
                               -vaultcert=\"/${ROOTCERTPATH}/vault.d/pki/tls/certs/vault-client.pem\" \
                               -vaultkey=\"/${ROOTCERTPATH}/vault.d/pki/tls/private/vault-client-key.pem\""
        sudo systemctl start factory
        #sudo systemctl status factory
        register_secret_id_service_with_consul
    else
        sudo /usr/local/bin/VaultServiceIDFactory -vault="${VAULT_ADDR}" \
                                                  -vaultCA="/${ROOTCERTPATH}/ssl/certs/vault-agent-ca.pem" \
                                                  -vaultcert="/${ROOTCERTPATH}/vault.d/pki/tls/certs/vault-client.pem" \
                                                  -vaultkey="/${ROOTCERTPATH}/vault.d/pki/tls/private/vault-client-key.pem" &> ${LOG} &
    fi



    sleep 15

    # start envoy proxy
    sudo /usr/local/bootstrap/scripts/install_envoy_proxy.sh  approle "App Role Vault Secret ID Factory "-sidecar-for approle" 19002 ${CONSUL_HTTP_TOKEN}
    sleep 5

    curl http://127.0.0.1:8314/health 

}

verify_go_application () {                                                                         

    if [ "${TRAVIS}" == "true" ]; then

        curl http://127.0.0.1:8314/health 

        IP=127.0.0.1
        curl -s http://127.0.0.1:8314/health 
        # Initialise with Vault Token
        WRAPPED_VAULT_TOKEN=`VAULT_TOKEN=reallystrongpassword VAULT_ADDR="https://${LEADER_IP}:8322" vault kv get -field "value" kv/development/wrappedprovisionertoken`
        
        curl -s --header "Content-Type: application/json" \
        --request POST \
        --data "{\"token\":\"${WRAPPED_VAULT_TOKEN}\"}" \
        http://127.0.0.1:8314/initialiseme

        curl -s http://127.0.0.1:8314/health 
        # Get a secret ID and test access to the Vault KV Secret
        ROLENAME="id-factory"

        WRAPPED_SECRET_ID=`curl -s --header "Content-Type: application/json" \
        --request POST \
        --data "{\"RoleName\":\"${ROLENAME}\"}" \
        http://127.0.0.1:8314/approlename`

        echo "WRAPPED_SECRET_ID : ${WRAPPED_SECRET_ID}"

        SECRET_ID=`curl -s --header "X-Vault-Token: ${WRAPPED_SECRET_ID}" \
            --request POST \
            ${VAULT_ADDR}/v1/sys/wrapping/unwrap | jq -r .data.secret_id`
        
        echo "SECRET_ID : ${SECRET_ID}"
        
        # retrieve the appRole-id from the approle - /usr/local/bootstrap/.appRoleID
        APPROLEID=`VAULT_TOKEN=reallystrongpassword VAULT_ADDR="https://${LEADER_IP}:8322" vault kv get -field "value" kv/development/approleid`

        echo "APPROLEID : ${APPROLEID}"

        # login
        tee id-factory-secret-id-login.json <<EOF
        {
        "role_id": "${APPROLEID}",
        "secret_id": "${SECRET_ID}"
        }
EOF

        APPTOKEN=`curl -s \
            --request POST \
            --data @id-factory-secret-id-login.json \
            ${VAULT_ADDR}/v1/auth/approle/login | jq -r .auth.client_token`

        cat ${LOG}
        
        echo "Reading secret using newly acquired token"

        RESULT=`curl -s \
            --header "X-Vault-Token: ${APPTOKEN}" \
            ${VAULT_ADDR}/v1/kv/example_password | jq -r .data.value`

        if [ "${RESULT}" != "You_have_successfully_accessed_a_secret_password" ];then
            echo "APPLICATION VERIFICATION FAILURE"
            exit 1
        fi

        echo "APPLICATION VERIFICATION SUCCESSFUL"

        curl -s http://127.0.0.1:8314/health 
    else
        # start client client proxy
        start_client_proxy_service democlientproxy "SecretID Service connect client proxy" "approle" "8314"

        curl http://127.0.0.1:8314/health 
        # converting for consul connect - point to loopback
        IP=127.0.0.1
        curl -s http://127.0.0.1:8314/health 
        # Initialise with Vault Token
        WRAPPED_VAULT_TOKEN=`VAULT_TOKEN=reallystrongpassword VAULT_ADDR="https://${LEADER_IP}:8322" vault kv get -field "value" kv/development/wrappedprovisionertoken`
   
        curl -s --header "Content-Type: application/json" \
        --request POST \
        --data "{\"token\":\"${WRAPPED_VAULT_TOKEN}\"}" \
        http://127.0.0.1:8314/initialiseme

        curl -s http://127.0.0.1:8314/health 
        # Get a secret ID and test access to the Vault KV Secret
        ROLENAME="id-factory"

        WRAPPED_SECRET_ID=`curl -s --header "Content-Type: application/json" \
        --request POST \
        --data "{\"RoleName\":\"${ROLENAME}\"}" \
        http://127.0.0.1:8314/approlename`

        echo "WRAPPED_SECRET_ID : ${WRAPPED_SECRET_ID}"

        SECRET_ID=`curl -s --header "X-Vault-Token: ${WRAPPED_SECRET_ID}" \
            --request POST \
            ${VAULT_ADDR}/v1/sys/wrapping/unwrap | jq -r .data.secret_id`
        
        echo "SECRET_ID : ${SECRET_ID}"
        
        # retrieve the appRole-id from the approle - /usr/local/bootstrap/.appRoleID
        APPROLEID=`VAULT_TOKEN=reallystrongpassword VAULT_ADDR="https://${LEADER_IP}:8322" vault kv get -field "value" kv/development/approleid`

        echo "APPROLEID : ${APPROLEID}"

        # login
        tee id-factory-secret-id-login.json <<EOF
        {
        "role_id": "${APPROLEID}",
        "secret_id": "${SECRET_ID}"
        }
EOF

        APPTOKEN=`curl -s \
            --request POST \
            --data @id-factory-secret-id-login.json \
            ${VAULT_ADDR}/v1/auth/approle/login | jq -r .auth.client_token`

        cat ${LOG}
        
        echo "Reading secret using newly acquired token"

        RESULT=`curl -s \
            --header "X-Vault-Token: ${APPTOKEN}" \
            ${VAULT_ADDR}/v1/kv/example_password | jq -r .data.value`

        if [ "${RESULT}" != "You_have_successfully_accessed_a_secret_password" ];then
            echo "APPLICATION VERIFICATION FAILURE"
            exit 1
        fi

        echo "APPLICATION VERIFICATION SUCCESSFUL"

        curl -s http://${IP}:8314/health 
    fi



}

set -x
echo 'Start of Factory Service Installation'
setup_environment
install_secret_id_application
# install_go_application
#verify_go_application

# initialise the factory service with the provisioner token

WRAPPED_TOKEN=`VAULT_TOKEN=reallystrongpassword VAULT_ADDR="https://${LEADER_IP}:8322" vault kv get -field "value" kv/development/wrappedprovisionertoken`
curl --header 'Content-Type: application/json' \
    --request POST \
    --data "{\"token\":\""${WRAPPED_TOKEN}"\"}" \
    http://127.0.0.1:8314/initialiseme

# echo 'Debug - Aliased check "Factory Service SecretID" failing:'
# sleep 30

register_secret_id_service_with_consul

# check health
echo "APPLICATION HEALTH"
curl -s http://127.0.0.1:8314/health

echo 'End of Factory Service Installation'
exit 0

