#!/usr/bin/env bash

create_service () {

  if [ ! -f /etc/systemd/system/${1}.service ]; then
    
    create_service_user ${1}
    
    sudo tee /etc/systemd/system/${1}.service <<EOF
### BEGIN INIT INFO
# Provides:          ${1}
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${1} agent
# Description:       ${2}
### END INIT INFO

[Unit]
Description=${2}
Requires=network-online.target
After=network-online.target

[Service]
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

setup_environment () {
    
    set -x
    echo 'Start Setup of Vault Environment'
    source /usr/local/bootstrap/var.env

    IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8}'`
    CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.9" {print $2}'`
    IP=${CIDR%%/24}

    if [ -d /vagrant ]; then
        LOG="/vagrant/logs/vault_${HOSTNAME}.log"
    else
        LOG="vault.log"
    fi


    if [ "${TRAVIS}" == "true" ]; then
    IP=${IP:-127.0.0.1}
    fi

    # check vault binary
    [ -f /usr/local/bin/vault ] &>/dev/null || {
        pushd /usr/local/bin
        [ -f vault_${vault_version}_linux_amd64.zip ] || {
            sudo wget -q https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip
        }
        sudo unzip vault_${vault_version}_linux_amd64.zip
        sudo chmod +x vault
        sudo rm vault_${vault_version}_linux_amd64.zip
        popd
    }

    # Configure consul environment variables for use with certificates 
    export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
    export CONSUL_CACERT=/usr/local/bootstrap/certificate-config/consul-ca.pem
    export CONSUL_CLIENT_CERT=/usr/local/bootstrap/certificate-config/cli.pem
    export CONSUL_CLIENT_KEY=/usr/local/bootstrap/certificate-config/cli-key.pem
    BOOTSTRAPACL=`cat /usr/local/bootstrap/.bootstrap_acl`
    export CONSUL_HTTP_TOKEN=${BOOTSTRAPACL}

    export VAULT_TOKEN=reallystrongpassword
    export VAULT_ADDR=https://127.0.0.1:8322
    export VAULT_CLIENT_KEY=/usr/local/bootstrap/certificate-config/hashistack-client-key.pem
    export VAULT_CLIENT_CERT=/usr/local/bootstrap/certificate-config/hashistack-client.pem
    export VAULT_CACERT=/usr/local/bootstrap/certificate-config/hashistack-ca.pem

    echo 'End Setup of Vault Environment'
}

configure_vault_KV_audit_logs () {
    
    echo 'Start Vault KV Version Selection and Audit Log Enablement'
    export VAULT_TOKEN=`cat /usr/local/bootstrap/.vault-token`
    # export VAULT_ADDR="http://${IP}:8200"
    # enable secret KV version 1
    vault secrets enable -version=1 kv

#     # configure Audit Backend
#     tee audit-backend-file.json <<EOF
#     {
#         "type": "file",
#         "options": {
#             "path": "${AUDIT_LOG}"
#         }
#     }
# EOF

#     sudo curl \
#         --header "X-Vault-Token: ${VAULT_TOKEN}" \
#         --request PUT \
#         --data @audit-backend-file.json \
#         ${VAULT_ADDR}/v1/sys/audit/file-audit    
    echo 'Vault KV Version Selection Complete'
}

configure_vault_database_role () {

    echo 'Start Vault Database Role & Policy Creation'
    # use root policy to create admin & provisioner policies
    # see https://www.hashicorp.com/resources/policies-vault

    # admin policy hcl definition file
    tee database_policy.hcl <<EOF
    # List read key/value secrets
    path "kv/development/*"
    {
    capabilities = ["read", "list"]
    }
EOF

    # create the admin policy in vault
    VAULT_TOKEN=${VAULT_TOKEN} vault policy write database_admin database_policy.hcl

    # create an admin token
    DATABASE_TOKEN=`vault token create -policy=database_admin -field=token`
    sudo echo -n ${DATABASE_TOKEN} > /usr/local/bootstrap/.database-token

    sudo chmod ugo+r /usr/local/bootstrap/.database-token
    echo 'Vault DBA Role & Policy Creation Complete'   
}


configure_vault_admin_role () {

    echo 'Start Vault Admin Role & Policy Creation'
    # use root policy to create admin & provisioner policies
    # see https://www.hashicorp.com/resources/policies-vault

    # admin policy hcl definition file
    tee admin_policy.hcl <<EOF
    # Manage auth backends broadly across Vault
    path "auth/*"
    {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # List, create, update, and delete auth backends
    path "sys/auth/*"
    {
    capabilities = ["create", "read", "update", "delete", "sudo"]
    }

    # List existing policies
    path "sys/policy"
    {
    capabilities = ["read"]
    }

    # Create and manage ACL policies broadly across Vault
    path "sys/policy/*"
    {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # List, create, update, and delete key/value secrets
    path "secret/*"
    {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # List, create, update, and delete key/value secrets
    path "kv/*"
    {
    capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Manage and manage secret backends broadly across Vault.
    path "sys/mounts/*"
    {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # Read health checks
    path "sys/health"
    {
    capabilities = ["read", "sudo"]
    }
EOF

    # create the admin policy in vault
    vault policy write admin admin_policy.hcl

    # create an admin token
    ADMIN_TOKEN=`vault token create -policy=admin -field=token`
    sudo echo -n ${ADMIN_TOKEN} > /usr/local/bootstrap/.admin-token

    sudo chmod ugo+r /usr/local/bootstrap/.admin-token
    echo 'Vault Admin Role & Policy Creation Complete'   
}

configure_vault_provisioner_role_wrapped () {

    echo 'Start Vault Provisioner Role & Policy Creation'
    # provisioner policy hcl definition file
    tee provisioner_policy.hcl <<EOF
    # Manage auth backends broadly across Vault
    path "auth/*"
    {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # List, create, update, and delete auth backends
    path "sys/auth/*"
    {
    capabilities = ["create", "read", "update", "delete", "sudo"]
    }

    # List existing policies
    path "sys/policy"
    {
    capabilities = ["read"]
    }

    # Create and manage ACL policies
    path "sys/policy/*"
    {
    capabilities = ["create", "read", "update", "delete", "list"]
    }

    # List, create, update, and delete key/value secrets
    path "secret/*"
    {
    capabilities = ["create", "read", "update", "delete", "list"]
    }

    # List, create, update, and delete key/value secrets
    path "kv/*"
    {
    capabilities = ["create", "read", "update", "delete", "list"]
    }
EOF

    # create provisioner policy
    vault policy write provisioner provisioner_policy.hcl

    # create a wrapped provisioner token by adding -wrap-ttl=60m
    WRAPPED_PROVISIONER_TOKEN=`vault token create -policy=provisioner -wrap-ttl=60m -field=wrapping_token`
    sudo echo -n ${WRAPPED_PROVISIONER_TOKEN} > /usr/local/bootstrap/.wrapped-provisioner-token

    sudo chmod ugo+r /usr/local/bootstrap/.wrapped-provisioner-token
    echo 'Vault Provisioner Role & Policy Creation Complete'
    echo '*** NOTE: The PROVISIONER token has been WRAPPED and Must be UNWRAPPED before USE ***'
}

configure_vault_app_role () {

    echo 'Start Vault App-Role Configuration'
    
    #Enable & Configure AppRole Auth Backend

    # AppRole auth backend config
    tee approle.json <<EOF
    {
    "type": "approle",
    "description": "Demo AppRole auth backend for id-factory deployment"
    }
EOF

    # Create the approle backend
    curl \
        --location \
        --cacert "/usr/local/bootstrap/certificate-config/hashistack-ca.pem" \
        --key "/usr/local/bootstrap/certificate-config/hashistack-client-key.pem" \
        --cert "/usr/local/bootstrap/certificate-config/hashistack-client.pem" \
        --header "X-Vault-Token: ${VAULT_TOKEN}" \
        --request POST \
        --data @approle.json \
        ${VAULT_ADDR}/v1/sys/auth/approle | jq .

    # Create ACL Policy that will define what the AppRole can access

    # Policy to apply to AppRole token
    tee id-factory-secret-read.json <<EOF
    {"policy":"path \"kv/development/redispassword\" {capabilities = [\"read\", \"list\"]}"}
EOF

    # Write the policy
    curl \
        --location \
        --cacert "/usr/local/bootstrap/certificate-config/hashistack-ca.pem" \
        --key "/usr/local/bootstrap/certificate-config/hashistack-client-key.pem" \
        --cert "/usr/local/bootstrap/certificate-config/hashistack-client.pem" \
        --header "X-Vault-Token: ${VAULT_TOKEN}" \
        --request PUT \
        --data @id-factory-secret-read.json \
        ${VAULT_ADDR}/v1/sys/policy/id-factory-secret-read | jq .

    # List ACL policies
    sudo curl \
        --location \
        --cacert "/usr/local/bootstrap/certificate-config/hashistack-ca.pem" \
        --key "/usr/local/bootstrap/certificate-config/hashistack-client-key.pem" \
        --cert "/usr/local/bootstrap/certificate-config/hashistack-client.pem" \
        --header "X-Vault-Token: ${VAULT_TOKEN}" \
        --request LIST \
        ${VAULT_ADDR}/v1/sys/policy | jq .

    # Check if AppRole Exists
    APPROLEID=`curl  \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --cacert "/usr/local/bootstrap/certificate-config/hashistack-ca.pem" \
    --key "/usr/local/bootstrap/certificate-config/hashistack-client-key.pem" \
    --cert "/usr/local/bootstrap/certificate-config/hashistack-client.pem" \
    ${VAULT_ADDR}/v1/auth/approle/role/id-factory/role-id | jq -r .data.role_id`

    if [ "${APPROLEID}" == null ]; then
        # AppRole backend configuration
        tee id-factory-approle-role.json <<EOF
        {
            "role_name": "id-factory",
            "bind_secret_id": true,
            "secret_id_ttl": "24h",
            "secret_id_num_uses": "0",
            "token_ttl": "10m",
            "token_max_ttl": "30m",
            "period": 0,
            "policies": [
                "id-factory-secret-read"
            ]
        }
EOF

        # Static AppRole ID backend configuration
        tee id-factory-static-role-id.json <<EOF
        {
            "role_id": "314159265359"
        }
EOF

        # Create the AppRole role
        curl \
            --location \
            --cacert "/usr/local/bootstrap/certificate-config/hashistack-ca.pem" \
            --key "/usr/local/bootstrap/certificate-config/hashistack-client-key.pem" \
            --cert "/usr/local/bootstrap/certificate-config/hashistack-client.pem" \
            --header "X-Vault-Token: ${VAULT_TOKEN}" \
            --request POST \
            --data @id-factory-approle-role.json \
            ${VAULT_ADDR}/v1/auth/approle/role/id-factory | jq .
        
        # Update the static AppRole role-id
        curl \
            --location \
            --cacert "/usr/local/bootstrap/certificate-config/hashistack-ca.pem" \
            --key "/usr/local/bootstrap/certificate-config/hashistack-client-key.pem" \
            --cert "/usr/local/bootstrap/certificate-config/hashistack-client.pem" \
            --header "X-Vault-Token: ${VAULT_TOKEN}" \
            --request POST \
            --data @id-factory-static-role-id.json \
            ${VAULT_ADDR}/v1/auth/approle/role/id-factory/role-id

        APPROLEID=`curl  \
            --header "X-Vault-Token: ${VAULT_TOKEN}" \
            --cacert "/usr/local/bootstrap/certificate-config/hashistack-ca.pem" \
            --key "/usr/local/bootstrap/certificate-config/hashistack-client-key.pem" \
            --cert "/usr/local/bootstrap/certificate-config/hashistack-client.pem" \
            ${VAULT_ADDR}/v1/auth/approle/role/id-factory/role-id | jq -r .data.role_id`

    fi

    echo -e "\n\nApplication RoleID = ${APPROLEID}\n\n"
    echo -n ${APPROLEID} > /usr/local/bootstrap/.appRoleID
    sudo chmod ugo+r /usr/local/bootstrap/.appRoleID
    echo 'Vault App-Role Configuration Complete'
}

revoke_root_token () {
    
    echo 'Start Vault Root Token Revocation'
    # revoke ROOT token now that admin token has been created
    vault token revoke ${VAULT_TOKEN}

    # Verify root token revoked
    VAULT_TOKEN=${VAULT_TOKEN} vault status

    # Set new admin vault token & verify
    export VAULT_TOKEN=${ADMIN_TOKEN}
    VAULT_TOKEN=${ADMIN_TOKEN} vault login ${ADMIN_TOKEN}
    VAULT_TOKEN=${ADMIN_TOKEN} vault status
    echo 'Vault Root Token Revocation Complete'    
}

get_approle_id () {
    
    echo 'Start Get APP-ROLE ID'
    # retrieve the appRole-id from the approle
    APPROLEID=`curl  \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --cacert "/usr/local/bootstrap/certificate-config/hashistack-ca.pem" \
    --key "/usr/local/bootstrap/certificate-config/hashistack-client-key.pem" \
    --cert "/usr/local/bootstrap/certificate-config/hashistack-client.pem" \
    ${VAULT_ADDR}/v1/auth/approle/role/id-factory/role-id | jq -r .data.role_id`
    echo 'Get APP-ROLE ID Complete'

}

bootstrap_secret_data () {
    
    echo 'Set environmental bootstrapping data in VAULT'
    export VAULT_TOKEN=reallystrongpassword
    export VAULT_ADDR=https://127.0.0.1:8322
    export VAULT_CLIENT_KEY=/usr/local/bootstrap/certificate-config/hashistack-client-key.pem
    export VAULT_CLIENT_CERT=/usr/local/bootstrap/certificate-config/hashistack-client.pem
    export VAULT_CACERT=/usr/local/bootstrap/certificate-config/hashistack-ca.pem
    REDIS_MASTER_PASSWORD=`openssl rand -base64 32`
    APPROLEID=`cat /usr/local/bootstrap/.appRoleID`
    DB_VAULT_TOKEN=`cat /usr/local/bootstrap/.database-token`
    AGENTTOKEN=`cat /usr/local/bootstrap/.agenttoken_acl`
    WRAPPEDPROVISIONERTOKEN=`cat /usr/local/bootstrap/.wrapped-provisioner-token`
    BOOTSTRAPACL=`cat /usr/local/bootstrap/.bootstrap_acl`
    # Put Redis Password in Vault
    vault login ${ADMIN_TOKEN}
    # FAILS???? sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault policy list
    vault kv put kv/development/redispassword value=${REDIS_MASTER_PASSWORD}
    vault kv put kv/development/consulagentacl value=${AGENTTOKEN}
    vault kv put kv/development/vaultdbtoken value=${DB_VAULT_TOKEN}
    vault kv put kv/development/approleid value=${APPROLEID}
    vault kv put kv/development/wrappedprovisionertoken value=${WRAPPEDPROVISIONERTOKEN}
    vault kv put kv/development/bootstraptoken value=${BOOTSTRAPACL}

}

get_secret_id () {

    echo 'Start Generate Secret-ID'
    # Generate a new secret-id
    SECRET_ID=`curl \
        --location \
        --cacert "/usr/local/bootstrap/certificate-config/hashistack-ca.pem" \
        --key "/usr/local/bootstrap/certificate-config/hashistack-client-key.pem" \
        --cert "/usr/local/bootstrap/certificate-config/hashistack-client.pem" \
        --header "X-Vault-Token: ${VAULT_TOKEN}" \
        --request POST \
        ${VAULT_ADDR}/v1/auth/approle/role/id-factory/secret-id | jq -r .data.secret_id`
    echo 'Generate Secret-ID Complete'
}

verify_approle_credentials () {
    
    echo 'Start Verification of App-Role Login'
    # login
    tee id-factory-secret-id-login.json <<EOF
    {
    "role_id": "${APPROLEID}",
    "secret_id": "${SECRET_ID}"
    }
EOF

    APPTOKEN=`curl \
        --request POST \
        --cacert "/usr/local/bootstrap/certificate-config/hashistack-ca.pem" \
        --key "/usr/local/bootstrap/certificate-config/hashistack-client-key.pem" \
        --cert "/usr/local/bootstrap/certificate-config/hashistack-client.pem" \
        --data @id-factory-secret-id-login.json \
        ${VAULT_ADDR}/v1/auth/approle/login | jq -r .auth.client_token`


    echo "Reading secret using newly acquired token"
    vault login ${APPTOKEN}
    vault kv get -field "value" kv/development/redispassword

    echo "Reading secret using newly acquired token"

    RESULT=`curl \
        --header "X-Vault-Token: ${APPTOKEN}" \
        --cacert "/usr/local/bootstrap/certificate-config/hashistack-ca.pem" \
        --key "/usr/local/bootstrap/certificate-config/hashistack-client-key.pem" \
        --cert "/usr/local/bootstrap/certificate-config/hashistack-client.pem" \
        ${VAULT_ADDR}/v1/kv/development/redispassword | jq -r .data.value`

    if [ "${RESULT}" != "${REDIS_MASTER_PASSWORD}" ];then
        echo "APPLICATION VERIFICATION FAILURE"
        exit 1
    fi

    echo "APPLICATION VERIFICATION SUCCESSFUL"
    echo 'Verification of App-Role Login Complete'

}

install_vault () {
    
    
    # verify it's either the TRAVIS server or the Vault server
    if [[ "${HOSTNAME}" =~ "leader" ]] || [ "${TRAVIS}" == "true" ]; then
        echo 'Start Installation of Vault on Server'
        setup_environment
        
        #lets kill past instance
        sudo killall vault &>/dev/null

        #lets delete old consul storage
        consul kv delete -recurse vault

        #delete old token if present
        [ -f /usr/local/bootstrap/.vault-token ] && sudo rm /usr/local/bootstrap/.vault-token

        # copy the example certificates into the correct location - PLEASE CHANGE THESE FOR A PRODUCTION DEPLOYMENT
        sudo mkdir -p /etc/vault.d
        sudo cp -r /usr/local/bootstrap/certificate-config/hashistack-server-key.pem /etc/pki/tls/private/hashistack-server-key.pem
        sudo cp -r /usr/local/bootstrap/certificate-config/hashistack-server.pem /etc/pki/tls/certs/hashistack-server.pem
        # sudo groupadd vaultcerts
        sudo chgrp -R webpagecountercerts /etc/vault.d
        sudo chmod -R 770 /etc/vault.d
        create_service_user vault
        sudo usermod -a -G webpagecountercerts vault
        sudo -u vault cp -r /usr/local/bootstrap/conf/vault.d/* /etc/vault.d/.

        #start vault
        if [ "${TRAVIS}" == "true" ]; then
            sudo /usr/local/bin/vault server -dev -dev-root-token-id="reallystrongpassword" -config=/etc/vault.d/vault.hcl &> ${LOG} &
            sleep 15
            cat ${LOG}
        else
            # create_service vault "HashiCorp's Sercret Management Service" "/usr/local/bin/vault server -dev -dev-root-token-id=\"reallystrongpassword\" -config=/etc/vault.d/vault.hcl"
            sudo sed -i "/ExecStart/c\ExecStart=/usr/local/bin/vault server -dev -dev-root-token-id=\"reallystrongpassword\" -config=/etc/vault.d/vault.hcl" /etc/systemd/system/vault.service
            sudo systemctl enable vault
            sudo systemctl start vault
            #sudo systemctl status vault
        fi
        echo vault started
        sleep 15 
        
        #copy token to known location
        echo "reallystrongpassword" > /usr/local/bootstrap/.vault-token
        sudo chmod ugo+r /usr/local/bootstrap/.vault-token
        configure_vault_KV_audit_logs
        configure_vault_admin_role
        configure_vault_database_role
        configure_vault_provisioner_role_wrapped
        configure_vault_app_role
        #revoke_root_token
        bootstrap_secret_data
        get_secret_id
        get_approle_id
        verify_approle_credentials
        echo 'Installation of Vault Finished'

    fi

    
}

install_vault

exit 0
    



