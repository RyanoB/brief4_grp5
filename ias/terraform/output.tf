output "resource_group_name" {
    value = azurerm_resource_group.rg.name
}

output "ip_private" {
  value = azurerm_network_interface.nic_app.private_ip_address
}

output "public_ip_address_app" {
  value = "${azurerm_public_ip.public_ipapp.*.ip_address}"
}

output "public_ip_address_gateway" {
  value = "${azurerm_public_ip.public_ipgateway.*.ip_address}"
}

output "password" {
  value = random_password.dbpassword.result
  sensitive = true
}