#!/usr/bin/env bash

generate_certificate_config () {
  if [ ! -d /${ROOTCERTPATH}/consul.d ]; then
    sudo mkdir --parents /${ROOTCERTPATH}/consul.d
  fi

  sudo tee /${ROOTCERTPATH}/consul.d/consul_ssl_setup.hcl <<EOF

datacenter = "hashistack"
data_dir = "/usr/local/consul"
encrypt = "${ConsulKeygenOutput}"
log_level = "INFO"
server = ${1}
node_name = "${HOSTNAME}"
addresses {
    https = "0.0.0.0"
}
ports {
    https = 8321
    http = -1
    grpc = 8502
}
connect {
    enabled = true
}
verify_incoming = true
verify_outgoing = true
key_file = "${2}"
cert_file = "${3}"
ca_file = "${4}"
EOF


}

setup_environment () {
  set -x
  sleep 5
  source /usr/local/bootstrap/var.env
  
  IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8;exit}'`
  CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.9" {print $2}'`
  IP=${CIDR%%/24}
  
  # export ConsulKeygenOutput=`/usr/local/bin/consul keygen` [e.g. mUIJq6TITeenfVa2yMSi6yLwxrz2AYcC0dXissYpOxE=]

  if [ -d /vagrant ]; then
    LOG="/vagrant/logs/consul_${HOSTNAME}.log"
  else
    LOG="consul.log"
  fi

  if [ "${TRAVIS}" == "true" ]; then
    ROOTCERTPATH=tmp
    IP=${IP:-127.0.0.1}
  else
    ROOTCERTPATH=etc
  fi

  export ROOTCERTPATH

}

install_prerequisite_binaries () {

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
    }

}

install_chef_inspec () {
    
    [ -f /usr/bin/inspec ] &>/dev/null || {
        pushd /tmp
        curl https://omnitruck.chef.io/install.sh | sudo bash -s -- -P inspec
        popd
    }    

}

install_terraform () {

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
    }

}

install_consul () {
  AGENT_CONFIG="-config-dir=/${ROOTCERTPATH}/consul.d -enable-script-checks=true"

  sudo /usr/local/bootstrap/scripts/create_certificate.sh consul hashistack1 30 ${IP} client
  # Configure consul environment variables for use with certificates 
  export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
  export CONSUL_CACERT=/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem
  export CONSUL_CLIENT_CERT=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem
  export CONSUL_CLIENT_KEY=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem

  # check for consul hostname or travis => server
  if [[ "${HOSTNAME}" =~ "leader" ]] || [ "${TRAVIS}" == "true" ]; then
    echo "Starting a Consul Agent in Server Mode"

    generate_certificate_config true "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-server-key.pem" "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-server.pem" "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem"

    /usr/local/bin/consul members 2>/dev/null || {
      if [ "${TRAVIS}" == "true" ]; then
        
        # copy the example certificates into the correct location - PLEASE CHANGE THESE FOR A PRODUCTION DEPLOYMENT
        sudo /usr/local/bootstrap/scripts/create_certificate.sh consul hashistack1 30 ${IP} server

        sudo ls -al /${ROOTCERTPATH}/consul.d/pki/tls/certs/consul/ /${ROOTCERTPATH}/consul.d/pki/tls/private/consul/
        # sudo ls -al /${ROOTCERTPATH}/consul.d/pki/tls/private/consul/
        sudo /usr/local/bin/consul agent -server -log-level=debug -ui -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -bootstrap-expect=1 >${TRAVIS_BUILD_DIR}/${LOG} &
        sleep 5
        sudo ls -al ${TRAVIS_BUILD_DIR}/${LOG}
        sudo cat ${TRAVIS_BUILD_DIR}/${LOG}
      else
        # copy the example certificates into the correct location - PLEASE CHANGE THESE FOR A PRODUCTION DEPLOYMENT
        sudo /usr/local/bootstrap/scripts/create_certificate.sh consul hashistack1 30 ${IP} server
        sudo sed -i "/ExecStart=/c\ExecStart=/usr/local/bin/consul agent -server -log-level=debug -ui -client=0.0.0.0 -join=${IP} -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -bootstrap-expect=1" /etc/systemd/system/consul.service
        #sudo -u consul cp -r /usr/local/bootstrap/conf/consul.d/* /etc/consul.d/.
        sudo systemctl enable consul
        sudo systemctl start consul
      fi
      sleep 15
      # upload vars to consul kv
      echo "Quick test of the Consul KV store - upload the var.env parameters"
      while read a b; do
        k=${b%%=*}
        v=${b##*=}

        consul kv put "development/$k" $v

      done < /usr/local/bootstrap/var.env
    }
  else
    echo "Starting a Consul Agent in Client Mode"
    
    generate_certificate_config false "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem"

    /usr/local/bin/consul members 2>/dev/null || {
        
        sudo sed -i "/ExecStart=/c\ExecStart=/usr/local/bin/consul agent -log-level=debug -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -join=${LEADER_IP}" /etc/systemd/system/consul.service

        sudo systemctl enable consul
        sudo systemctl start consul
        echo $HOSTNAME
        hostname
        sleep 15
    }
  fi

  echo "Consul Service Started"
}

setup_environment
install_prerequisite_binaries
install_chef_inspec # used for dev/test of scripts
install_terraform # used for testing only
install_consul
exit 0
