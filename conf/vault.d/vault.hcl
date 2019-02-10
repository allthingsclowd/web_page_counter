  storage "consul" {
    address = "127.0.0.1:8321"
    scheme = "https"
    path    = "vault/"
    tls_ca_file = "/etc/pki/tls/certs/consul-ca.pem"
    tls_cert_file = "/etc/pki/tls/certs/server.pem"
    tls_key_file = "/etc/pki/tls/private/server-key.pem"
    token = "30fb48b5-33f3-bd6c-3cd9-92cd7cafc058"
  }

  ui = true
