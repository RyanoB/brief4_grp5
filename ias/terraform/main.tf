# CREATE RESOURCE GROUP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group

resource "azurerm_resource_group" "rg" {
  name      = var.resource_group_name
  location  = var.resource_group_location
}


/*
resource "azurerm_network_security_group" "nsg_bastion" {
  name                = "nsg_bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name


  security_rule {
    # Ingress traffic from Internet on 443 is enabled
    name                       = "AllowIB_HTTPS443_Internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    # Ingress traffic for control plane activity that is GatewayManger to be able to talk to Azure Bastion
    name                       = "AllowIB_TCP443_GatewayManager"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    # Ingress traffic for health probes, enabled AzureLB to detect connectivity
    name                       = "AllowIB_TCP443_AzureLoadBalancer"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  security_rule {
    # Ingress traffic for data plane activity that is VirtualNetwork service tag
    name                       = "AllowIB_BastionHost_Commn8080"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    # Deny all other Ingress traffic
    name                       = "DenyIB_any_other_traffic"
    priority                   = 900
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # * * * * * * OUT-BOUND Traffic * * * * * * #

  # Egress traffic to the target VM subnets over ports 3389 and 22
  security_rule {
    name                       = "AllowOB_SSHRDP_VirtualNetwork"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["3389", "22"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
  # Egress traffic to AzureCloud over 443
  security_rule {
    name                       = "AllowOB_AzureCloud"
    priority                   = 105
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
  # Egress traffic for data plane communication between the Bastion and VNets service tags
  security_rule {
    name                       = "AllowOB_BastionHost_Comn"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Egress traffic for SessionInformation
  security_rule {
    name                       = "AllowOB_GetSessionInformation"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

# Associate the NSG to the AZBastionHost Subnet
resource "azurerm_subnet_network_security_group_association" "azbsubnet-and-nsg-association" {
  network_security_group_id = azurerm_network_security_group.nsg_bastion.id
  subnet_id                 = azurerm_subnet.subnet_bastion.id
}
# CREATE IP ADDRESS
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip



# CREATE NETWORK SECURITY GROUP AND RULES
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group
/*
resource "azurerm_network_security_group" "nsg_bastion" {
  name                = "nsg_bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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
}*/



# CONNECT THE SECURITY GROUP TO THE NETWORK INTERFACE
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_security_group_association
/*
resource "azurerm_network_interface_security_group_association" "assoc-nic-nsg-bastion" {
  network_interface_id      = azurerm_network_interface.nic_bastion.id
  network_security_group_id = azurerm_network_security_group.nsg_bastion.id
}*/

# CREATE NETWORK INTERFACE FOR THE BASTION
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_application_security_group_association
/*
resource "azurerm_network_interface" "nic_bastion" {
  name                = "nic_bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "nic_bastion_config"
    subnet_id                     = azurerm_subnet.subnet_bastion.id
    private_ip_address_allocation = "Static"
    private_ip_address = "10.6.0.19"
    public_ip_address_id = azurerm_public_ip.public_ip_bastion.id
  }
}*/
# SSH KEY
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/ssh_public_key

resource "azurerm_ssh_public_key" "ssh_nomad" {
  name                = "ssh_key_nomad"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  public_key          = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDAXuIAe8DVtQ+qHpbTnCMn5iP1u7WQEOLDE76PTRZ0lYc0TrWJvH+zWzpEbTK/fwzx5sw7yAlBnuR83cAOtm6y8Gk5yktOogsk71VnJ9cXKV7QWtX5o/nysqhliBWAW2jQmEMLHBf4DOFXcKpCdl0OBOtrPct976tnFXhM5n5WF0wrQ4dVikfWe57yg0BX+G+ZbNl7iDCHS8cAGEI2S0ziGOLjl0qJq+9jjCaj2bdVb5vtbz/ghplWtNKQvirxvfOC5H3XbX7aeH2sAlogeYbPs8DmFuz5Smq/+FLBZzqV7JhPMxBCpVFm6r+EzZDgiS2WB96Q3Jh0ItPz7wwJtgpLmSWeaBmWyPGAOh9MBal2RXgDIZ26EPOQTc9WX1377SaEMFSXgwq3e0mtFl5TYG+hzjujY9ik6nfjyLy1yNaPB7hq0z0cCijeJf0Nlm092Ukb1IJOndiS9LSZXjFJT+LRNz7hqyK/oj8nH4K2nx4DMH+Fj4JypSdsqmIk7aXLdYE= nomad@device"
}


/*
resource "azurerm_linux_virtual_machine" "vm_bastion" {
  name = "vm_bastion"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_bastion.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "disk_bastion"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

# GENERER LE FICHIER YAML CLOUD-INIT POUR CONFIGURATION DE LA VM BASTION
# https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config

  custom_data = data.template_cloudinit_config.configbastion.rendered
  computer_name                   = "bastion"
  admin_username                  = "bastion"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "bastion"
    public_key = azurerm_ssh_public_key.ssh_nomad.public_key
  }
}*/


# CREATION D UNE VM APP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
/*
resource "azurerm_linux_virtual_machine" "vm_app" {
  name                  = "vm_apptest"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_app.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "disk_app"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

# GENERER LE FICHIER YAML CLOUD-INIT POUR CONFIGURATION DE LA VM BASTION
# https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config

  custom_data = data.template_cloudinit_config.configapp.rendered
  computer_name                   = "magento"
  admin_username                  = "magento"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "magento"
    public_key = azurerm_ssh_public_key.ssh_nomad.public_key
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage-bdd.primary_blob_endpoint
  }
}
*/

# creation d'un gateway subnet
# resource "azurerm_subnet" "myterraformsubnetgateway" {
#   name                 = var.subnet_gateway_name
#   resource_group_name  = azurerm_resource_group.rg.name
#   virtual_network_name = azurerm_virtual_network.network.name
#   address_prefixes     = var.subnet_gateway_address
# }





