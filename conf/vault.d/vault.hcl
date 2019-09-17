  storage "consul" {
    address = "127.0.0.1:8321"
    scheme = "https"
    path    = "vault/"
    tls_ca_file = "/etc/pki/tls/certs/consul-ca.pem"
    tls_cert_file = "/etc/pki/tls/certs/server.pem"
    tls_key_file = "/etc/pki/tls/private/server-key.pem"
    token = "cd76a583-deb2-9468-6da7-8c9eb951fe3f"
  }

  ui = true

  listener "tcp" {
    address = "0.0.0.0:8322"
    tls_disable = 0
    tls_cert_file = "/etc/pki/tls/certs/hashistack-server.pem"
    tls_key_file = "/etc/pki/tls/private/hashistack-server-key.pem"
  }
