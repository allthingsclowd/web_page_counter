#
# Outputs
#

locals {
  hashistackdemo = <<AZUREDEMO

Welcome to The TAM HashiStack demo
        
            on Azure

Open a browser on the following URLs to access each service

    WebPageCounter Application FrontEnd -   http://${data.azurerm_public_ip.web_front_end.ip_address}:9091
    WebPageCounter Application BackEnd  -   http://${data.azurerm_public_ip.web_front_end.ip_address}:9090
    Nomad Portal    -   http://${azurerm_network_interface.wpcnic.private_ip_address}:4646
    Vault Portal    -   http://${azurerm_network_interface.wpcnic.private_ip_address}:8200
    Consul Portal   -   https://${azurerm_network_interface.wpcnic.private_ip_address}:8321
    (self-signed certificates - ../certificate-config directory)

    Vault Password  -   reallystrongpassword
    Consul ACL  -   Navigate to Vault to locate the consul ACL token then use it to login to the Consul portal

AZUREDEMO

}

output "hashistackdemo" {
  value = "${local.hashistackdemo}"
}
