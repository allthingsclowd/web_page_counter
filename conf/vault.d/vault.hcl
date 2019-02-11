  storage "consul" {
    address = "127.0.0.1:8321"
    scheme = "https"
    path    = "vault/"
    tls_ca_file = "/etc/pki/tls/certs/consul-ca.pem"
    tls_cert_file = "/etc/pki/tls/certs/server.pem"
    tls_key_file = "/etc/pki/tls/private/server-key.pem"
    token = "cdf67621-339e-1086-a3e7-9b099103a9cb"
  }

  ui = true
