#!/usr/bin/env bash

install_hashicorp_binaries () {
    # check consul binary
    [ -f /usr/local/bin/consul ] &>/dev/null || {
        pushd /usr/local/bin
        [ -f consul_1.4.0_linux_amd64.zip ] || {
            sudo wget -q https://releases.hashicorp.com/consul/1.4.0/consul_1.4.0_linux_amd64.zip
        }
        sudo unzip consul_1.4.0_linux_amd64.zip
        sudo chmod +x consul
        sudo rm consul_1.4.0_linux_amd64.zip
        popd
    }

    # check consul-template binary
    [ -f /usr/local/bin/consul-template ] &>/dev/null || {
        pushd /usr/local/bin
        [ -f consul-template_0.19.5_linux_amd64.zip ] || {
            sudo wget -q https://releases.hashicorp.com/consul-template/0.19.5/consul-template_0.19.5_linux_amd64.zip
        }
        sudo unzip consul-template_0.19.5_linux_amd64.zip
        sudo chmod +x consul-template
        sudo rm consul-template_0.19.5_linux_amd64.zip
        popd
    }

    # check envconsul binary
    [ -f /usr/local/bin/envconsul ] &>/dev/null || {
        pushd /usr/local/bin
        [ -f envconsul_0.7.3_linux_amd64.zip ] || {
            sudo wget -q https://releases.hashicorp.com/envconsul/0.7.3/envconsul_0.7.3_linux_amd64.zip
        }
        sudo unzip envconsul_0.7.3_linux_amd64.zip
        sudo chmod +x envconsul
        sudo rm envconsul_0.7.3_linux_amd64.zip
        popd
    }

    # check vault binary
    [ -f /usr/local/bin/vault ] &>/dev/null || {
        pushd /usr/local/bin
        [ -f vault_1.0.1_linux_amd64.zip ] || {
            sudo wget -q https://releases.hashicorp.com/vault/1.0.1/vault_1.0.1_linux_amd64.zip
        }
        sudo unzip vault_1.0.1_linux_amd64.zip
        sudo chmod +x vault
        sudo rm vault_1.0.1_linux_amd64.zip
        popd
    }

    [ -f /usr/local/bin/nomad ] &>/dev/null || {
        pushd /usr/local/bin
        [ -f nomad_0.8.7-rc1_linux_amd64.zip ] || {
            sudo wget -q https://releases.hashicorp.com/nomad/0.8.7-rc1/nomad_0.8.7-rc1_linux_amd64.zip
        }
        unzip nomad_0.8.7-rc1_linux_amd64.zip
        chmod +x nomad
        sudo rm nomad_0.8.7-rc1_linux_amd64.zip
        popd
    }
}

apt-get clean
apt-get update
apt-get upgrade -y

# Update to the latest kernel
apt-get install -y linux-generic linux-image-generic linux-server

# Hide Ubuntu splash screen during OS Boot, so you can see if the boot hangs
apt-get remove -y plymouth-theme-ubuntu-text
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
update-grub

apt-get install -y wget -q unzip git redis-server nginx lynx jq curl

which /usr/local/go &>/dev/null || {
    mkdir -p /tmp/go_src
    pushd /tmp/go_src
    [ -f go1.11.1.linux-amd64.tar.gz ] || {
        wget -qnv https://dl.google.com/go/go1.11.1.linux-amd64.tar.gz
    }
    tar -C /usr/local -xzf go1.11.1.linux-amd64.tar.gz
    popd
    rm -rf /tmp/go_src
    echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile
}

install_hashicorp_binaries

# Reboot with the new kernel
shutdown -r now
sleep 60
