#!/usr/bin/env bash

setup_environment () {
  set -x

  source /usr/local/bootstrap/var.env

  IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8;exit}'`
  CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.9" {print $2}'`
  IP=${CIDR%%/24}

  # Configure Nomad client.hcl file
  sed -i 's/network_interface = ".*"/network_interface = "'${IFACE}'"/g' /usr/local/bootstrap/conf/nomad.d/client.hcl

  if [ -d /vagrant ]; then
    LOG="/vagrant/logs/nomad_${HOSTNAME}.log"
  else
    LOG="nomad.log"
  fi

  if [ "${TRAVIS}" == "true" ]; then
    IP=${IP:-127.0.0.1}
    LEADER_IP=${IP}
  fi

  echo 'Set environmental bootstrapping data in VAULT'
  export VAULT_TOKEN=reallystrongpassword
  export VAULT_ADDR=https://${LEADER_IP}:8322
  export VAULT_CLIENT_KEY=/etc/vault.d/pki/tls/private/vault-client-key.pem
  export VAULT_CLIENT_CERT=/etc/vault.d/pki/tls/certs/vault-client.pem
  export VAULT_CACERT=/etc/ssl/certs/vault-agent-ca.pem

  # Configure consul environment variables for use with certificates 
  export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
  export CONSUL_CACERT=/etc/ssl/certs/consul-agent-ca.pem
  export CONSUL_CLIENT_CERT=/etc/consul.d/pki/tls/certs/consul-client.pem
  export CONSUL_CLIENT_KEY=/etc/consul.d/pki/tls/private/consul-client-key.pem
  vault status
  AGENTTOKEN=`vault kv get -field "value" kv/development/consulagentacl`
  export CONSUL_HTTP_TOKEN=${AGENTTOKEN}



  which wget unzip &>/dev/null || {
    apt-get update
    apt-get install -y wget unzip 
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
  }

  grep NOMAD_ADDR ~/.bash_profile &>/dev/null || {
    echo export NOMAD_ADDR=http://${IP}:4646 | tee -a ~/.bash_profile
  }
}

create_certificate () {
  # ${1} domain e.g. consul
  # ${2} data centre e..g. DC1
  # ${3} certificate duration in days
  # ${4} additional ip addresses
  # ${5} cert type either server, client or cli
  
  [ -f /etc/${1}.d/pki/tls/private/${1}-${5}-key.pem ] &>/dev/null || {
    echo "Start generating ${5} certificates for data centre ${2} with domain ${1}" 
    pushd /etc/${1}.d/pki/tls/private
    sudo /usr/local/bin/consul tls cert create \
                                -domain=${1} \
                                -dc=${2} \
                                -key=/etc/ssl/private/${1}-agent-ca-key.pem \
                                -ca=/etc/ssl/certs/${1}-agent-ca.pem$ \
                                -days=${3} \
                                -additional-ipaddress=${4} \
                                -${5} 
                                
    sudo mv ${2}-${5}-${1}-0.pem /etc/${1}.d/pki/tls/certs/${1}-${5}.pem
    sudo mv ${2}-${5}-${1}-0-key.pem /etc/${1}.d/pki/tls/private/${1}-${5}-key.pem

    sudo -u ${1} chmod 644 /etc/${1}.d/pki/tls/certs/${1}-${5}.pem
    sudo -u ${1} chmod 600 /etc/${1}.d/pki/tls/private/${1}-${5}-key.pem  

    # debug
    sudo ls -al /etc/${1}.d/pki/tls/private/
    sudo ls -al /etc/${1}.d/pki/tls/certs/
    popd
    echo "Finished generating ${5} certificates for data centre ${2} with domain ${1}" 
  }
}

install_nomad() {

  # create certificates - using consul helper :shrug:?
  configure_certificate nomad hashistack1 30 ${IP} server
  configure_certificate consul hashistack1 30 ${IP} client

  # check for nomad hostname => server
  if [[ "${HOSTNAME}" =~ "leader" ]] || [ "${TRAVIS}" == "true" ]; then
    if [ "${TRAVIS}" == "true" ]; then

      # create nomad directories
      sudo -u nomad mkdir --parents /etc/nomad.d/pki/tls/private/nomad /etc/nomad.d/pki/tls/certs/nomad
      sudo -u nomad mkdir --parents /etc/nomad.d/pki/tls/private/consul /etc/nomad.d/pki/tls/certs/consul
      sudo -u nomad mkdir --parents /etc/nomad.d/pki/tls/private/vault /etc/nomad.d/pki/tls/certs/vault
      sudo -u nomad chmod -R 644 /etc/nomad.d/pki/tls/certs/nomad /etc/nomad.d/pki/tls/certs/consul /etc/nomad.d/pki/tls/certs/vault
      sudo -u nomad chmod -R 600 /etc/nomad.d/pki/tls/private/vault /etc/nomad.d/pki/tls/private/consul /etc/nomad.d/pki/tls/private/nomad
      
      # create certificates - using consul helper :shrug:?
      create_certificate nomad hashistack1 30 ${IP} server
      create_certificate consul hashistack1 30 ${IP} client

      sudo cp -apr /usr/local/bootstrap/conf/nomad.d /etc
      sudo /usr/local/bin/nomad agent -server -bind=${IP} -data-dir=/usr/local/nomad -bootstrap-expect=1 -config=/etc/nomad.d >${LOG} &
    else
      NOMAD_ADDR=http://${IP}:4646 /usr/local/bin/nomad agent-info 2>/dev/null || {
        
        # create certificates - using consul helper :shrug:?
        create_certificate nomad hashistack1 30 ${IP} server
        create_certificate consul hashistack1 30 ${IP} client

        sudo sed -i "/ExecStart=/c\ExecStart=/usr/local/bin/nomad agent -log-level=DEBUG -server -bind=${IP} -data-dir=/usr/local/nomad -bootstrap-expect=1 -config=/etc/nomad.d" /etc/systemd/system/nomad.service
        cp -apr /usr/local/bootstrap/conf/nomad.d /etc
        sudo systemctl enable nomad
        sudo systemctl start nomad
        
      }
    fi
    sleep 15

  else

    create_certificate nomad hashistack1 30 ${IP} client
    create_certificate consul hashistack1 30 ${IP} client
    create_certificate vault hashistack1 30 ${IP} client
    
    NOMAD_ADDR=http://${IP}:4646 /usr/local/bin/nomad agent-info 2>/dev/null || {
      sudo sed -i "/ExecStart=/c\ExecStart=/usr/local/bin/nomad agent -log-level=DEBUG -client -bind=${IP} -data-dir=/usr/local/nomad -join=${LEADER_IP} -config=/etc/nomad.d" /etc/systemd/system/nomad.service
      cp -apr /usr/local/bootstrap/conf/nomad.d /etc
      sudo systemctl enable nomad
      sudo systemctl start nomad
      sleep 15
    }

  fi
}
setup_environment
install_nomad

exit 0
