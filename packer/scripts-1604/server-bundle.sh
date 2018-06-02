#!/usr/bin/env bash

apt-get install -y wget unzip git redis-server nginx

which /usr/local/bin/consul &>/dev/null || {
    pushd /usr/local/bin
    [ -f consul_1.1.0_linux_amd64.zip ] || {
        wget https://releases.hashicorp.com/consul/1.1.0/consul_1.1.0_linux_amd64.zip
    }
    unzip consul_1.1.0_linux_amd64.zip
    chmod +x consul
    popd
}

which /usr/local/go &>/dev/null || {
    mkdir -p /tmp/go_src
    pushd /tmp/go_src
    [ -f go1.10.2.linux-amd64.tar.gz ] || {
        wget -nv https://dl.google.com/go/go1.10.2.linux-amd64.tar.gz
    }
    tar -C /usr/local -xzf go1.10.2.linux-amd64.tar.gz
    popd
    rm -rf /tmp/go_src
}
