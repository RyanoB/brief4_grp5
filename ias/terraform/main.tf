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

# Create Network Security Group and rule
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

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "assoc-nic-nsg-bastion" {
  network_interface_id      = azurerm_network_interface.nic_bastion.id
  network_security_group_id = azurerm_network_security_group.nsg_bastion.id
}

resource "azurerm_network_interface_security_group_association" "assoc-nic-nsg-app" {
  network_interface_id      = azurerm_network_interface.nic_app.id
  network_security_group_id = azurerm_network_security_group.nsg_app.id
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
    public_ip_address_id = azurerm_public_ip.public_ip_bastion.id
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

// Key Vault
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "keyvault" {
  name                        = "keyvaultmagento"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
  }
}

resource "azurerm_storage_account" "storage-tls" {
  name                     = "statls"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "storage-container-tls" {
  name                  = "stacontainer"
  storage_account_name  = azurerm_storage_account.storage-tls.name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "blob_tls" {
  name                   = ".well-known/acme-challenge/test.txt"
  storage_account_name   = azurerm_storage_account.storage-tls.name
  storage_container_name = azurerm_storage_container.storage-container-tls.name
  type                   = "Block"
  source                 = "./test.txt"
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

# Link network with private link because need for link dns name with local ip
resource "azurerm_private_dns_zone_virtual_network_link" "link_bdd" {
  name                  = "link_bdd"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_mariadb.name
  virtual_network_id    = azurerm_virtual_network.network.id
}

#creation storage account
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

  start_ip_address = azurerm_public_ip.public_ip_bastion.ip_address
  end_ip_address = azurerm_public_ip.public_ip_bastion.ip_address
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
resource "azurerm_linux_virtual_machine" "vm_app" {
  name                  = "vm_app"
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
  frontend_port_name2            = "${azurerm_virtual_network.network.name}-feport2"
  frontend_ip_configuration_name = "${azurerm_virtual_network.network.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.network.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.network.name}-httplstn"
  listener_name2                  = "${azurerm_virtual_network.network.name}-httplstn2"
  request_routing_rule_name      = "${azurerm_virtual_network.network.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.network.name}-rdrcfg"
}

resource "azurerm_application_gateway" "network_gateway" {
  name                = "gateway-brief4"
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
  frontend_port {
    name = local.frontend_port_name2
    port = 443
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
  # http_listener {
  #   name                           = local.listener_name2
  #   frontend_ip_configuration_name = local.frontend_ip_configuration_name
  #   frontend_port_name             = local.frontend_port_name2
  #   protocol                       = "Https"
  # }
   request_routing_rule {
    name                       = var.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority = 100
  }
  # request_routing_rule {
  #   name               = "tls-rule"
  #   rule_type          = "PathBasedRouting"
  #   http_listener_name = local.listener_name2
  #   url_path_map_name  = "test"
  #   priority = 200
  # }

  # redirect_configuration {
  #   name          = "LetsEncryptChallenge"
  #   redirect_type = "Permanent"
  #   target_url    = "http://stockagetls.blob.core.windows.net/containertls//.well-known/acme-challenge/"
  # }

  # url_path_map {
  #   name                               = "test"
  #   default_backend_address_pool_name  = local.backend_address_pool_name
  #   default_backend_http_settings_name = local.http_setting_name

  #   path_rule {
  #     name                        = "letsencrypt"
  #     paths                       = ["/.well-known/acme-challenge/*"]
  #     redirect_configuration_name = "LetsEncryptChallenge"
  #   }
  # }

}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "poolbackend" {
  network_interface_id = azurerm_network_interface.nic_app.id
  ip_configuration_name = "nic_app_config"
  backend_address_pool_id = tolist(azurerm_application_gateway.network_gateway.backend_address_pool).0.id

}



// Monitoring
resource "azurerm_storage_account" "storage-monitor" {
  name                     = "stamonitor"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_monitor_action_group" "group-monitor" {
  name                = "group-monitor"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "monitor-grp"
}

resource "azurerm_monitor_metric_alert" "alert-vm-cpu" {
  name                = "alert-vm-cpu"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.vm_app.id]
  description         = "VM App cpu alert"
  target_resource_type = "Microsoft.Compute/virtualMachines"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 90
  }

  action {
    action_group_id = azurerm_monitor_action_group.group-monitor.id
  }
}

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

resource "azurerm_application_insights" "insight" {
  name                = "insights-magento"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"

}

resource "azurerm_template_deployment" "example" {
  name                = "acctesttemplate-01"
  resource_group_name = azurerm_resource_group.rg.name

  template_body = <<DEPLOY
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
            "type": "microsoft.insights/webtests",
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
                    "RequestUrl": "http://${var.fqdn}.${var.resource_group_location}.cloudapp.azure.com",
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

  deployment_mode = "Incremental"
}


variable private_key_size {
    default = 4096
}
variable private_key_algorithim {
    default = "RSA"
}
resource tls_private_key ca_key {
   algorithm = var.private_key_algorithim
   rsa_bits  = var.private_key_size
}


resource tls_self_signed_cert ca_cert {
   private_key_pem = tls_private_key.ca_key.private_key_pem
   key_algorithm = "RSA"
   subject {
     common_name         = var.common_name
     organization        = var.issuer_organization.organization
     organizational_unit = var.issuer_organization.organizational_unit
     street_address      = var.issuer_organization.street_address
     locality            = var.issuer_organization.locality
     province            = var.issuer_organization.province
     country             = var.issuer_organization.country
     postal_code         = var.issuer_organization.postal_code

   }
   # 175200 = 20 years
   validity_period_hours = 175200
   allowed_uses = [
     "cert_signing",
     "crl_signing"
   ]
   is_ca_certificate = true

}
resource local_file private_key {
    sensitive_content = tls_private_key.ca_key.private_key_pem
    filename = "./privKey.pem"
    file_permission = "0600"
}
resource local_file ca_file {
    sensitive_content = tls_self_signed_cert.ca_cert.cert_pem
    filename = "./cert.pem"
    file_permission = "0600"
}

resource azurerm_key_vault_certificate ca_cert {
  name          = var.service_settings.cert_name
  key_vault_id  = var.service_settings.key_vault_resource_id

  certificate {
    contents = "${tls_private_key.ca_key.private_key_pem}${tls_self_signed_cert.ca_cert.cert_pem}"
    #contents = file("./secrets/test.pem")
    password = ""
  }
  certificate_policy {
    key_properties {
      exportable = "true"
      key_size   = var.private_key_size
      key_type   = var.private_key_algorithim
      reuse_key  = "true"
    }
    issuer_parameters {
      name = "Self"
    }
    secret_properties {
      content_type = "application/x-pem-file"
    }
  }



}