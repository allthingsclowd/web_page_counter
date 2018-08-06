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
    [ -f vault_0.10.4_linux_amd64.zip ] || {
        sudo wget https://releases.hashicorp.com/vault/0.10.4/vault_0.10.4_linux_amd64.zip
    }
    sudo unzip vault_0.10.4_linux_amd64.zip
    sudo chmod +x vault
    popd
}


if [[ "${HOSTNAME}" =~ "leader" ]] || [ "${TRAVIS}" == "true" ]; then
  #lets kill past instance
  sudo killall vault &>/dev/null

  #lets delete old consul storage
  sudo consul kv delete -recurse vault

  #delete old token if present
  [ -f /usr/local/bootstrap/.vault-token ] && sudo rm /usr/local/bootstrap/.vault-token

  #start vault
  sudo /usr/local/bin/vault server  -dev -dev-listen-address=${IP}:8200 -config=/usr/local/bootstrap/conf/vault.hcl &> ${LOG} &
  echo vault started
  sleep 3 
  
  #copy token to known location
  sudo find / -name '.vault-token' -exec cp {} /usr/local/bootstrap/.vault-token \; -quit
  sudo chmod ugo+r /usr/local/bootstrap/.vault-token

  # enable secret KV version 1
  sudo VAULT_ADDR="http://${IP}:8200" vault secrets enable -version=1 kv

  # create admin & provisioner policies
  tee provisioner_policy.hcl <<EOF
  # Manage auth methods broadly across Vault
  path "auth/*"
  {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }

  # List, create, update, and delete auth methods
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
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }
EOF
  sudo VAULT_ADDR="http://${IP}:8200" vault policy write provisioner provisioner_policy.hcl

  PROVISIONER_TOKEN=`sudo VAULT_ADDR="http://${IP}:8200" vault token create -policy=provisioner -field=token`
  sudo echo -n ${PROVISIONER_TOKEN} > /usr/local/bootstrap/.provisioner-token
  
  # create admin & provisioner policies
  tee /usr/local/bootstrap/conf/envconsul.hcl <<EOF
  vault {
    address = "http://vault.service.consul:8200"
    token   = "${PROVISIONER_TOKEN}"
    renew   = true
  }
EOF
  sudo chmod ugo+r /usr/local/bootstrap/.provisioner-token

  tee admin_policy.hcl <<EOF
  # Manage auth methods broadly across Vault
  path "auth/*"
  {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }

  # List, create, update, and delete auth methods
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
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }

  # Manage and manage secret engines broadly across Vault.
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
  sudo VAULT_ADDR="http://${IP}:8200" vault policy write admin admin_policy.hcl
  
  ADMIN_TOKEN=`sudo VAULT_ADDR="http://${IP}:8200" vault token create -policy=admin -field=token`

    # Put Redis Password in Vault
  sudo VAULT_ADDR="http://${IP}:8200" vault policy list
  REDIS_MASTER_PASSWORD=`openssl rand -base64 32`
  sudo VAULT_ADDR="http://${IP}:8200" vault login ${ADMIN_TOKEN}
  sudo VAULT_ADDR="http://${IP}:8200" vault policy list
  sudo VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/redispassword value=${REDIS_MASTER_PASSWORD}
  # sudo VAULT_ADDR="http://${IP}:8200" vault login ${PROVISIONER_TOKEN}
  # sudo VAULT_ADDR="http://${IP}:8200" vault policy list
  # sudo VAULT_ADDR="http://${IP}:8200" vault kv get secret/development/REDIS_MASTER_PASSWORD
fi
