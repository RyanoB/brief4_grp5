
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


# GENERATE RANDOM TEXT FOR A UNIQUE STORAGE ACCOUNT NAME
#https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id

resource "random_id" "randomId" {
  byte_length = 8
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
  name                = "recovery-vault-magentopolicy01"
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

