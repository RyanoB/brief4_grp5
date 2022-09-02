# Create ressource group.
resource "azurerm_resource_group" "rg" {
  name      = var.resource_group_name
  location  = var.resource_group_location
}

# Create virtual network
resource "azurerm_virtual_network" "network" {
  name                = var.network_name
  address_space       = var.network_address
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "subnet_gateway" {
  name                 = var.subnet_gateway_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = var.subnet_gateway_address
}

resource "azurerm_subnet" "subnet_app" {
  name                 = var.subnet_app_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = var.subnet_app_address
}

resource "azurerm_subnet" "subnet_bdd" {
  name                 = "subnet_bdd"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.3.0.0/16"]

  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"] # pour liaison sql et  compte de stockage
  private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet" "subnet_elastic" {
  name                 = "subnet_elastic"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.4.0.0/16"]
}

resource "azurerm_subnet" "subnet_bastion" {
  name = "subnet_bastion"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.6.0.0/16"]
}

resource "azurerm_public_ip" "public_ipapp" {
  name                = var.ip_app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "public_ipgateway" {
  name                = var.ip_gateway_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku = "Standard"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "myNetworkSecurityGroup"
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
}

# Create network interface for app
resource "azurerm_network_interface" "nic_bastion" {
  name                = "nic_bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "nic_bastion_config"
    subnet_id                     = azurerm_subnet.subnet_bastion.id
    private_ip_address_allocation = "Static"
    private_ip_address = "10.6.0.19"
    public_ip_address_id = azurerm_public_ip.public_ipapp.id
  }
}
# Create network interface for gateway
resource "azurerm_network_interface" "nic_app" {
  name                = "nic_app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "nic_app_config"
    subnet_id                     = azurerm_subnet.subnet_app.id
    private_ip_address = "10.2.0.19"
    private_ip_address_allocation = "Static"
  }
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.nic_bastion.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# SSH key
resource "azurerm_ssh_public_key" "ssh_nomad" {
  name                = "ssh_key_nomad"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  public_key          = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDAXuIAe8DVtQ+qHpbTnCMn5iP1u7WQEOLDE76PTRZ0lYc0TrWJvH+zWzpEbTK/fwzx5sw7yAlBnuR83cAOtm6y8Gk5yktOogsk71VnJ9cXKV7QWtX5o/nysqhliBWAW2jQmEMLHBf4DOFXcKpCdl0OBOtrPct976tnFXhM5n5WF0wrQ4dVikfWe57yg0BX+G+ZbNl7iDCHS8cAGEI2S0ziGOLjl0qJq+9jjCaj2bdVb5vtbz/ghplWtNKQvirxvfOC5H3XbX7aeH2sAlogeYbPs8DmFuz5Smq/+FLBZzqV7JhPMxBCpVFm6r+EzZDgiS2WB96Q3Jh0ItPz7wwJtgpLmSWeaBmWyPGAOh9MBal2RXgDIZ26EPOQTc9WX1377SaEMFSXgwq3e0mtFl5TYG+hzjujY9ik6nfjyLy1yNaPB7hq0z0cCijeJf0Nlm092Ukb1IJOndiS9LSZXjFJT+LRNz7hqyK/oj8nH4K2nx4DMH+Fj4JypSdsqmIk7aXLdYE= nomad@device"
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  byte_length = 8
}

#generation d'un random password pour database
#peut necessiter un terraform init -upgrade pour activer le random

resource "random_password" "dbpassword" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

#creation database
#https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mariadb_server


resource "azurerm_mariadb_server" "server_magento" {
  name = "magento-mariadb-server"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  administrator_login = "magento"
  administrator_login_password = "blablabla123!"

  sku_name = "MO_Gen5_2"
  storage_mb = 5120
  version = "10.2"

  auto_grow_enabled = true
  backup_retention_days = 14
  geo_redundant_backup_enabled = false
  public_network_access_enabled = true
  ssl_enforcement_enabled = false
}

resource "azurerm_mariadb_database" "db_magento" {
  name                = "mariadb_database"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mariadb_server.server_magento.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}

resource "azurerm_private_dns_zone" "private_dns_mariadb" {
  name                = "privatelink.mariadb.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_endpoint" "private_bdd" {
  name = "private_bdd"
  location = azurerm_resource_group.rg.location
  resource_group_name =azurerm_resource_group.rg.name
  subnet_id = azurerm_subnet.subnet_bdd.id

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_mariadb.id]
  }

  private_service_connection {
    name = "private_service_bdd"
    private_connection_resource_id = azurerm_mariadb_server.server_magento.id
    subresource_names = ["mariadbServer"]
    is_manual_connection = false
  }
}

# Link network with private link beacause need for link dns name with local ip
resource "azurerm_private_dns_zone_virtual_network_link" "link_bdd" {
  name                  = "link_bdd"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_mariadb.name
  virtual_network_id    = azurerm_virtual_network.network.id
}

#creation storage account
resource "azurerm_storage_account" "magento-storage" {
  name = "magentostorage"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  account_kind = "StorageV2"
  enable_https_traffic_only = false
  allow_nested_items_to_be_public = true
  is_hns_enabled = true
  nfsv3_enabled = true
  network_rules {
    default_action="Deny"
    virtual_network_subnet_ids = [azurerm_subnet.subnet_bdd.id]
  }
}
# Create network interface 2 pour elastic
resource "azurerm_network_interface" "nic_elasticsrh" {
  name                = "nic_elasticsrh"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "nic_elastic_config"
    subnet_id                     = azurerm_subnet.subnet_elastic.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create virtual machine for elastic search
resource "azurerm_linux_virtual_machine" "vmelasticsrh" {
  name                  = "vm_elasticsrh"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_elasticsrh.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "disk_elastic"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  custom_data = data.template_cloudinit_config.configelastic.rendered
  computer_name                   = "elastic"
  admin_username                  = "elastic"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "elastic"
    public_key = azurerm_ssh_public_key.ssh_nomad.public_key
  }
}

#rule VM autorization
resource "azurerm_mariadb_firewall_rule" "mdbrule" {
  name = "rule_magento_db"
  resource_group_name = azurerm_resource_group.rg.name
  server_name = azurerm_mariadb_server.server_magento.name

  start_ip_address = azurerm_public_ip.public_ipapp.ip_address
  end_ip_address = azurerm_public_ip.public_ipapp.ip_address
}

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
  custom_data = data.template_cloudinit_config.configbastion.rendered
  computer_name                   = "bastion"
  admin_username                  = "bastion"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "bastion"
    public_key = azurerm_ssh_public_key.ssh_nomad.public_key
  }
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
  name                  = "vm_app_test"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_app.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  custom_data = data.template_cloudinit_config.configapp.rendered
  computer_name                   = "magento"
  admin_username                  = "magento"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "magento"
    public_key = azurerm_ssh_public_key.ssh_nomad.public_key
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.magento-storage.primary_blob_endpoint
  }
}



#creation d'un gateway subnet
# resource "azurerm_subnet" "myterraformsubnetgateway" {
#   name                 = var.subnet_gateway_name
#   resource_group_name  = azurerm_resource_group.rg.name
#   virtual_network_name = azurerm_virtual_network.network.name
#   address_prefixes     = var.subnet_gateway_address
# }

#

#creation d'une gateway

locals {
  backend_address_pool_name      = "${azurerm_virtual_network.network.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.network.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.network.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.network.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.network.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.network.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.network.name}-rdrcfg"
}

resource "azurerm_application_gateway" "network_gateway" {
  name                = "example-appgateway"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.subnet_gateway.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.public_ipgateway.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

   request_routing_rule {
    name                       = var.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority = 100
  }


}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "poolbackend" {
  network_interface_id = azurerm_network_interface.nic_app.id
  ip_configuration_name = "nic_app_config"
  backend_address_pool_id = tolist(azurerm_application_gateway.network_gateway.backend_address_pool).0.id

}



