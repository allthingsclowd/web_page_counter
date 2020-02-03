consul {
  address = "127.0.0.1:8321"
  ssl       = true
  ca_file   = "/etc/ssl/certs/consul-agent-ca.pem"
  cert_file = "/etc/consul.d/pki/tls/certs/consul-client.pem"
  key_file  = "/etc/consul.d/pki/tls/private/consul-client-key.pem"
  token = "25a3f88c-0cc1-d2bc-0590-15dcad344c2c"
  }
