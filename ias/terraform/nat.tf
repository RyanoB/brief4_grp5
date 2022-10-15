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
# Axe amélioration: réduire le nombre de sous réseau pour

# Sous réseau de la gateway.
# Obligatoire pour la gateway.
resource "azurerm_subnet" "subnet_gateway" {
  name                 = var.subnet_gateway_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = var.subnet_gateway_address
}

resource "azurerm_public_ip" "public_ip_gateway" {
  name                = var.ip_gateway_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku = "Standard"
  domain_name_label = var.fqdn
}


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

  probe {
    name = "probetest"
    host = "magentobrief4.eastus2.cloudapp.azure.com"
    protocol = "Http"
    path = "/customer/account/create/"
    interval = "30"
    timeout = "30"
    unhealthy_threshold = "3"
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

