resource "azurerm_subnet" "subnet_bdd" {
  name                 = "subnet_bdd"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.3.0.0/16"]

  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"] # pour liaison sql et  compte de stockage
  private_endpoint_network_policies_enabled = true
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




# REGLES FIREWALL QUI AUTORISE LA PLAGE RESEAU QUI COMMUNIQUE AVEC MARIADB
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mariadb_firewall_rule

resource "azurerm_mariadb_firewall_rule" "mdbrule" {
  name = "rule_magento_db"
  resource_group_name = azurerm_resource_group.rg.name
  server_name = azurerm_mariadb_server.server_magento.name

  start_ip_address = azurerm_public_ip.public_ip_bastion.ip_address
  end_ip_address = azurerm_public_ip.public_ip_bastion.ip_address
}

