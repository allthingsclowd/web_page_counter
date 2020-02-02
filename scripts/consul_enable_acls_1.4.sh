#!/usr/bin/env bash
set -x

setup_environment () {
    source /usr/local/bootstrap/var.env

    IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8;exit}'`
    CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.9" {print $2}'`
    IP=${CIDR%%/24}

    if [ -d /vagrant ]; then
    sudo mkdir -p /vagrant/logs
    LOG="/vagrant/logs/consul_${HOSTNAME}.log"
    else
    LOG="consul.log"
    fi

    if [ "${TRAVIS}" == "true" ]; then
      ROOTCERTPATH=tmp
      IP=${IP:-127.0.0.1}
      LEADER_IP=${IP}
    else
      ROOTCERTPATH=etc
    fi

    export ROOTCERTPATH

    # Configure consul environment variables for use with certificates 
    export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
    export CONSUL_CACERT=/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem
    export CONSUL_CLIENT_CERT=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem
    export CONSUL_CLIENT_KEY=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem
    export CONSUL_GRPC_ADDR=https://127.0.0.1:8502

    export VAULT_TOKEN=reallystrongpassword
    export VAULT_ADDR=https://${LEADER_IP}:8322
    export VAULT_CLIENT_KEY=/${ROOTCERTPATH}/vault.d/pki/tls/private/vault-client-key.pem
    export VAULT_CLIENT_CERT=/${ROOTCERTPATH}/vault.d/pki/tls/certs/vault-client.pem
    export VAULT_CACERT=/${ROOTCERTPATH}/ssl/certs/vault-agent-ca.pem
    

    export AGENT_CONFIG="-config-dir=/${ROOTCERTPATH}/consul.d -enable-script-checks=true"

}

create_acl_policy () {

      curl \
      --verbose \
      --request PUT \
      --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
      --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
      --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --data \
    "{
      \"Name\": \"${1}\",
      \"Description\": \"${2}\",
      \"Rules\": \"${3}\"
      }" https://127.0.0.1:8321/v1/acl/policy
}

step1_enable_acls_on_server () {

#   sudo tee /${ROOTCERTPATH}/consul.d/consul_acl_1.4_setup.json <<EOF
#   {
#     "primary_datacenter": "allthingscloud1",
#     "acl" : {
#       "enabled" : true,
#       "default_policy" : "deny",
#       "down_policy" : "extend-cache"
#     }
#   }
# EOF

  sudo tee /${ROOTCERTPATH}/consul.d/consul_acl_1.4_server_setup.hcl <<EOF 
primary_datacenter = "hashistack1"
acl {
    enabled = true
    default_policy = "deny"
    down_policy = "extend-cache"
    }
EOF
  # read in new configs
  restart_consul

}

step2_create_bootstrap_token_on_server () {

  curl -v -w "\n%{http_code}" \
        --request PUT \
        --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
        --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
        --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
        https://127.0.0.1:8321/v1/acl/bootstrap |  {
            read body
            read result
            if [ "$result" == "200" ]; then
                BOOTSTRAPACL=`jq -r .SecretID <<< "$body"`
                echo "The BootStrap ACL received => ${BOOTSTRAPACL}"
                echo -n ${BOOTSTRAPACL} > /usr/local/bootstrap/.bootstrap_acl
                sudo chmod ugo+r /usr/local/bootstrap/.bootstrap_acl
            else
                echo "The system may already be bootstrapped - return code ${result}"

            fi

           }

  BOOTSTRAPACL=`cat /usr/local/bootstrap/.bootstrap_acl`
  export CONSUL_HTTP_TOKEN=${BOOTSTRAPACL}
  echo ${CONSUL_HTTP_TOKEN}
        
}

step3_create_an_agent_token_policies () {
    
    create_acl_policy "agent-policy" "Agent Token" "node_prefix \\\"\\\" { policy = \\\"write\\\"} service_prefix \\\"\\\" { policy = \\\"write\\\" intentions = \\\"write\\\" } "
    create_acl_policy "list-all-nodes" "List All Nodes" "node_prefix \\\"\\\" { policy = \\\"read\\\" }"
    create_acl_policy "ui-access" "Enable UI Access" "key \\\"\\\" { policy = \\\"write\\\"} node \\\"\\\" { policy = \\\"read\\\" } service \\\"\\\" { policy = \\\"read\\\" }"
    create_acl_policy "consul-service" "Consul Service" "service \\\"consul\\\" { policy = \\\"write\\\" }"
    create_acl_policy "development-app" "Sample Development Application" "key_prefix \\\"development/\\\" { policy = \\\"write\\\" }"
}

step4_create_an_agent_token () {
    
    AGENTTOKEN=$(curl -v \
      --request PUT \
      --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
      --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
      --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --data \
    '{
        "Description": "Agent Token",
        "Policies": [
            {
              "Name": "agent-policy"
            },
            {
              "Name": "list-all-nodes"
            },
            {
              "Name": "ui-access"
            },
            {
              "Name": "consul-service"
            },
            {
              "Name": "development-app"
            }
        ],
        "Local": false
      }' https://127.0.0.1:8321/v1/acl/token | jq -r .SecretID)

      echo "The Agent Token received => ${AGENTTOKEN}"
      echo -n ${AGENTTOKEN} > /usr/local/bootstrap/.agenttoken_acl
      sudo chmod ugo+r /usr/local/bootstrap/.agenttoken_acl
      export AGENTTOKEN
}

step5_add_agent_token_on_server () {

#   sudo tee /${ROOTCERTPATH}/consul.d/consul_acl_1.4_setup.json <<EOF
#   {
#   "primary_datacenter": "allthingscloud1",
#   "acl" : {
#     "enabled" : true,
#     "default_policy" : "deny",
#     "down_policy" : "extend-cache",
#     "tokens" : {
#       "agent" : "${AGENTTOKEN}"
#     }
#   }
# }
# EOF

  sudo tee /${ROOTCERTPATH}/consul.d/consul_acl_1.4_server_setup.hcl <<EOF 
primary_datacenter = "hashistack1"
acl {
    enabled = true
    default_policy = "deny"
    down_policy = "extend-cache"
    tokens {
        agent = "${AGENTTOKEN}"
            }
    }
EOF
  # read in new configs
  restart_consul

}

step6_verify_acl_config () {

    curl -v -w "\n%{http_code}" \
      --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
      --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
      --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
      --header "X-Consul-Token: ${AGENTTOKEN}" \
      https://127.0.0.1:8321/v1/catalog/nodes | {
            read body
            read result
            if [ "$result" == "200" ]; then
                TAGGEDADDRESSES=`jq -r '.[0].TaggedAddresses' <<< "$body"`
                if [ "${TAGGEDADDRESSES}" != "" ];then
                  echo "The ACL system appears to be bootstrapped correctly - Tagged Addresses ${TAGGEDADDRESSES}"
                else
                  echo "The ACL system does not appear to be bootstrapped correctly - Tagged Addresses ${TAGGEDADDRESSES}"
                fi
            else
                echo "The ACL system does not appear to be bootstrapped correctly - return code ${result}"

            fi

           }

}

step7_enable_acl_on_client () {

  AGENTTOKEN=`vault kv get -field "value" kv/development/consulagentacl`
  export CONSUL_HTTP_TOKEN=${AGENTTOKEN}

#   sudo tee /${ROOTCERTPATH}/consul.d/consul_acl_1.4_setup.json <<EOF
#   {
#   "acl" : {
#     "enabled" : true,
#     "default_policy" : "deny",
#     "down_policy" : "extend-cache",
#     "tokens" : {
#       "agent" : "${AGENTTOKEN}"
#     }
#   }
# }
# EOF
  sudo tee /${ROOTCERTPATH}/consul.d/consul_acl_1.4_setup.hcl <<EOF
  acl {
      enabled =  true
      default_policy = "deny"
      down_policy =  "extend-cache"
      tokens {
          agent = "${AGENTTOKEN}"
              }
  }
EOF
  # read in new configs
  restart_consul

}

step8_verify_acl_config () {

    AGENTTOKEN=`vault kv get -field "value" kv/development/consulagentacl`

    curl -v -w "\n%{http_code}" \
      --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
      --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
      --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
      --header "X-Consul-Token: ${AGENTTOKEN}" \
      https://127.0.0.1:8321/v1/catalog/nodes | {
            read body
            read result
            if [ "$result" == "200" ]; then
                TAGGEDADDRESSES=`jq -r '.[0].TaggedAddresses' <<< "$body"`
                if [ "${TAGGEDADDRESSES}" != "" ];then
                  echo "The ACL system appears to be bootstrapped correctly - Tagged Addresses ${TAGGEDADDRESSES}"
                else
                  echo "The ACL system does not appear to be bootstrapped correctly - Tagged Addresses ${TAGGEDADDRESSES}"
                fi
            else
                echo "The ACL system does not appear to be bootstrapped correctly - return code ${result}"

            fi

           }

}

create_app_token () {

  create_acl_policy "vault-backend" "Vault Session Token" "node_prefix \\\"\\\" { policy = \\\"write\\\"} service_prefix \\\"\\\" { policy = \\\"write\\\" } key_prefix \\\"vault\\\" { policy = \\\"write\\\" } session_prefix \\\"\\\" { policy = \\\"write\\\" }"
  
  VAULTSESSIONTOKEN=$(curl -v \
  --request PUT \
  --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
  --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
  --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
  --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
  --data \
'{
    "Description": "Vault Token",
    "Policies": [
        {
          "Name": "vault-backend"
        }
    ],
    "Local": false
  }' https://127.0.0.1:8321/v1/acl/token | jq -r .SecretID)

  echo "The Vault Session Token received => ${VAULTSESSIONTOKEN}"
  echo -n ${VAULTSESSIONTOKEN} > /usr/local/bootstrap/.vaulttoken_acl
  sudo chmod ugo+r /usr/local/bootstrap/.vaulttoken_acl
  
  sudo tee /usr/local/bootstrap/conf/vault.d/vault.hcl <<EOF
  storage "consul" {
    address = "127.0.0.1:8321"
    scheme = "https"
    path    = "vault/"
    tls_ca_file = "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem"
    tls_cert_file = "/${ROOTCERTPATH}/vault.d/pki/tls/certs/consul/consul-client.pem"
    tls_key_file = "/${ROOTCERTPATH}/vault.d/pki/tls/private/consul/consul-client-key.pem"
    token = "${VAULTSESSIONTOKEN}"
  }

  ui = true

  listener "tcp" {
    address = "0.0.0.0:8322"
    tls_disable = 0
    tls_cert_file = "/${ROOTCERTPATH}/vault.d/pki/tls/certs/vault/vault-server.pem"
    tls_key_file = "/${ROOTCERTPATH}/vault.d/pki/tls/private/vault/vault-server-key.pem"
  }

  # Advertise the non-loopback interface
  api_addr = "https://${LEADER_IP}:8322"
  cluster_addr = "https://${LEADER_IP}:8322"
EOF

  sudo tee /usr/local/bootstrap/conf/nomad.d/nomad.hcl <<EOF
consul {
  address = "127.0.0.1:8321"
  ssl       = true
  ca_file   = "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem"
  cert_file = "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem"
  key_file  = "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem"
  token = "${CONSUL_HTTP_TOKEN}"
  }
EOF

}

step9_configure_nomad() {

  AGENTTOKEN=`vault kv get -field "value" kv/development/bootstraptoken`

  sudo tee /usr/local/bootstrap/conf/nomad.d/nomad.hcl <<EOF
consul {
  address = "127.0.0.1:8321"
  ssl       = true
  ca_file   = "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem"
  cert_file = "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem"
  key_file  = "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem"
  token = "${AGENTTOKEN}"
  }
EOF

} 


restart_consul () {
    
    
    #sudo cp -r /usr/local/bootstrap/conf/consul.d/* /${ROOTCERTPATH}/consul.d/.
    if [ "${TRAVIS}" == "true" ]; then
        sudo killall -9 -v consul
        sleep 5
        sudo /usr/local/bin/consul agent -server -log-level=trace -ui -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -bootstrap-expect=1 >${LOG} &
        sleep 15
    else
        sudo systemctl restart consul
        sleep 15
        #sudo systemctl status consul
    fi
    
  
}

consul_acl_config () {

  # check for consul hostname or travis => server
  if [[ "${HOSTNAME}" =~ "leader" ]] || [ "${TRAVIS}" == "true" ]; then
    echo server
    step1_enable_acls_on_server
    step2_create_bootstrap_token_on_server
    step3_create_an_agent_token_policies
    step4_create_an_agent_token
    step5_add_agent_token_on_server
    step6_verify_acl_config

    # for vault backend
    create_app_token
    
  else
    echo "Configuring Consul ACLs on Agent"
    step7_enable_acl_on_client
    step8_verify_acl_config
    step9_configure_nomad
    
  fi
  
  if [ "${TRAVIS}" == "true" ]; then
    create_app_token
  fi
  verify_consul_access
  echo consul started
}

verify_consul_access () {
      
      echo 'Testing Consul KV by Uploading some key/values'

      #lets delete old consul storage
      consul kv delete -recurse development
        # upload vars to consul kv
      while read a b; do
        k=${b%%=*}
        v=${b##*=}

        consul kv put "development/$k" $v

      done < /usr/local/bootstrap/var.env
      
      consul kv export "development/"
      
      consul members
}

setup_environment
consul_acl_config
exit 0
