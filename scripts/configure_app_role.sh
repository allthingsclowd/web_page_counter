#!/usr/bin/env bash

set -x

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}

if [ "${TRAVIS}" == "true" ]; then
IP=${IP:-127.0.0.1}
fi

export VAULT_ADDR=http://${IP}:8200
export VAULT_SKIP_VERIFY=true

VAULT_TOKEN=`cat /usr/local/bootstrap/.vault-token`

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
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request POST \
    --data @approle.json \
    ${VAULT_ADDR}/v1/sys/auth/approle | jq .

# Create ACL Policy that will define what the AppRole can access

# Policy to apply to AppRole token
tee id-factory-secret-read.json <<EOF
{"policy":"path \"kv/example_password\" {capabilities = [\"read\", \"list\"]}"}
EOF

# Write the policy
curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request PUT \
    --data @id-factory-secret-read.json \
    ${VAULT_ADDR}/v1/sys/policy/id-factory-secret-read | jq .

##--------------------------------------------------------------------

# List ACL policies
curl \
    --location \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request LIST \
    ${VAULT_ADDR}/v1/sys/policy | jq .

##--------------------------------------------------------------------


# Check if AppRole Exists
APPROLEID=`curl  \
   --header "X-Vault-Token: ${VAULT_TOKEN}" \
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

    # Create the AppRole role
    curl \
        --location \
        --header "X-Vault-Token: ${VAULT_TOKEN}" \
        --request POST \
        --data @id-factory-approle-role.json \
        ${VAULT_ADDR}/v1/auth/approle/role/id-factory | jq .

    APPROLEID=`curl  \
   --header "X-Vault-Token: ${VAULT_TOKEN}" \
   ${VAULT_ADDR}/v1/auth/approle/role/id-factory/role-id | jq -r .data.role_id`

fi

echo -e "\n\nApplication RoleID = ${APPROLEID}\n\n"
echo -n ${APPROLEID} > /usr/local/bootstrap/.appRoleID
sudo chmod ugo+r /usr/local/bootstrap/.appRoleID





