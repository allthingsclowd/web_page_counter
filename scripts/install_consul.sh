#!/usr/bin/env bash


create_consul_service_user () {
  
  if ! grep consul /etc/passwd >/dev/null 2>&1; then
    echo "Creating consul user to run the consul service"
    sudo useradd --system --home /etc/consul.d --shell /bin/false consul
    sudo mkdir --parents /opt/consul /usr/local/consul /etc/consul.d
    sudo chown --recursive consul:consul /opt/consul /etc/consul.d /usr/local/consul
  fi

}

setup_environment () {
  set -x
  source /usr/local/bootstrap/var.env

  IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8;exit}'`
  CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
  IP=${CIDR%%/24}

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
      [ -f consul_1.3.0_linux_amd64.zip ] || {
          sudo wget -q https://releases.hashicorp.com/consul/1.3.0/consul_1.3.0_linux_amd64.zip
      }
      sudo unzip consul_1.3.0_linux_amd64.zip
      sudo chmod +x consul
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
      popd
  }
}

install_consul () {
  AGENT_CONFIG="-config-dir=/etc/consul.d -enable-script-checks=true"
  
  # check for consul hostname or travis => server
  if [[ "${HOSTNAME}" =~ "leader" ]] || [ "${TRAVIS}" == "true" ]; then
    echo "Starting a Consul Server"

    if [ "${TRAVIS}" == "true" ]; then
      COUNTER=0
      HOSTURL="http://${IP}:808${COUNTER}/health"
      sudo cp /usr/local/bootstrap/conf/consul.d/redis.json /etc/consul.d/redis.json
      CONSUL_SCRIPTS="scripts"
      # ensure all scripts are executable for consul health checks
      pushd ${CONSUL_SCRIPTS}
      for file in `ls`;
        do
          sudo chmod +x $file
        done
      popd
    fi

    /usr/local/bin/consul members 2>/dev/null || {
        sudo -u consul cp -r /usr/local/bootstrap/conf/consul.d/* /etc/consul.d/.
        sudo -u consul /usr/local/bin/consul agent -server -log-level=debug -ui -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -bootstrap-expect=1 >${LOG} &
      
      sleep 5
      # upload vars to consul kv
      echo "Quick test of the Consul KV store - upload the var.env parameters"
      while read a b; do
        k=${b%%=*}
        v=${b##*=}

        consul kv put "development/$k" $v

      done < /usr/local/bootstrap/var.env
    }
  else
    echo "Starting a Consul Agent"
    /usr/local/bin/consul members 2>/dev/null || {
      sudo -u consul /usr/local/bin/consul agent -log-level=debug -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -join=${LEADER_IP} >${LOG} &
      sleep 10
    }
  fi

  echo "Consul Service Started"
}

setup_environment
install_prerequisite_binaries
create_consul_service_user
install_consul

