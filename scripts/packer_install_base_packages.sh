#!/usr/bin/env bash

# Binary versions to check for
consul_version=1.6.1
vault_version=1.2.3
nomad_version=0.9.5
terraform_version=0.12.8
consul_template_version=0.21.3
env_consul_version=0.9.0
golang_version=1.13
# TODO: Add checksums to ensure integrity of binaries downloaded

install_webpagecounter_binaries () {
    # Added loop below to overcome Travis-CI/Github download issue
    RETRYDOWNLOAD="1"
    pushd /usr/local/bin
    while [ ${RETRYDOWNLOAD} -lt 10 ] && [ ! -f /usr/local/bin/webcounter ]
    do
        echo "Webpagecounter Binaries Download - Take ${RETRYDOWNLOAD}" 
        # download binariesfrom latest release
        sudo bash -c 'curl -s -L https://api.github.com/repos/allthingsclowd/web_page_counter/releases/latest \
        | grep "browser_download_url" \
        | cut -d : -f 2,3 \
        | tr -d \" | wget -q -i - '
        RETRYDOWNLOAD=$[${RETRYDOWNLOAD}+1]
        sleep 5
    done

    [  -f /usr/local/bin/webcounter  ] &>/dev/null || {
        echo 'Failed to download webpagecounter binaries from https://api.github.com/repos/allthingsclowd/web_page_counter/releases/latest'
        exit 1
    }

    sudo chmod +x /usr/local/bin/webcounter
    popd    
}

install_factory_secretid_binaries () {
    # Added loop below to overcome Travis-CI download issue
    RETRYDOWNLOAD="1"
    pushd /usr/local/bin
    while [ ${RETRYDOWNLOAD} -lt 10 ] && [ ! -f /usr/local/bin/VaultServiceIDFactory ]
    do
        echo "Vault SecretID Service Download - Take ${RETRYDOWNLOAD}"
        # download binary and template file from latest release
        sudo bash -c 'curl -s -L https://api.github.com/repos/allthingsclowd/VaultServiceIDFactory/releases/latest \
        | grep "browser_download_url" \
        | cut -d : -f 2,3 \
        | tr -d \" | wget -q -i - '
        RETRYDOWNLOAD=$[${RETRYDOWNLOAD}+1]
        sleep 5
    done

    [  -f /usr/local/bin/VaultServiceIDFactory  ] &>/dev/null || {
        echo 'Failed to download Vault Secret ID Factory Service'
        exit 1
    }

    sudo chmod +x /usr/local/bin/VaultServiceIDFactory
    popd   
}

install_web_front_end_binaries () {
    # Added loop below to overcome Travis-CI download issue
    RETRYDOWNLOAD="1"
    sudo mkdir -p /tmp/wpc-fe
    pushd /tmp/wpc-fe
    while [ ${RETRYDOWNLOAD} -lt 10 ] && [ ! -f /var/www/wpc-fe/index.html ]
    do 
        echo "Web Front End Download - Take ${RETRYDOWNLOAD}"
        # download binary and template file from latest release
        sudo bash -c 'curl -s -L https://api.github.com/repos/allthingsclowd/wep_page_counter_front-end/releases/latest \
        | grep "browser_download_url" \
        | cut -d : -f 2,3 \
        | tr -d \" | wget -q -i - '
        [ -f webcounterpagefrontend.tar.gz ] && sudo tar -xvf webcounterpagefrontend.tar.gz -C /var/www
        RETRYDOWNLOAD=$[${RETRYDOWNLOAD}+1]
        sleep 5
    done

    popd

    [  -f /var/www/wpc-fe/index.html  ] &>/dev/null || {
        echo 'Web Front End Download Failed'
        exit 1
    } 
   
}


install_hashicorp_binaries () {

    # check consul binary
    [ -f /usr/local/bin/consul ] &>/dev/null || {
        pushd /usr/local/bin
        [ -f consul_${consul_version}_linux_amd64.zip ] || {
            sudo wget -q https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
        }
        sudo unzip consul_${consul_version}_linux_amd64.zip
        sudo chmod +x consul
        sudo rm consul_${consul_version}_linux_amd64.zip
        popd
        consul --version
    }

    # check consul-template binary
    [ -f /usr/local/bin/consul-template ] &>/dev/null || {
        pushd /usr/local/bin
        [ -f consul-template_${consul_template_version}_linux_amd64.zip ] || {
            sudo wget -q https://releases.hashicorp.com/consul-template/${consul_template_version}/consul-template_${consul_template_version}_linux_amd64.zip
        }
        sudo unzip consul-template_${consul_template_version}_linux_amd64.zip
        sudo chmod +x consul-template
        sudo rm consul-template_${consul_template_version}_linux_amd64.zip
        popd
        consul-template -version
    }

    # check envconsul binary
    [ -f /usr/local/bin/envconsul ] &>/dev/null || {
        pushd /usr/local/bin
        [ -f envconsul_${env_consul_version}_linux_amd64.zip ] || {
            sudo wget -q https://releases.hashicorp.com/envconsul/${env_consul_version}/envconsul_${env_consul_version}_linux_amd64.zip
        }
        sudo unzip envconsul_${env_consul_version}_linux_amd64.zip
        sudo chmod +x envconsul
        sudo rm envconsul_${env_consul_version}_linux_amd64.zip
        popd
        envconsul -version
    }

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
        vault -version
    }

    # check terraform binary
    [ -f /usr/local/bin/terraform ] &>/dev/null || {
        pushd /usr/local/bin
        [ -f terraform_${terraform_version}_linux_amd64.zip ] || {
            sudo wget -q https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip
        }
        sudo unzip terraform_${terraform_version}_linux_amd64.zip
        sudo chmod +x terraform
        sudo rm terraform_${terraform_version}_linux_amd64.zip
        popd
        terraform -version
    }

    # check for nomad binary
    [ -f /usr/local/bin/nomad ] &>/dev/null || {
        pushd /usr/local/bin
        [ -f nomad_${nomad_version}_linux_amd64.zip ] || {
            sudo wget -q https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip
        }
        sudo unzip nomad_${nomad_version}_linux_amd64.zip
        sudo chmod +x nomad
        sudo rm nomad_${nomad_version}_linux_amd64.zip
        popd
        nomad -version
    }
}

install_chef_inspec () {
    
    [ -f /usr/bin/inspec ] &>/dev/null || {
        pushd /tmp
        curl https://omnitruck.chef.io/install.sh | sudo bash -s -- -P inspec   
        popd
        inspec version
    }    

}

sudo apt-get clean
sudo apt-get update
sudo apt-get upgrade -y

# Update to the latest kernel
sudo apt-get install -y linux-generic linux-image-generic linux-server

# Hide Ubuntu splash screen during OS Boot, so you can see if the boot hangs
sudo apt-get remove -y plymouth-theme-ubuntu-text
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
sudo update-grub

sudo apt-get install -y wget -q unzip git redis-server nginx lynx jq curl net-tools

# disable services that are not used by all hosts
sudo systemctl stop redis-server
sudo systemctl disable redis-server
sudo systemctl stop nginx
sudo systemctl disable nginx

echo "Start Golang installation"
which /usr/local/go &>/dev/null || {
    echo "Create a temporary directory"
    sudo mkdir -p /tmp/go_src
    pushd /tmp/go_src
    [ -f go${golang_version}.linux-amd64.tar.gz ] || {
        echo "Download Golang source"
        sudo wget -qnv https://dl.google.com/go/go${golang_version}.linux-amd64.tar.gz
    }
    
    echo "Extract Golang source"
    sudo tar -C /usr/local -xzf go${golang_version}.linux-amd64.tar.gz
    popd
    echo "Remove temporary directory"
    sudo rm -rf /tmp/go_src
    echo "Edit profile to include path for Go"
    echo "export PATH=$PATH:/usr/local/go/bin" | sudo tee -a /etc/profile
    echo "Ensure others can execute the binaries"
    sudo chmod -R +x /usr/local/go/bin/

    source /etc/profile

    go version

}

install_hashicorp_binaries
install_webpagecounter_binaries
install_factory_secretid_binaries
install_web_front_end_binaries
install_chef_inspec

# Reboot with the new kernel
shutdown -r now
sleep 60

exit 0

