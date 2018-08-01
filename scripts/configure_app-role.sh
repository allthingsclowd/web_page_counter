#!/usr/bin/env bash

DEBUG=false

function pause(){
    echo -e "\n"
    if ${DEBUG}; then
        read -p "$*"
    else
        echo "$*"
    fi
    echo -e "\n"
}

set -x

IFACE=`route -n | awk '$1 == "192.168.5.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.5" {print $2}'`
IP=${CIDR%%/24}

if [ "${TRAVIS}" == "true" ]; then
IP=${IP:-127.0.0.1}
fi

if [ -d /vagrant ]; then
  LOG="/vagrant/logs/vault_audit_${HOSTNAME}.log"
else
  LOG="vault_audit.log"
fi

export VAULT_ADDR=http://${IP}:8200
export VAULT_SKIP_VERIFY=true

VAULT_TOKEN=`cat /usr/local/bootstrap/.vault-token`

##--------------------------------------------------------------------
## Configure Audit Backend

VAULT_AUDIT_LOG="${LOG}"
#sudo chown vault:vault ${VAULT_AUDIT_LOG}

PKG="curl jq"
which ${PKG} &>/dev/null || {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ${PKG}
}

tee audit-backend-file.json <<EOF
{
  "type": "file",
  "options": {
    "path": "${VAULT_AUDIT_LOG}"
  }
}
EOF

pause 'Enable Audit Backend - Press [Enter] key to continue...'

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request PUT \
    --data @audit-backend-file.json \
    ${VAULT_ADDR}/v1/sys/audit/file-audit


##--------------------------------------------------------------------
## Create ACL Policy

# Policy to apply to AppRole token
tee goapp-secret-read.json <<EOF
{"policy":"path \"secret/data/goapp\" {capabilities = [\"read\", \"list\"]}"}
EOF

pause 'Create goapp secret policy - Press [Enter] key to continue...'

# Write the policy
curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request PUT \
    --data @goapp-secret-read.json \
    ${VAULT_ADDR}/v1/sys/policy/goapp-secret-read | jq .

##--------------------------------------------------------------------

pause 'List ACL policies - Press [Enter] key to continue...'

# List ACL policies
curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request LIST \
    ${VAULT_ADDR}/v1/sys/policy | jq .

##--------------------------------------------------------------------
## Enable & Configure AppRole Auth Backend

# AppRole auth backend config
tee approle.json <<EOF
{
  "type": "approle",
  "description": "Demo AppRole auth backend"
}
EOF

pause 'Enable approle - Press [Enter] key to continue...'

# Create the approle backend
curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data @approle.json \
    ${VAULT_ADDR}/v1/sys/auth/approle | jq .

# Check if AppRole Exists
APPROLEID=`curl  \
   --header "X-Vault-Token: ${VAULT_TOKEN}" \
   ${VAULT_ADDR}/v1/auth/approle/role/goapp/role-id | jq -r .data.role_id`

# AppRole backend configuration
tee goapp-approle-role.json <<EOF
{
    "role_name": "goapp",
    "bind_secret_id": true,
    "secret_id_ttl": "10m",
    "secret_id_num_uses": "1",
    "token_ttl": "10m",
    "token_max_ttl": "30m",
    "period": 0,
    "policies": [
        "goapp-secret-read"
    ]
}
EOF

if [ "${APPROLEID}" == null ]; then
    pause 'Create approle - Press [Enter] key to continue...'

    # Create the AppRole role
    curl \
        --location \
        --header "X-Vault-Token: ${VAULT_TOKEN}" \
        --request POST \
        --data @goapp-approle-role.json \
        ${VAULT_ADDR}/v1/auth/approle/role/goapp | jq .

    APPROLEID=`curl  \
   --header "X-Vault-Token: ${VAULT_TOKEN}" \
   ${VAULT_ADDR}/v1/auth/approle/role/goapp/role-id | jq -r .data.role_id`

fi

pause 'Show AppRoleID - Press [Enter] key to continue...'

echo -e "\n\nApplication RoleID = ${APPROLEID}\n\n"
echo ${APPROLEID} > /usr/local/bootstrap/.approle-id

# Write minimal secret-id payload
tee secret_id_config.json <<'EOF'
{
  "metadata": "{ \"tag1\": \"goapp production\" }"
}
EOF

WRAPPED_SECRETID=`curl  \
--header "X-Vault-Token: ${VAULT_TOKEN}" \
--header "X-Vault-Wrap-TTL:5m" \
--data @secret_id_config.json \
${VAULT_ADDR}/v1/auth/approle/role/goapp/secret-id | jq -r .wrap_info.token`

pause 'Show SecretID - Press [Enter] key to continue...'

echo -e "\n\nApplication Wrapped SecretID = ${WRAPPED_SECRETID}\n\n"
echo ${WRAPPED_SECRETID} > /usr/local/bootstrap/.wrapped_secret-id

# Write some demo secrets that should be accessible 
tee demo-secrets.json <<'EOF'
{
   "data": {
    "username": "goapp-user",
    "password": "$up3r$3cr3t!"
    }
}
EOF

pause 'Deploy some accessible secrets - Press [Enter] key to continue...'

curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data @demo-secrets.json \
    ${VAULT_ADDR}/v1/secret/data/goapp | jq .

# Write some demo secrets that should NOT be accessible 
tee demo-secrets.json <<'EOF'
{
   "data": {
    "username": "someother-user",
    "password": "Pa$$W0RD"
    }
}
EOF

pause 'Deploy some inaccessible secrets - Press [Enter] key to continue...'

curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data @demo-secrets.json \
    ${VAULT_ADDR}/v1/secret/data/wrongapp | jq .





