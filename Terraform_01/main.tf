

#creation d'un resource group
resource "azurerm_resource_group" "labste" {
  name      = "${var.prefix}-rg"
  location  = var.resource_group_location
}

#creation d'un Vnet
resource "azurerm_virtual_network" "vnet" {
    name="${var.prefix}-vnet"
    resource_group_name = azurerm_resource_group.labste.name
    location = azurerm_resource_group.labste.location
    address_space = ["10.0.0.0/16"]
}

#creation subnet pour VM
resource "azurerm_subnet" "subnet01" {
    name="${var.prefix}-subnet01"
    virtual_network_name = azurerm_virtual_network.vnet.name
    resource_group_name = azurerm_resource_group.labste.name
    address_prefixes = ["10.0.1.0/24"]
    service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"] # pour liaison sql et  compte de stockage 
}

#creation IP pub VM
resource "azurerm_public_ip" "pipvm01" {
    name = "${var.prefix}-pipvm01"
    resource_group_name = azurerm_resource_group.labste.name
    location = azurerm_resource_group.labste.location
    allocation_method = "Dynamic"
    domain_name_label = "${var.prefix}-magento"  
}

#creation interface reseau
resource "azurerm_network_interface" "main" {
    name = "${var.prefix}-nic01"
    resource_group_name = azurerm_resource_group.labste.name
    location = azurerm_resource_group.labste.location

    ip_configuration {
        
      name = "maitre"
      subnet_id = azurerm_subnet.subnet01.id
      private_ip_address_allocation = "Dynamic"
      public_ip_address_id = azurerm_public_ip.pipvm01.id
      
    }
}
#creation du nsg 
resource "azurerm_network_security_group" "magentonsg" {
  name = "${var.prefix}-nsg01"
  location = azurerm_resource_group.labste.location
  resource_group_name = azurerm_resource_group.labste.name
}

#association de la NSG avec le subnet
resource "azurerm_subnet_network_security_group_association" "subnet-nsg-association" {
    subnet_id = azurerm_subnet.subnet01.id
   network_security_group_id = azurerm_network_security_group.magentonsg.id
   depends_on = [azurerm_network_security_rule.nsg_inbound_100]

}

# resource Rules list nsg
resource "azurerm_network_security_rule" "nsg_inbound_100" {
    name = "${var.prefix}-vm01"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_address_prefix = "*"
    source_port_range = "*"
    destination_address_prefix = "*"
    destination_port_range = "22"
    resource_group_name = azurerm_resource_group.labste.name
    network_security_group_name = azurerm_network_security_group.magentonsg.name
  
}

#creation d'une VM LINUX

resource "azurerm_linux_virtual_machine" "main" {
    name = "${var.prefix}-vm01"
    resource_group_name = azurerm_resource_group.labste.name
    location = azurerm_resource_group.labste.location
    size = "Standard_F2"
    admin_username = var.admin_name
    network_interface_ids = [
        azurerm_network_interface.main.id
     ]

    admin_ssh_key {
    username = var.admin_name
    public_key = file("C:/Users/utilisateur/.ssh/id_rsa.pub")
    }
    
    source_image_reference {
      publisher = "Canonical"
      offer = "UbuntuServer"
      sku = "16.04-LTS"
      version = "latest"
    }

    os_disk {
      storage_account_type = "Standard_LRS"
      caching = "ReadWrite"
    }
}

#creation storage account
resource "azurerm_storage_account" "labstestorage" {
  name = "${var.prefix}storage"
  resource_group_name = azurerm_resource_group.labste.name
  location = azurerm_resource_group.labste.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  account_kind = "StorageV2"
  enable_https_traffic_only = false
  allow_blob_public_access = true
  is_hns_enabled = true
  nfsv3_enabled = true
  network_rules {
    default_action="Deny"
    virtual_network_subnet_ids = [azurerm_subnet.subnet01.id]
    
  }

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


resource "azurerm_mariadb_server" "labstemariadb" {
  name = "${var.prefix}-mariadb-server"
  location = azurerm_resource_group.labste.location
  resource_group_name = azurerm_resource_group.labste.name
  administrator_login = "${var.admin_name}-mariadb"
  administrator_login_password = random_password.dbpassword.result

  sku_name = "B_Gen5_2"
  storage_mb = 5120
  version = "10.2"

  auto_grow_enabled = true
  backup_retention_days = 14
  geo_redundant_backup_enabled = false
  public_network_access_enabled = true
  ssl_enforcement_enabled = true  
}

#rule VM autorization
resource "azurerm_mariadb_firewall_rule" "mdbrule" {
  name = "${var.prefix}-mariadb-vnet-rule"
  resource_group_name = azurerm_resource_group.labste.name
  server_name = azurerm_mariadb_server.labstemariadb.name
  start_ip_address = "10.0.1.0"
  end_ip_address = "10.0.1.255"
}



#creation subnet pour gateway
resource "azurerm_subnet" "subnet02" {
    name="${var.prefix}-subnet02"
    virtual_network_name = azurerm_virtual_network.vnet.name
    resource_group_name = azurerm_resource_group.labste.name
    address_prefixes = ["10.0.2.0/24"]
}

