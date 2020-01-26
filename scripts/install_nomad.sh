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
  export VAULT_CLIENT_KEY=/usr/local/bootstrap/certificate-config/vault/vault-client-key.pem
  export VAULT_CLIENT_CERT=/usr/local/bootstrap/certificate-config/vault/vault-client.pem
  export VAULT_CACERT=/usr/local/bootstrap/certificate-config/hashistack/hashistack-ca.pem

  # Configure consul environment variables for use with certificates 
  export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
  export CONSUL_CACERT=/usr/local/bootstrap/certificate-config/hashistack/hashistack-ca.pem
  export CONSUL_CLIENT_CERT=/usr/local/bootstrap/certificate-config/consul/consul-client.pem
  export CONSUL_CLIENT_KEY=/usr/local/bootstrap/certificate-config/consul/consul-client-key.pem
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

install_nomad() {
  # check for nomad hostname => server
  if [[ "${HOSTNAME}" =~ "leader" ]] || [ "${TRAVIS}" == "true" ]; then
    if [ "${TRAVIS}" == "true" ]; then
      # move consul certificates for nomad in place
      sudo mkdir --parents /etc/nomad.d/pki/tls/private/nomad /etc/nomad.d/pki/tls/certs/nomad /etc/nomad.d/pki/tls/certs/hashistack
      sudo mkdir --parents /etc/nomad.d/pki/tls/private/consul /etc/nomad.d/pki/tls/certs/consul

      sudo cp -r /usr/local/bootstrap/certificate-config/nomad/nomad-server-key.pem /etc/nomad.d/pki/tls/private/nomad/nomad-server-key.pem
      sudo cp -r /usr/local/bootstrap/certificate-config/nomad/nomad-server.pem /etc/nomad.d/pki/tls/certs/nomad/nomad-server.pem
      sudo cp -r /usr/local/bootstrap/certificate-config/hashistack/hashistack-ca.pem /etc/nomad.d/pki/tls/certs/hashistack/hashistack-ca.pem

      sudo cp -r /usr/local/bootstrap/certificate-config/consul/consul-client-key.pem /etc/nomad.d/pki/tls/private/consul/consul-client-key.pem
      sudo cp -r /usr/local/bootstrap/certificate-config/consul/consul-client.pem /etc/nomad.d/pki/tls/certs/consul/consul-client.pem 
   
      sudo cp -apr /usr/local/bootstrap/conf/nomad.d /etc
      sudo /usr/local/bin/nomad agent -server -bind=${IP} -data-dir=/usr/local/nomad -bootstrap-expect=1 -config=/etc/nomad.d >${LOG} &
    else
      NOMAD_ADDR=http://${IP}:4646 /usr/local/bin/nomad agent-info 2>/dev/null || {
        sudo sed -i "/ExecStart=/c\ExecStart=/usr/local/bin/nomad agent -log-level=DEBUG -server -bind=${IP} -data-dir=/usr/local/nomad -bootstrap-expect=1 -config=/etc/nomad.d" /etc/systemd/system/nomad.service
        cp -apr /usr/local/bootstrap/conf/nomad.d /etc
        sudo systemctl enable nomad
        sudo systemctl start nomad
        
      }
    fi
    sleep 15

  else

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
