resource "azurerm_subnet" "subnet_elastic" {
  name                 = "subnet_elastic"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.4.0.0/16"]
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