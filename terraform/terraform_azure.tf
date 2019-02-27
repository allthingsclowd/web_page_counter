
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

# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "${var.arm_subscription_id}"
    client_id       = "${var.arm_client_id}"
    client_secret   = "${var.arm_client_secret}"
    tenant_id       = "${var.arm_tenant_id}"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "webpagecounter" {
    name     = "graham-dev"
    location = "westeurope"

    tags {
        environment = "Web Page Counter"
    }
    
    lifecycle {
    prevent_destroy = true
    }
}

# Create virtual network
resource "azurerm_virtual_network" "webpagecounternetwork" {
    name                = "wpcVnet"
    address_space       = ["192.168.0.0/16"]
    location            = "westeurope"
    resource_group_name = "${azurerm_resource_group.webpagecounter.name}"

    tags {
        environment = "Web Page Counter"
    }
}

# Create subnet
resource "azurerm_subnet" "webpagecountersubnet" {
    name                 = "wpcSubnet"
    resource_group_name  = "${azurerm_resource_group.webpagecounter.name}"
    virtual_network_name = "${azurerm_virtual_network.webpagecounternetwork.name}"
    address_prefix       = "192.168.2.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "wpcPublicIP"
    location                     = "westeurope"
    resource_group_name          = "${azurerm_resource_group.webpagecounter.name}"
    allocation_method            = "Dynamic"

    tags {
        environment = "Web Page Counter"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "wpcnsg" {
    name                = "wpcNetworkSecurityGroup"
    location            = "westeurope"
    resource_group_name = "${azurerm_resource_group.webpagecounter.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags {
        environment = "Web Page Counter"
    }
}

# Create network interface
resource "azurerm_network_interface" "wpcnic" {
    name                      = "wpcNIC"
    location                  = "westeurope"
    resource_group_name       = "${azurerm_resource_group.webpagecounter.name}"
    network_security_group_id = "${azurerm_network_security_group.wpcnsg.id}"

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

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.webpagecounter.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.webpagecounter.name}"
    location                    = "westeurope"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        environment = "Web Page Counter"
    }
}

# Create cloud-init config
data "template_file" "cloudconfig" {
    
  template = "${file("../scripts/leader_cloud_config.txt")}"
}

#https://www.terraform.io/docs/providers/template/d/cloudinit_config.html
data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    content = "${data.template_file.cloudconfig.rendered}"
  }
}


# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
    name                  = "leader01"
    location              = "westeurope"
    resource_group_name   = "${azurerm_resource_group.webpagecounter.name}"
    network_interface_ids = ["${azurerm_network_interface.wpcnic.id}"]
    vm_size               = "Standard_DS1_v2"

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
        custom_data    = "${data.template_cloudinit_config.config.rendered}"
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
