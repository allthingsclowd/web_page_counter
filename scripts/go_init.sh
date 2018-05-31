#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "/var/vagrant_go_base" ]; then
    exit 0
fi

touch /var/vagrant_go_base
sudo apt-get update && \
    sudo apt-get upgrade -y && \
    sudo apt-get install -y git=1:2.7.4-0ubuntu1.3
mkdir -p /tmp/go_src
pushd /tmp/go_src
wget -nv https://dl.google.com/go/go1.10.2.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.10.2.linux-amd64.tar.gz
echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile
popd



