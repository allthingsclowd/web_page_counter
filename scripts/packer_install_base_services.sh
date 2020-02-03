#!/usr/bin/env bash

create_service () {
  if [ ! -f /etc/systemd/system/${1}.service ]; then
    
    create_service_user ${1}
    
    sudo tee /etc/systemd/system/${1}.service <<EOF
### BEGIN INIT INFO
# Provides:          ${1}
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${1} agent
# Description:       ${2}
### END INIT INFO

[Unit]
Description=${2}
Requires=network-online.target
After=network-online.target
ConditionDirectoryNotEmpty=/etc/${1}.d/
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=${4}
User=${1}
Group=${1}
PIDFile=/var/run/${1}/${1}.pid
PermissionsStartOnly=true
ExecStartPre=/bin/mkdir -p /var/run/${1}
ExecStartPre=/bin/chown -R ${1}:${1} /var/run/${1}
ExecStart=${3}
ExecReload=/bin/kill -HUP ${MAINPID}
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=2s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  fi

}

create_vault_serviced () {
  if [ ! -f /etc/systemd/system/${1}.service ]; then
    
    create_service_user ${1}
    
    sudo tee /etc/systemd/system/${1}.service <<EOF
### BEGIN INIT INFO
# Provides:          ${1}
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${1} agent
# Description:       ${2}
### END INIT INFO

[Unit]
Description=${2}
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionDirectoryNotEmpty=/etc/${1}.d/
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=${1}
Group=${1}
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=${3}
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

  fi

}

create_root_CA_certificate () {

  # ${1} - domain name - e.g. consul
  # ${2} - duration in days that CA is valid for
  
  # create file layout for the certs
  [ -d /${ROOTCERTPATH}/ssl/CA ] &>/dev/null || {
    sudo mkdir --parent /${ROOTCERTPATH}/ssl/CA /${ROOTCERTPATH}/ssl/certs /${ROOTCERTPATH}/ssl/private
  }
  pushd /${ROOTCERTPATH}/ssl/CA
  sudo /usr/local/bin/consul tls ca create -domain=${1} -days=${2}
  sudo mv /${ROOTCERTPATH}/ssl/CA/${1}-agent-ca.pem /${ROOTCERTPATH}/ssl/certs/.
  sudo mv /${ROOTCERTPATH}/ssl/CA/${1}-agent-ca-key.pem /${ROOTCERTPATH}/ssl/private/.
  sudo chmod -R 755 /${ROOTCERTPATH}/ssl/certs
  sudo chmod -R 755 /${ROOTCERTPATH}/ssl/private
  sudo ls -al /${ROOTCERTPATH}/ssl/certs /${ROOTCERTPATH}/ssl/private
  popd

}

configure_certificates () {

    # create nomad directories
    sudo -u nomad mkdir --parents /${ROOTCERTPATH}/nomad.d/pki/tls/private /${ROOTCERTPATH}/nomad.d/pki/tls/certs
    sudo -u nomad chmod -R 644 /${ROOTCERTPATH}/nomad.d/pki/tls/certs
    sudo -u nomad chmod -R 644 /${ROOTCERTPATH}/nomad.d/pki/tls/private

    sudo -u consul mkdir --parents /${ROOTCERTPATH}/consul.d/pki/tls/private /${ROOTCERTPATH}/consul.d/pki/tls/certs
    sudo -u consul chmod -R 644 /${ROOTCERTPATH}/consul.d/pki/tls/certs
    sudo -u consul chmod -R 644 /${ROOTCERTPATH}/consul.d/pki/tls/private

    sudo -u vault mkdir --parents /${ROOTCERTPATH}/vault.d/pki/tls/private /${ROOTCERTPATH}/vault.d/pki/tls/certs
    sudo -u vault chmod -R 644 /${ROOTCERTPATH}/vault.d/pki/tls/certs
    sudo -u vault chmod -R 644 /${ROOTCERTPATH}/vault.d/pki/tls/private
  
    # copy ssh CA certificate onto host
    sudo cp -r /usr/local/bootstrap/certificate-config/ssh_host/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
    sudo chmod 644 /etc/ssh/ssh_host_rsa_key.pub
    sudo cp -r /usr/local/bootstrap/certificate-config/ssh_host/ssh_host_rsa_key-cert.pub /etc/ssh/ssh_host_rsa_key-cert.pub
    sudo chmod 644 /etc/ssh/ssh_host_rsa_key-cert.pub
    sudo cp -r /usr/local/bootstrap/certificate-config/ssh_host/client-ca.pub /etc/ssh/client-ca.pub
    sudo chmod 644 /etc/ssh/client-ca.pub
    sudo cp -r /usr/local/bootstrap/certificate-config/ssh_host/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
    sudo chmod 600 /etc/ssh/ssh_host_rsa_key
    # enable ssh CA certificate
    grep -qxF 'TrustedUserCAKeys /etc/ssh/client-ca.pub' /etc/ssh/sshd_config || echo 'TrustedUserCAKeys /etc/ssh/client-ca.pub' | sudo tee -a /etc/ssh/sshd_config
    grep -qxF 'HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub' /etc/ssh/sshd_config || echo 'HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub' | sudo tee -a /etc/ssh/sshd_config
}

create_service_user () {
  
  if ! grep ${1} /etc/passwd >/dev/null 2>&1; then
    
    echo "Creating ${1} user to run the ${1} service"
    sudo groupadd -f -r ${1}
    sudo useradd -g ${1} --system --home-dir /etc/${1}.d --create-home --shell /bin/false ${1}
    sudo mkdir --parents /opt/${1} /usr/local/${1} /etc/${1}.d
    sudo chown -R ${1}:${1} /opt/${1} /usr/local/${1} /etc/${1}.d

  fi

}

create_consul_service () {
    
    create_service consul "HashiCorp Consul Server SD & KV Service" "/usr/local/bin/consul agent -server -log-level=debug -ui -client=0.0.0.0 -bind=${IP} -join=${IP} -config-dir=/${ROOTCERTPATH}/consul.d -enable-script-checks=true -data-dir=/usr/local/consul -bootstrap-expect=1" notify
    sudo systemctl disable consul
}

create_vault_service () {
    
    sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault
    create_vault_serviced vault "HashiCorp Secret Management Service" "/usr/local/bin/vault server -dev -dev-root-token-id=\"reallystrongpassword\" -config=/${ROOTCERTPATH}/vault.d/vault.hcl"
    sudo systemctl disable vault
}

create_nomad_service () {
    
    create_service nomad "HashiCorp's Nomad Server - A Modern Platform and Cloud Agnostic Scheduler" "/usr/local/bin/nomad agent -log-level=DEBUG -server -data-dir=/usr/local/nomad -bootstrap-expect=1 -config=/${ROOTCERTPATH}/nomad.d" simple
    sudo systemctl disable nomad
}

create_envoy_service () {
    
    create_service envoy "Envoy Proxy Server" "/usr/bin/envoy" simple
    sudo systemctl disable envoy
}

setup_environment (){
  set -x
  if [ "${TRAVIS}" == "true" ]; then
    ROOTCERTPATH=tmp
  else
    ROOTCERTPATH=etc
  fi

  export ROOTCERTPATH
}

setup_environment
create_consul_service
create_vault_service
create_nomad_service
create_envoy_service

create_root_CA_certificate consul 30
create_root_CA_certificate vault 30
create_root_CA_certificate nomad 30
configure_certificates
