output "resource_group_name" {
    value = azurerm_resource_group.rg.name
}

output "ip_private" {
  value = azurerm_network_interface.nic_app.private_ip_address
}

output "public_ip_address_app" {
  value = "${azurerm_public_ip.public_ip_bastion.*.ip_address}"
}

output "public_ip_address_gateway" {
  value = "${azurerm_public_ip.public_ip_gateway.*.ip_address}"
}

output "password" {
  value = random_password.dbpassword.result
  sensitive = true
}

output "test" {
  value = azurerm_private_dns_zone.private_dns_mariadb.name
}

output arm_example_output {
  value = jsondecode(azurerm_resource_group_template_deployment.example.output_content)
}