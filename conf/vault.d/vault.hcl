  storage "consul" {
    address = "127.0.0.1:8321"
    scheme = "https"
    path    = "vault/"
    tls_ca_file = "/etc/pki/tls/certs/consul-ca.pem"
    tls_cert_file = "/etc/pki/tls/certs/server.pem"
    tls_key_file = "/etc/pki/tls/private/server-key.pem"
    token = "22008e9b-b4bb-4cca-4627-90a00fbcb9b3"
  }

  ui = true

  listener "tcp" {
    address = "0.0.0.0:8322"
    tls_disable = 0
    tls_cert_file = "/etc/pki/tls/certs/hashistack-server.pem"
    tls_key_file = "/etc/pki/tls/private/hashistack-server-key.pem"
  }
