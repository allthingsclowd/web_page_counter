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

/usr/local/bin/vault server -config=/usr/local/bootstrap/conf/vault.hcl >/vagrant/vault_${HOSTNAME}.log &
    
echo vault started