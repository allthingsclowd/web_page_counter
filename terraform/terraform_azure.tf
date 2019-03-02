
variable "arm_subscription_id" {
  description = "Azure subscription identifier"
}

variable "arm_client_id" {
  description = "Service principal client identifier"
}

variable "arm_client_secret" {
  description = "Service principal secret"
}

variable "arm_tenant_id" {
  description = "Azure tenant identifier"
}

variable "arm_sshkey" {
  description = "Azure ssh public key"
}

variable "arm_resource_group" {
  description = "Resource Group Name"
}

variable "local_cidr" {
  description = "Firewall Access"
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "${var.arm_subscription_id}"
    client_id       = "${var.arm_client_id}"
    client_secret   = "${var.arm_client_secret}"
    tenant_id       = "${var.arm_tenant_id}"
}

# Create virtual network
resource "azurerm_virtual_network" "webpagecounternetwork" {
    name                = "wpcVnet"
    address_space       = ["192.168.0.0/16"]
    location            = "westeurope"
    resource_group_name = "${var.arm_resource_group}"

    tags {
        environment = "Web Page Counter"
    }
}

# Create subnet
resource "azurerm_subnet" "webpagecountersubnet" {
    name                 = "wpcSubnet"
    resource_group_name  = "${var.arm_resource_group}"
    virtual_network_name = "${azurerm_virtual_network.webpagecounternetwork.name}"
    address_prefix       = "192.168.2.0/24"
}

# Create public IP for leader01
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "wpcPublicIPleader"
    location                     = "westeurope"
    resource_group_name          = "${var.arm_resource_group}"
    allocation_method            = "Dynamic"

    tags {
        environment = "Web Page Counter"
    }
}

# Create public IP for leader01
resource "azurerm_public_ip" "wpcpublicipproxy" {
    name                         = "wpcPublicIPproxy"
    location                     = "westeurope"
    resource_group_name          = "${var.arm_resource_group}"
    allocation_method            = "Dynamic"

    tags {
        environment = "Web Page Counter"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${var.arm_resource_group}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${var.arm_resource_group}"
    location                    = "westeurope"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        environment = "Web Page Counter"
    }
}

# Create Network Security Group and rule for leader
resource "azurerm_network_security_group" "wpcleadernsg" {
    name                = "wpcleaderNetworkSecurityGroup"
    location            = "westeurope"
    resource_group_name = "${var.arm_resource_group}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "${var.local_cidr}"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "CONSUL"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8321"
        source_address_prefix      = "${var.local_cidr}"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "VAULT"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8200"
        source_address_prefix      = "${var.local_cidr}"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "NOMAD"
        priority                   = 1004
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "4646"
        source_address_prefix      = "${var.local_cidr}"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "FACTORY"
        priority                   = 1005
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8314"
        source_address_prefix      = "${var.local_cidr}"
        destination_address_prefix = "*"
    }

    tags {
        environment = "Web Page Counter"
    }
}

# Create Network Security Group and rule for other systems
resource "azurerm_network_security_group" "wpcothersnsg" {
    name                = "wpcothersNetworkSecurityGroup"
    location            = "westeurope"
    resource_group_name = "${var.arm_resource_group}"

    security_rule {
        name                       = "SSH"
        priority                   = 1006
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "${var.local_cidr}"
        destination_address_prefix = "*"
    }

    tags {
        environment = "Web Page Counter"
    }
}

# Create Network Security Group and rule for proxy
resource "azurerm_network_security_group" "wpcproxynsg" {
    name                = "wpcproxyNetworkSecurityGroup"
    location            = "westeurope"
    resource_group_name = "${var.arm_resource_group}"

    security_rule {
        name                       = "SSH"
        priority                   = 1007
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "${var.local_cidr}"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "WEBFRONTEND"
        priority                   = 1008
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "9091"
        source_address_prefix      = "${var.local_cidr}"
        destination_address_prefix = "*"
    }

    tags {
        environment = "Web Page Counter"
    }
}

# Create network interface with public ip for leader
resource "azurerm_network_interface" "wpcnic" {
    name                      = "wpcNIC"
    location                  = "westeurope"
    resource_group_name       = "${var.arm_resource_group}"
    network_security_group_id = "${azurerm_network_security_group.wpcleadernsg.id}"

    ip_configuration {
        name                          = "wpcNicConfiguration"
        subnet_id                     = "${azurerm_subnet.webpagecountersubnet.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = "${cidrhost("192.168.2.0/24", 11)}"
        public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
    }

    tags {
        environment = "Web Page Counter"
    }
}

# Create network interface with public ip for web01
resource "azurerm_network_interface" "wpcproxynic" {
    name                      = "wpcproxyNIC"
    location                  = "westeurope"
    resource_group_name       = "${var.arm_resource_group}"
    network_security_group_id = "${azurerm_network_security_group.wpcproxynsg.id}"

    ip_configuration {
        name                          = "wpcproxyNicConfiguration"
        subnet_id                     = "${azurerm_subnet.webpagecountersubnet.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = "${cidrhost("192.168.2.0/24", 250)}"
        public_ip_address_id          = "${azurerm_public_ip.wpcpublicipproxy.id}"
    }

    tags {
        environment = "Web Page Counter"
    }
}

# Create network interface with public ip for redis01
resource "azurerm_network_interface" "wpcredisnic" {
    name                      = "wpcredisNIC"
    location                  = "westeurope"
    resource_group_name       = "${var.arm_resource_group}"
    network_security_group_id = "${azurerm_network_security_group.wpcothersnsg.id}"

    ip_configuration {
        name                          = "wpcredisNicConfiguration"
        subnet_id                     = "${azurerm_subnet.webpagecountersubnet.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = "${cidrhost("192.168.2.0/24", 200)}"
    }

    tags {
        environment = "Web Page Counter"
    }
}

# Create network interface with public ip for godev01
resource "azurerm_network_interface" "wpcgodev01nic" {
    name                      = "wpcgodev01NIC"
    location                  = "westeurope"
    resource_group_name       = "${var.arm_resource_group}"
    network_security_group_id = "${azurerm_network_security_group.wpcothersnsg.id}"

    ip_configuration {
        name                          = "wpcgodev01NicConfiguration"
        subnet_id                     = "${azurerm_subnet.webpagecountersubnet.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = "${cidrhost("192.168.2.0/24", 110)}"
    }

    tags {
        environment = "Web Page Counter"
    }
}

# Create network interface with public ip for godev02
resource "azurerm_network_interface" "wpcgodev02nic" {
    name                      = "wpcgodev02NIC"
    location                  = "westeurope"
    resource_group_name       = "${var.arm_resource_group}"
    network_security_group_id = "${azurerm_network_security_group.wpcothersnsg.id}"

    ip_configuration {
        name                          = "wpcgodev02NicConfiguration"
        subnet_id                     = "${azurerm_subnet.webpagecountersubnet.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = "${cidrhost("192.168.2.0/24", 120)}"
    }

    tags {
        environment = "Web Page Counter"
    }
}

# Create cloud-init config for leader01
data "template_file" "leadercloudconfig" {

  template = "${file("../scripts/leader_cloud_config.txt")}"
}

#https://www.terraform.io/docs/providers/template/d/cloudinit_config.html
data "template_cloudinit_config" "leadercloudconfig" {
  gzip          = true
  base64_encode = true

  part {
    content = "${data.template_file.leadercloudconfig.rendered}"
  }
}

# Create cloud-init config for Redis01
data "template_file" "rediscloudconfig" {

  template = "${file("../scripts/redis_cloud_config.txt")}"
}

#https://www.terraform.io/docs/providers/template/d/cloudinit_config.html
data "template_cloudinit_config" "rediscloudconfig" {
  gzip          = true
  base64_encode = true

  part {
    content = "${data.template_file.rediscloudconfig.rendered}"
  }
}

# Create cloud-init config for Web01
data "template_file" "webcloudconfig" {

  template = "${file("../scripts/web_cloud_config.txt")}"
}

#https://www.terraform.io/docs/providers/template/d/cloudinit_config.html
data "template_cloudinit_config" "webcloudconfig" {
  gzip          = true
  base64_encode = true

  part {
    content = "${data.template_file.webcloudconfig.rendered}"
  }
}

# Create cloud-init config for godev0x
data "template_file" "godevcloudconfig" {

  template = "${file("../scripts/godev_cloud_config.txt")}"
}

#https://www.terraform.io/docs/providers/template/d/cloudinit_config.html
data "template_cloudinit_config" "godevcloudconfig" {
  gzip          = true
  base64_encode = true

  part {
    content = "${data.template_file.godevcloudconfig.rendered}"
  }
}

# Create virtual machine leader01
resource "azurerm_virtual_machine" "myterraformvm" {
    name                  = "leader01"
    location              = "westeurope"
    resource_group_name   = "${var.arm_resource_group}"
    network_interface_ids = ["${azurerm_network_interface.wpcnic.id}"]
    vm_size               = "Standard_DS2_v2"

    # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_os_disk_on_termination = true

    # This means the Data Disk Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "leaderOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        id = "/subscriptions/c0a607b2-6372-4ef3-abdb-dbe52a7b56ba/resourceGroups/graham-dev/providers/Microsoft.Compute/images/webPageCounter"
    }

    os_profile {
        computer_name  = "leader01"
        admin_username = "azureuser"
        custom_data    = "${data.template_cloudinit_config.leadercloudconfig.rendered}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "${var.arm_sshkey}"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Web Page Counter"
    }

}

# Create virtual machine redis01
resource "azurerm_virtual_machine" "redisvm" {
    name                  = "redis01"
    location              = "westeurope"
    resource_group_name   = "${var.arm_resource_group}"
    network_interface_ids = ["${azurerm_network_interface.wpcredisnic.id}"]
    vm_size               = "Standard_DS2_v2"

    # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_os_disk_on_termination = true

    # This means the Data Disk Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "redisOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        id = "/subscriptions/c0a607b2-6372-4ef3-abdb-dbe52a7b56ba/resourceGroups/graham-dev/providers/Microsoft.Compute/images/webPageCounter"
    }

    os_profile {
        computer_name  = "redis01"
        admin_username = "azureuser"
        custom_data    = "${data.template_cloudinit_config.rediscloudconfig.rendered}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "${var.arm_sshkey}"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Web Page Counter"
    }

    depends_on = ["azurerm_virtual_machine.myterraformvm"]

}

# Create virtual machine web01
resource "azurerm_virtual_machine" "webvm" {
    name                  = "web01"
    location              = "westeurope"
    resource_group_name   = "${var.arm_resource_group}"
    network_interface_ids = ["${azurerm_network_interface.wpcproxynic.id}"]
    vm_size               = "Standard_DS2_v2"

    # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_os_disk_on_termination = true

    # This means the Data Disk Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "webOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        id = "/subscriptions/c0a607b2-6372-4ef3-abdb-dbe52a7b56ba/resourceGroups/graham-dev/providers/Microsoft.Compute/images/webPageCounter"
    }

    os_profile {
        computer_name  = "web01"
        admin_username = "azureuser"
        custom_data    = "${data.template_cloudinit_config.webcloudconfig.rendered}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "${var.arm_sshkey}"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Web Page Counter"
    }

    depends_on = ["azurerm_virtual_machine.godev01vm","azurerm_virtual_machine.godev02vm"]

}

# Create virtual machine godev01
resource "azurerm_virtual_machine" "godev01vm" {
    name                  = "godev01"
    location              = "westeurope"
    resource_group_name   = "${var.arm_resource_group}"
    network_interface_ids = ["${azurerm_network_interface.wpcgodev01nic.id}"]
    vm_size               = "Standard_DS2_v2"

    # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_os_disk_on_termination = true

    # This means the Data Disk Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "godev01OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        id = "/subscriptions/c0a607b2-6372-4ef3-abdb-dbe52a7b56ba/resourceGroups/graham-dev/providers/Microsoft.Compute/images/webPageCounter"
    }

    os_profile {
        computer_name  = "godev01"
        admin_username = "azureuser"
        custom_data    = "${data.template_cloudinit_config.godevcloudconfig.rendered}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "${var.arm_sshkey}"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Web Page Counter"
    }

    depends_on = ["azurerm_virtual_machine.myterraformvm","azurerm_virtual_machine.redisvm"]

}

# Create virtual machine godev02
resource "azurerm_virtual_machine" "godev02vm" {
    name                  = "godev02"
    location              = "westeurope"
    resource_group_name   = "${var.arm_resource_group}"
    network_interface_ids = ["${azurerm_network_interface.wpcgodev02nic.id}"]
    vm_size               = "Standard_DS2_v2"

    # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_os_disk_on_termination = true

    # This means the Data Disk Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "godev02OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        id = "/subscriptions/c0a607b2-6372-4ef3-abdb-dbe52a7b56ba/resourceGroups/graham-dev/providers/Microsoft.Compute/images/webPageCounter"
    }

    os_profile {
        computer_name  = "godev02"
        admin_username = "azureuser"
        custom_data    = "${data.template_cloudinit_config.godevcloudconfig.rendered}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "${var.arm_sshkey}"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Web Page Counter"
    }

    depends_on = ["azurerm_virtual_machine.godev01vm"]

}