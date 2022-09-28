variable "resource_group_name" {
  default = "brief4_QB_2"
  description   = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "resource_group_location" {
  default = "eastus2"
  description   = "Location of the resource group."
}

variable "fqdn" {
  default = "magentobrief4"
}
variable "network_name" {
    default = "network"
    description = "Name of network."
}

variable "network_address" {
    default = ["10.0.0.0/8"]
    description = "Network address"
}

variable "subnet_gateway_name" {
    default = "subnet_gateway"
}

variable "subnet_gateway_address" {
    default = ["10.1.0.0/16"]
    description = "Subnet gateway"
}

variable "subnet_app_name" {
    default = "subnet_app"
}

variable "subnet_app_address" {
    default = ["10.2.0.0/16"]
}

variable "ip_gateway_name" {
    default = "ip_gateway"
}

variable "ip_bastion_name" {
    default = "ip_bastion"
}

# Render a part using a `template_file`
data "template_file" "scriptapp" {
  template = "${file("${path.module}/../cloud-init/cloud-init-app.yaml")}"

  vars = {
    ip_bdd = azurerm_private_endpoint.private_bdd.private_service_connection.0.private_ip_address
    ip_public = azurerm_public_ip.public_ip_gateway.ip_address
    password = azurerm_storage_account.Storage_share01.primary_access_key
    fqdn_app = "${var.fqdn}.${var.resource_group_location}.cloudapp.azure.com"
  }
}
data "template_file" "scriptelastic" {
  template = "${file("${path.module}/../cloud-init/cloud-init-elastic.yaml")}"
}
data "template_cloudinit_config" "configapp" {
  gzip          = true
  base64_encode = true


  # Main cloud-config configuration file.
  part {
    filename     = "../cloud-init/cloud-init-app.yaml"
    content_type = "text/cloud-config"
    content      = "${data.template_file.scriptapp.rendered}"
  }
}

data "template_cloudinit_config" "configelastic" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "../cloud-init/cloud-init-elastic.yaml"
    content_type = "text/cloud-config"
    content      = "${data.template_file.scriptelastic.rendered}"
  }
}

data "template_file" "scriptbastion" {
  template = "${file("${path.module}/../cloud-init/cloud-init-bastion.yaml")}"
}

data "template_cloudinit_config" "configbastion" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "../cloud-init/cloud-init-bastion.yaml"
    content_type = "text/cloud-config"
    content      = "${data.template_file.scriptbastion.rendered}"
  }
}
variable "request_routing_rule_name" {
default =  "rule_magento"
description = "rule for magento gateway"
}

# sortir l'adresse IP dynamiquement

data "http" "myip" {
  url = "https://ifconfig.me"
}
