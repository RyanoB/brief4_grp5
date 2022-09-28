# CREATE RESOURCE GROUP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group

resource "azurerm_resource_group" "rg" {
  name      = var.resource_group_name
  location  = var.resource_group_location
}

# CREATE VIRTUAL NETWORK
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network

resource "azurerm_virtual_network" "network" {
  name                = var.network_name
  address_space       = var.network_address
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# CREATE SUBNET
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet

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
    service_endpoints    = ["Microsoft.Storage"] # pour liaison compte de stockage smb share
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

# CREATE IP ADDRESS
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip

resource "azurerm_public_ip" "public_ip_bastion" {
  name                = var.ip_bastion_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "public_ip_gateway" {
  name                = var.ip_gateway_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku = "Standard"
  domain_name_label = var.fqdn
}

# CREATE NETWORK SECURITY GROUP AND RULES
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group

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
}

resource "azurerm_network_security_group" "nsg_app" {
  name                = "nsg_app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "PING"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# CONNECT THE SECURITY GROUP TO THE NETWORK INTERFACE
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_security_group_association

resource "azurerm_network_interface_security_group_association" "assoc-nic-nsg-bastion" {
  network_interface_id      = azurerm_network_interface.nic_bastion.id
  network_security_group_id = azurerm_network_security_group.nsg_bastion.id
}

resource "azurerm_network_interface_security_group_association" "assoc-nic-nsg-app" {
  network_interface_id      = azurerm_network_interface.nic_app.id
  network_security_group_id = azurerm_network_security_group.nsg_app.id
}

# CREATE NETWORK INTERFACE FOR THE BASTION
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_application_security_group_association

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
}
# CREATE NETWORK INTERFACE FOR APP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_application_security_group_association

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

# CREATE KEY VAULT
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config

resource "azurerm_user_assigned_identity" "id-magento" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  name = "id-magento"
}

data "azurerm_client_config" "current" {}
data "azuread_user" "mybigq" {
  user_principal_name = "qbesse.ext@simplonformations.onmicrosoft.com"
}

data "azuread_user" "mybigstep" {
  user_principal_name = "sandriamarofahatra.ext@simplonformations.onmicrosoft.com"
}
data "azuread_user" "mybigr" {
  user_principal_name = "rboucheriha.ext@simplonformations.onmicrosoft.com"
}

resource "azurerm_key_vault" "keyvault" {
  name                        = "keyvaultmagento1"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "premium"

}

resource "azurerm_key_vault_access_policy" "admin" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_user.mybigq.object_id

   certificate_permissions = [
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "SetIssuers",
      "Update",
      "Purge",
    ]

    key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey",
      "Release",
      "Rotate",
      "GetRotationPolicy",
      "SetRotationPolicy",
    ]

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set",
    ]
}


resource "azurerm_key_vault_access_policy" "app" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.id-magento.principal_id

   certificate_permissions = [
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "SetIssuers",
      "Update",
      "Purge",
    ]

    key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey",
    ]

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set",
    ]
}

resource "azurerm_key_vault_access_policy" "mybigstep" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_user.mybigstep.object_id

   certificate_permissions = [
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "SetIssuers",
      "Update",
      "Purge",
    ]

    key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey",
      "Release",
      "Rotate",
      "GetRotationPolicy",
      "SetRotationPolicy",
    ]

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set",
    ]
}


resource "azurerm_key_vault_access_policy" "mybigr" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_user.mybigr.object_id

   certificate_permissions = [
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "SetIssuers",
      "Update",
      "Purge",
    ]

    key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey",
      "Release",
      "Rotate",
      "GetRotationPolicy",
      "SetRotationPolicy",
    ]

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set",
    ]
}

resource "azurerm_key_vault_certificate" "example" {
  name         = "key-magento-app2"
  key_vault_id = azurerm_key_vault.keyvault.id

  certificate {
    contents = filebase64("cert.pfx")
    password = ""
  }
}
# create an azure storage account
#https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account

resource "azurerm_storage_account" "storage-tls" {
  name                     = "statls"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# create a container within an azure storage account
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container

resource "azurerm_storage_container" "storage-container-tls" {
  name                  = "stacontainer"
  storage_account_name  = azurerm_storage_account.storage-tls.name
  container_access_type = "blob"
}

# create a blob within a storage container
#https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_blob

resource "azurerm_storage_blob" "blob_tls" {
  name                   = ".well-known/acme-challenge/test.txt"
  storage_account_name   = azurerm_storage_account.storage-tls.name
  storage_container_name = azurerm_storage_container.storage-container-tls.name
  type                   = "Block"
  source                 = "./test.txt"
}

#-------------------------STORAGE ACCOUNT SMB DOSSIER PARTAGE---------------------------
#STEP 1 OUVERTURE DU PORT 455 POUR LE PROTOCOLE SMB

resource "azurerm_network_security_rule" "nsg_inbound_2000" {
    name = "stnsg_inbound_2000"
    priority = 2000
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_address_prefix = "*"
    source_port_range = "*"
    destination_address_prefix = "*"
    destination_port_range = "445"
    resource_group_name = azurerm_resource_group.rg.name
    network_security_group_name = azurerm_network_security_group.nsg_app.name
}

#STEP 2 CREATION compte de stockage
#PARAMETRE = Par defaut est defini le protocole SMB

resource "azurerm_storage_account" "Storage_share01" {
  name = "stapp2"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  account_kind = "StorageV2"
  enable_https_traffic_only = false
  #allow_blob_public_access = true
  is_hns_enabled = true
}

#STEP 3 AUTORISATION règle d'association avec la VMAPP via son IP PUBLIQUE

resource "azurerm_storage_account_network_rules" "Storage_share01_association" {
  storage_account_id = azurerm_storage_account.Storage_share01.id

  default_action             = "Allow"
  ip_rules                   = ["${data.http.myip.response_body}"]
  virtual_network_subnet_ids = [azurerm_subnet.subnet_app.id]
}

#STEP 4 CREATION d'un FICHIER de partage PROTOCLE SMB (FILE SHARES)

resource "azurerm_storage_share" "smb_share" {
  name                 = "magentoshare01"
  storage_account_name = azurerm_storage_account.Storage_share01.name
  quota                = 5
  }

# SSH KEY
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/ssh_public_key

resource "azurerm_ssh_public_key" "ssh_nomad" {
  name                = "ssh_key_nomad"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  public_key          = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDAXuIAe8DVtQ+qHpbTnCMn5iP1u7WQEOLDE76PTRZ0lYc0TrWJvH+zWzpEbTK/fwzx5sw7yAlBnuR83cAOtm6y8Gk5yktOogsk71VnJ9cXKV7QWtX5o/nysqhliBWAW2jQmEMLHBf4DOFXcKpCdl0OBOtrPct976tnFXhM5n5WF0wrQ4dVikfWe57yg0BX+G+ZbNl7iDCHS8cAGEI2S0ziGOLjl0qJq+9jjCaj2bdVb5vtbz/ghplWtNKQvirxvfOC5H3XbX7aeH2sAlogeYbPs8DmFuz5Smq/+FLBZzqV7JhPMxBCpVFm6r+EzZDgiS2WB96Q3Jh0ItPz7wwJtgpLmSWeaBmWyPGAOh9MBal2RXgDIZ26EPOQTc9WX1377SaEMFSXgwq3e0mtFl5TYG+hzjujY9ik6nfjyLy1yNaPB7hq0z0cCijeJf0Nlm092Ukb1IJOndiS9LSZXjFJT+LRNz7hqyK/oj8nH4K2nx4DMH+Fj4JypSdsqmIk7aXLdYE= nomad@device"
}

# GENERATE RANDOM TEXT FOR A UNIQUE STORAGE ACCOUNT NAME
#https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id

resource "random_id" "randomId" {
  byte_length = 8
}

# GENERATION D'UN RANDOM PASSWORD POUR DATABASE
# PEU NECESSITER UN TERRAFORM INIT -UPGRADE POUR ACTIVER LE RANDOM
# https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password

resource "random_password" "dbpassword" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# CREATION DATABASE
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
# MANAGES A MARIADB DATABASE WITHIN MARIADB SERVER
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mariadb_database

resource "azurerm_mariadb_database" "db_magento" {
  name                = "mariadb_database"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mariadb_server.server_magento.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}

# CREATE PRIVATE DNS ZONE

resource "azurerm_private_dns_zone" "private_dns_mariadb" {
  name                = "privatelink.mariadb.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# CREATION D'UN ENDPOINT POUR OBTENIR MARIADB DANS MON RESEAU LOCAL
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint

# Creation d'un endpoint pour obtenir mariadb dans mon réseau local
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
    subresource_names = ["mariadbServer"] # subresource = type de ressources
    is_manual_connection = false
  }
}

# lINK NETWORK WITH PRIVATE LINK BECAUSE NEED FOR LINK DNS NAME WITH LOCAL IP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link

resource "azurerm_private_dns_zone_virtual_network_link" "link_bdd" {
  name                  = "link_bdd"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_mariadb.name
  virtual_network_id    = azurerm_virtual_network.network.id
}

# CREATE STORAGE ACCOUNT FOR BDD
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account

resource "azurerm_storage_account" "storage-bdd" {
  name = "stabdd"
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

# CREATION NIC POUR ELASTICSEARCH
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface

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

# CREATION D'UNE MACHINE VIRTUELLE POUR ELASTIC SEARCH
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine

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


# REGLES FIREWALL QUI AUTORISE LA PLAGE RESEAU QUI COMMUNIQUE AVEC MARIADB
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mariadb_firewall_rule

resource "azurerm_mariadb_firewall_rule" "mdbrule" {
  name = "rule_magento_db"
  resource_group_name = azurerm_resource_group.rg.name
  server_name = azurerm_mariadb_server.server_magento.name

  start_ip_address = azurerm_public_ip.public_ip_bastion.ip_address
  end_ip_address = azurerm_public_ip.public_ip_bastion.ip_address
}

# CREATION D UNE VM BASTION
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine

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
}

# CREATION D UNE VM APP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine


resource "azurerm_linux_virtual_machine_scale_set" "example" {
  name                = "vmsapptest"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_DS1_v2"
  instances           = 1

  # GENERER LE FICHIER YAML CLOUD-INIT POUR CONFIGURATION DE LA VM BASTION
  # https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config

  custom_data = data.template_cloudinit_config.configapp.rendered
  admin_username                  = "magento"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "magento"
    public_key = azurerm_ssh_public_key.ssh_nomad.public_key
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  network_interface {
    name    = "example"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.subnet_app.id
      application_gateway_backend_address_pool_ids = [tolist(azurerm_application_gateway.network_gateway.backend_address_pool).0.id]
    }
  }
}

resource "azurerm_monitor_autoscale_setting" "example" {
  name                = "myAutoscaleSetting"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.example.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.example.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 15
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"

      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown = "PT20M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.example.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT15M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
      custom_emails                         = ["admin@contoso.com"]
    }
  }
}

# creation d'un gateway subnet
# resource "azurerm_subnet" "myterraformsubnetgateway" {
#   name                 = var.subnet_gateway_name
#   resource_group_name  = azurerm_resource_group.rg.name
#   virtual_network_name = azurerm_virtual_network.network.name
#   address_prefixes     = var.subnet_gateway_address
# }



# AZURE APPLICATION GATEWAY
# STEP 1 - INITIATIONS DES VARIABLES
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway

locals {
  backend_address_pool_name      = "${azurerm_virtual_network.network.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.network.name}-feport"
  frontend_port_name2            = "${azurerm_virtual_network.network.name}-feport2"
  frontend_ip_configuration_name = "${azurerm_virtual_network.network.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.network.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.network.name}-httplstn"
  listener_name2                  = "${azurerm_virtual_network.network.name}-httplstn2"
  listener_name3                  = "${azurerm_virtual_network.network.name}-httplstn3"
  request_routing_rule_name      = "${azurerm_virtual_network.network.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.network.name}-rdrcfg"
}

# STEP 2 - CREATION DE LA RESSOURCE AZURE APPLICATION GATEWAY
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway

resource "azurerm_application_gateway" "network_gateway" {
  name                = "gateway-brief4"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "Standard_v2" # format obligatoire
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
  frontend_port {
    name = local.frontend_port_name2
    port = 443 # tcp
  }
  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.public_ip_gateway.id
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
    priority = 200
  }

  ssl_certificate {
    name = "tls_cert"
    key_vault_secret_id = azurerm_key_vault_certificate.example.secret_id
  }

  http_listener {
    name                           = local.listener_name2
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name2
    protocol                       = "Https"
    ssl_certificate_name = "tls_cert"
  }


  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.id-magento.id]
  }
   request_routing_rule {
     name               = "tls-rule"
      rule_type          = "PathBasedRouting"
      http_listener_name = local.listener_name2
      url_path_map_name  = "test"
      priority = 100
    }

    redirect_configuration {
      name          = "LetsEncryptChallenge"
      redirect_type = "Permanent"
      target_url    = "https://statls.blob.core.windows.net/stacontainer/.well-known/acme-challenge/"
    }

    url_path_map {
      name                               = "test"
      default_backend_address_pool_name  = local.backend_address_pool_name
      default_backend_http_settings_name = local.http_setting_name

      path_rule {
        name                        = "letsencrypt"
        paths                       = ["/.well-known/acme-challenge/*"]
        redirect_configuration_name = "LetsEncryptChallenge"
      }
    }

}




# MONITORING
# AZURE APPLICATION INSIGHT (MESURE DE PERFORMANCE DE L'APPLICATION)
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights

resource "azurerm_application_insights" "insight" {
  name                = "insights-magento"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"

}
# STEP 1 CREATION D'UN COMPTE DE STOCKAGE
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
resource "azurerm_storage_account" "storage-monitor" {
  name                     = "stamonitor"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
# STEP 2 CREATION DU GROUPE QUI SERA MONITORER
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_action_group

resource "azurerm_monitor_action_group" "group-monitor" {
  name                = "group-monitor"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "monitor-grp"

   email_receiver {
    name          = "sendtoadmin"
    email_address = "ryanomagento@gmail.com"
  }
}

# MISE EN PLACE DE L'ALERTE POUR LA VM "BDD"
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_metric_alert

resource "azurerm_monitor_metric_alert" "alert-stock" {
  name                = "alert-stock-capacity"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_storage_account.storage-bdd.id]
  description         = "Space alert"
  target_resource_type = "Microsoft.Storage/storageAccounts"
  frequency = "PT1H"
  window_size = "PT12H"

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "UsedCapacity"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 450000
  }

  action {
    action_group_id = azurerm_monitor_action_group.group-monitor.id
  }
}


resource "azurerm_application_insights_web_test" "example" {
  name                    = "tf-test-appinsights-webtest"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  application_insights_id = azurerm_application_insights.insight.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 60
  enabled                 = true
  geo_locations           = ["us-tx-sn1-azr", "us-il-ch1-azr"]

  configuration = <<XML
<WebTest Name="WebTest1" Id="ABD48585-0831-40CB-9069-682EA6BB3583" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="0" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">
  <Items>
    <Request Method="GET" Guid="a5f10126-e4cd-570d-961c-cea43999a200" Version="1.1" Url="http://microsoft.com" ThinkTime="0" Timeout="300" ParseDependentRequests="True" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
XML

}


# CREATION D'UNE RESSOURCE QUI GENERE UN TEMPLATE AU FORMAT JSON
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/template_deployment

resource "azurerm_resource_group_template_deployment" "example" {
  name                = "arm-deploy"
  resource_group_name = azurerm_resource_group.rg.name
  deployment_mode     = "Incremental"

  template_content = <<DEPLOY
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "webtests_requesthttp_insights_app_name": {
            "defaultValue": "requesthttp-insights-app",
            "type": "String"
        }
    },
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Insights/webtests",
            "apiVersion": "2022-06-15",
            "name": "[parameters('webtests_requesthttp_insights_app_name')]",
            "location": "eastus2",
            "tags": {
                "hidden-link:${azurerm_application_insights.insight.id}": "Resource"
            },
            "properties": {
                "SyntheticMonitorId": "[parameters('webtests_requesthttp_insights_app_name')]",
                "Name": "requesthttp",
                "Enabled": true,
                "Frequency": 300,
                "Timeout": 120,
                "Kind": "standard",
                "RetryEnabled": true,
                "Locations": [
                    {
                        "Id": "us-va-ash-azr"
                    },
                    {
                        "Id": "us-ca-sjc-azr"
                    },
                    {
                        "Id": "us-fl-mia-edge"
                    },
                    {
                        "Id": "apac-sg-sin-azr"
                    },
                    {
                        "Id": "emea-ru-msa-edge"
                    }
                ],
                "Request": {
                    "RequestUrl": "https://${var.fqdn}.${var.resource_group_location}.cloudapp.azure.com",
                    "HttpVerb": "GET",
                    "ParseDependentRequests": false
                },
                "ValidationRules": {
                    "ExpectedHttpStatusCode": 200,
                    "SSLCheck": false
                }
            }
        }
    ]
}
DEPLOY
}



resource "azurerm_monitor_metric_alert" "alert-availability" {
  name                = "alert-availability"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_application_insights.insight.id]
  description         = "Availability"

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "availabilityResults/availabilityPercentage"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
    dimension {
      name="availabilityResult/name"
      operator = "Include"
      values=["requesthttp"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.group-monitor.id
  }
}




# -----------------------------BACKUP POUR STORAGE SHARES FILE------------------------------------------------
# CHECK des Prérequis du FILE SHARE ci-dessous :
# region eastus OK, account kind en General purpose ok, Standard OK, firewall allowed ok, smb ok (BACKUP STORAGE ne supporte pas nfs)

# STEP1 : CREATION D'UN RECOVERY VAULT

resource "azurerm_recovery_services_vault" "magento-rsvault" {
  name                = "magento-recovery-vault"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}

# STEP4 :CREATION D'UN BACKUP CONTAINER

resource "azurerm_backup_container_storage_account" "protection-container01" {
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.magento-rsvault.name
  storage_account_id  = azurerm_storage_account.Storage_share01.id
}

# STEP3 : CREATION d'un BACKUP POLICY + CONFIGURATION DES PARAMETRES
resource "azurerm_backup_policy_file_share" "magentopolicy01" {
  name                = "recovery-vault-magentopolicy012"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.magento-rsvault.name

  timezone = "UTC"

  backup {
    frequency = "Daily"
    time      = "14:00"
  }

  retention_daily {
    count = 14
  }
}
# STEP4 : LIAISON DES RESSOURCES ET MISE EN PLACE
# NB : " effet de bord " => Force la mise en place d'un AZUREPROTECTIONLOCK (LOCK) du compte de stockage. seul le Owners peut supprimer.
resource "azurerm_backup_protected_file_share" "share1" {
  resource_group_name       = azurerm_resource_group.rg.name
  recovery_vault_name       = azurerm_recovery_services_vault.magento-rsvault.name
  source_storage_account_id = azurerm_backup_container_storage_account.protection-container01.storage_account_id
  source_file_share_name    = azurerm_storage_share.smb_share.name
  backup_policy_id          = azurerm_backup_policy_file_share.magentopolicy01.id
}

#------------------------------FIN BACKUP STORAGE SHARES FILE-------------------------------------
