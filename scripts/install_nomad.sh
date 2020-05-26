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
    ROOTCERTPATH=tmp
    IP=${IP:-127.0.0.1}
    LEADER_IP=${IP}
  else
    ROOTCERTPATH=etc
  fi

  export ROOTCERTPATH

  echo 'Set environmental bootstrapping data in VAULT'
  export VAULT_TOKEN=reallystrongpassword
  export VAULT_ADDR=https://${LEADER_IP}:8322
  export VAULT_CLIENT_KEY=/${ROOTCERTPATH}/vault.d/pki/tls/private/vault-cli-key.pem
  export VAULT_CLIENT_CERT=/${ROOTCERTPATH}/vault.d/pki/tls/certs/vault-cli.pem
  export VAULT_CACERT=/${ROOTCERTPATH}/ssl/certs/vault-ca-chain.pem

  # Configure consul environment variables for use with certificates 
  export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
  export CONSUL_CACERT=/${ROOTCERTPATH}/ssl/certs/consul-ca-chain.pem
  export CONSUL_CLIENT_CERT=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-cli.pem
  export CONSUL_CLIENT_KEY=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-cli-key.pem
  vault status
  AGENTTOKEN=`vault kv get -field "value" kv/development/consulagentacl`
  export CONSUL_HTTP_TOKEN=${AGENTTOKEN}

  export NOMAD_CACERT=/${ROOTCERTPATH}/ssl/certs/nomad-ca-chain.pem
  export NOMAD_CLIENT_CERT=/${ROOTCERTPATH}/nomad.d/pki/tls/certs/nomad-cli.pem
  export NOMAD_CLIENT_KEY=/${ROOTCERTPATH}/nomad.d/pki/tls/private/nomad-cli-key.pem
  export NOMAD_ADDR=https://${LEADER_IP}:4646


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
    echo export NOMAD_ADDR=https://${IP}:4646 | tee -a ~/.bash_profile
  }
}

install_nomad() {

  echo "Installing Nomad"
  
  # create certificates 
  export BootStrapCertTool="https://raw.githubusercontent.com/allthingsclowd/BootstrapCertificateTool/folderperms/scripts/Generate_PKI_Certificates_For_Lab.sh"
  wget -O - ${BootStrapCertTool} | sudo bash -s nomad "server.global.nomad" "client.global.nomad" "${IP}"

  # check for nomad hostname => server
  if [[ "${HOSTNAME}" =~ "leader" ]] || [ "${TRAVIS}" == "true" ]; then
    echo "Nomad Server Installation"
    
    if [ "${TRAVIS}" == "true" ]; then
      
      sudo cp /usr/local/bootstrap/conf/nomad.d/nomad.hcl /${ROOTCERTPATH}/nomad.d/nomad.hcl
      # Travis-CI grant access to /tmp for all users
      sudo chmod -R 777 /${ROOTCERTPATH}
      
      sudo /usr/local/bin/nomad agent -server -bind=${IP} -data-dir=/usr/local/nomad -bootstrap-expect=1 -config=/${ROOTCERTPATH}/nomad.d >${LOG} &
    else
      NOMAD_ADDR=https://${IP}:4646 /usr/local/bin/nomad agent-info 2>/dev/null || {
        
        cp /usr/local/bootstrap/conf/nomad.d/nomad.hcl /${ROOTCERTPATH}/nomad.d/nomad.hcl       
        sudo sed -i "/ExecStart=/c\ExecStart=/usr/local/bin/nomad agent -log-level=DEBUG -server -bind=${IP} -data-dir=/usr/local/nomad -bootstrap-expect=1 -config=/${ROOTCERTPATH}/nomad.d" /etc/systemd/system/nomad.service
        sudo systemctl enable nomad
        sudo systemctl start nomad
        
      }
    fi
    sleep 15

  else

    echo "Nomad Client Installation"

    sudo sed -i "/ExecStart=/c\ExecStart=/usr/local/bin/nomad agent -log-level=DEBUG -client -bind=${IP} -data-dir=/usr/local/nomad -join=${LEADER_IP} -config=/${ROOTCERTPATH}/nomad.d" /etc/systemd/system/nomad.service
    cp /usr/local/bootstrap/conf/nomad.d/client.hcl /${ROOTCERTPATH}/nomad.d/client.hcl
    sudo systemctl enable nomad
    sudo systemctl start nomad
    sleep 15
    

  fi
  
  /usr/local/bin/nomad node status
  /usr/local/bin/nomad status

}
setup_environment
install_nomad

exit 0
