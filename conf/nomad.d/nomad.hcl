consul {
  address = "127.0.0.1:8321"
  ssl       = true
  ca_file   = "/etc/pki/tls/certs/consul-ca.pem"
  cert_file = "/etc/pki/tls/certs/server.pem"
  key_file  = "/etc/pki/tls/private/server-key.pem"
  token = ""
  }
