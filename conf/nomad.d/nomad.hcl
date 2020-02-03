consul {
  address = "127.0.0.1:8321"
  ssl       = true
  ca_file   = "/etc/ssl/certs/consul-agent-ca.pem"
  cert_file = "/etc/consul.d/pki/tls/certs/consul-client.pem"
  key_file  = "/etc/consul.d/pki/tls/private/consul-client-key.pem"
  token = "a91deaf6-3242-a8d6-11e0-c3623e3cb6a2"
  }
