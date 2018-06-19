#!/usr/bin/env bash

which /usr/local/bin/vault &>/dev/null || {
    pushd /usr/local/bin
    [ -f vault_0.10.2_linux_amd64.zip ] || {
        wget https://releases.hashicorp.com/vault/0.10.2/vault_0.10.2_linux_amd64.zip
    }
    unzip vault_0.10.2_linux_amd64.zip
    chmod +x vault
    popd
}

#vault

#lets kill past instance
killall vault &>/dev/null

#lets delete old consul storage
consul kv delete -recurse vault

/usr/local/bin/vault server  -dev -dev-listen-address=192.168.2.10:8200 -config=/usr/local/bootstrap/conf/vault.hcl >/vagrant/vault_${HOSTNAME}.log &
sleep 1
VAULT_ADDR='http://192.168.2.10:8200' vault kv put secret/hello value=world
VAULT_ADDR='http://192.168.2.10:8200' vault kv get secret/hello
echo vault started
