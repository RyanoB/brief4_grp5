output "resource_group_name" {
    value = azurerm_resource_group.rg.name
}

output "ip_private" {
  value = azurerm_network_interface.myterraformnic.private_ip_address
}

output "public_ip_address_app" {
  value = "${azurerm_public_ip.myterraformpublicipapp.*.ip_address}"
}

output "public_ip_address_gateway" {
  value = "${azurerm_public_ip.myterraformpublicipgateway.*.ip_address}"
}