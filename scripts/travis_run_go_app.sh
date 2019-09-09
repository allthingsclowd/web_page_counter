#!/usr/bin/env bash
set -x

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
    cat /etc/profile
    source /etc/profile

    go version

}

# delayed added to ensure consul has started on host - intermittent failures
sleep 2

AGENTTOKEN=`sudo VAULT_TOKEN=reallystrongpassword VAULT_ADDR="http://${LEADER_IP}:8200" vault kv get -field "value" kv/development/consulagentacl`
export CONSUL_HTTP_TOKEN=${AGENTTOKEN}

go get ./...
go build -o webcounter main.go
./webcounter -consulACL=${CONSUL_HTTP_TOKEN} -ip="0.0.0.0" -consulIp="127.0.0.1:8321" &

# delay added to allow webcounter startup
sleep 2

ps -ef | grep webcounter 

page_hit_counter=`lynx --dump http://localhost:8080`
echo $page_hit_counter
next_page_hit_counter=`lynx --dump http://localhost:8080`
echo $next_page_hit_counter
if (( next_page_hit_counter > page_hit_counter )); then
 echo "Successful Page Hit Update"
 exit 0
else
 echo "Failed Page Hit Update"
 exit 1
fi
# The End
