  storage "consul" {
    address = "127.0.0.1:8321"
    scheme = "https"
    path    = "vault/"
    tls_ca_file = "/etc/pki/tls/certs/consul-ca.pem"
    tls_cert_file = "/etc/pki/tls/certs/server.pem"
    tls_key_file = "/etc/pki/tls/private/server-key.pem"
    token = "b0a705df-d5ec-8247-76eb-3695fb0a3368"
  }

  ui = true

  listener "tcp" {
    address = "0.0.0.0:8322"
    tls_disable = 0
    tls_cert_file = "/etc/pki/tls/certs/hashistack-server.pem"
    tls_key_file = "/etc/pki/tls/private/hashistack-server-key.pem"
  }
