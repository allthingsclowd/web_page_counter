#!/usr/bin/env bash

generate_certificate_config () {
  if [ ! -d /etc/consul.d ]; then
    sudo mkdir --parents /etc/consul.d
  fi

  sudo tee /etc/consul.d/consul_ssl_setup.hcl <<EOF

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
    IP=${IP:-127.0.0.1}
  fi

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

install_consul () {
  AGENT_CONFIG="-config-dir=/etc/consul.d -enable-script-checks=true"


  create_certificate consul hashistack1 30 ${IP} client
  # Configure consul environment variables for use with certificates 
  export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
  export CONSUL_CACERT=/etc/ssl/certs/consul-agent-ca.pem
  export CONSUL_CLIENT_CERT=/etc/consul.d/pki/tls/certs/consul-client.pem
  export CONSUL_CLIENT_KEY=/etc/consul.d/pki/tls/private/consul-client-key.pem

  # check for consul hostname or travis => server
  if [[ "${HOSTNAME}" =~ "leader" ]] || [ "${TRAVIS}" == "true" ]; then
    echo "Starting a Consul Agent in Server Mode"

    generate_certificate_config true "/etc/consul.d/pki/tls/private/consul/consul-server-key.pem" "/etc/consul.d/pki/tls/certs/consul/consul-server.pem" "/etc/ssl/certs/consul-agent-ca.pem"

    /usr/local/bin/consul members 2>/dev/null || {
      if [ "${TRAVIS}" == "true" ]; then

        sudo -u consul mkdir --parents /etc/consul.d/pki/tls/private/nomad /etc/consul.d/pki/tls/certs/nomad
        sudo -u consul mkdir --parents /etc/consul.d/pki/tls/private/consul /etc/consul.d/pki/tls/certs/consul
        sudo -u consul mkdir --parents /etc/consul.d/pki/tls/private/vault /etc/consul.d/pki/tls/certs/vault
        sudo -u consul chmod -R 644 /etc/consul.d/pki/tls/certs/nomad /etc/consul.d/pki/tls/certs/consul /etc/consul.d/pki/tls/certs/vault
        sudo -u consul chmod -R 600 /etc/consul.d/pki/tls/private/vault /etc/consul.d/pki/tls/private/consul /etc/consul.d/pki/tls/private/nomad
        
        # copy the example certificates into the correct location - PLEASE CHANGE THESE FOR A PRODUCTION DEPLOYMENT
        create_certificate consul hashistack1 30 ${IP} server

        sudo ls -al /etc/consul.d/pki/tls/certs/consul/ /etc/consul.d/pki/tls/private/consul/
        # sudo ls -al /etc/consul.d/pki/tls/private/consul/
        sudo /usr/local/bin/consul agent -server -log-level=debug -ui -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -bootstrap-expect=1 >${TRAVIS_BUILD_DIR}/${LOG} &
        sleep 5
        sudo ls -al ${TRAVIS_BUILD_DIR}/${LOG}
        sudo cat ${TRAVIS_BUILD_DIR}/${LOG}
      else
        # copy the example certificates into the correct location - PLEASE CHANGE THESE FOR A PRODUCTION DEPLOYMENT
        create_certificate consul hashistack1 30 ${IP} server
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
    
    generate_certificate_config false "/etc/consul.d/pki/tls/private/consul-client-key.pem" "/etc/consul.d/pki/tls/certs/consul-client.pem" "/etc/ssl/certs/consul-agent-ca.pem"

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
