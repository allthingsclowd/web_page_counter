#!/usr/bin/env bash

golang_version=1.13

echo "Start Golang installation"
which /usr/local/go/bin/go &>/dev/null || {
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
    cat /etc/profile
    source /etc/profile

    go version

}