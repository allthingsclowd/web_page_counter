consul {
  address = "127.0.0.1:8321"
  ssl       = true
  ca_file   = "/etc/ssl/certs/consul-agent-ca.pem"
  cert_file = "/etc/consul.d/pki/tls/certs/consul-client.pem"
  key_file  = "/etc/consul.d/pki/tls/private/consul-client-key.pem"
  token = "5042f882-6326-dde3-8ad5-ade2c9ef6437"
  }
