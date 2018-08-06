#!/usr/bin/env bash

set -x

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
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

VAULT_TOKEN=`cat /usr/local/bootstrap/.provisioner-token`

##--------------------------------------------------------------------
## Configure Audit Backend

VAULT_AUDIT_LOG="${LOG}"

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

curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request PUT \
    --data @audit-backend-file.json \
    ${VAULT_ADDR}/v1/sys/audit/file-audit


##--------------------------------------------------------------------
## Create ACL Policy

# Policy to apply to AppRole token
tee goapp-secret-read.json <<EOF
{"policy":"path \"kv/development/redispassword\" {capabilities = [\"read\", \"list\"]}"}
EOF

# Write the policy
curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request PUT \
    --data @goapp-secret-read.json \
    ${VAULT_ADDR}/v1/sys/policy/goapp-secret-read | jq .

##--------------------------------------------------------------------

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
  "description": "Demo AppRole auth backend for goapp webcounter deployment"
}
EOF

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

if [ "${APPROLEID}" == null ]; then
    # AppRole backend configuration
    tee goapp-approle-role.json <<EOF
    {
        "role_name": "goapp",
        "bind_secret_id": true,
        "secret_id_ttl": "24h",
        "secret_id_num_uses": "0",
        "token_ttl": "10m",
        "token_max_ttl": "30m",
        "period": 0,
        "policies": [
            "goapp-secret-read"
        ]
    }
EOF

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

echo -e "\n\nApplication RoleID = ${APPROLEID}\n\n"
echo -n ${APPROLEID} > /usr/local/bootstrap/.approle-id

# Write minimal secret-id payload
tee secret_id_config.json <<EOF
{
  "metadata": "{ \"tag1\": \"goapp production\" }"
}
EOF

# Generate Secret-ID token generator
# Policy to create secret-ids for app-role
tee goapp-secret-id-create.json <<EOF
{"policy":"path \"auth/approle/role/goapp/secret-id\" {capabilities = [\"read\", \"list\", \"create\", \"update\"]}"}
EOF

# Write the policy
curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request PUT \
    --data @goapp-secret-id-create.json \
    ${VAULT_ADDR}/v1/sys/policy/goapp-secret-id-create | jq .

# Secret-Id token generator
tee goapp-secret-id-token.json <<EOF
{
  "policies": [
    "goapp-secret-id-create"
  ],
  "metadata": {
    "user": "Secret-Id Deployer"
  },
  "ttl": "1h",
  "renewable": true
}
EOF

# Create the Secret-Id Generator Token
SECRET_ID_TOKEN=`curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data @goapp-secret-id-token.json \
    ${VAULT_ADDR}/v1/auth/token/create | jq -r .auth.client_token`

sudo echo -n ${SECRET_ID_TOKEN} > /usr/local/bootstrap/.orchestrator-token

SECRET_ID=`curl \
    --location \
    --header "X-Vault-Token: ${SECRET_ID_TOKEN}" \
    --request POST \
    ${VAULT_ADDR}/v1/auth/approle/role/goapp/secret-id | jq -r .data.secret_id`

# login
tee goapp-secret-id-login.json <<EOF
{
  "role_id": "${APPROLEID}",
  "secret_id": "${SECRET_ID}"
}
EOF

curl \
    --location \
    --header "X-Vault-Token: ${SECRET_ID_TOKEN}" \
    --request POST \
    --data @goapp-secret-id-login.json \
    ${VAULT_ADDR}/v1/auth/approle/role/login 




