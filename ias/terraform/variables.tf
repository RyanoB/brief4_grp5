variable "resource_group_name" {
  default = "brief4_QB"
  description   = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "resource_group_location" {
  default = "eastus2"
  description   = "Location of the resource group."
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

variable "ip_app_name" {
    default = "ip_app"
}

# Render a part using a `template_file`
data "template_file" "script" {
  template = "${file("${path.module}/../cloud-init/cloud-init.yaml")}"
}

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "../cloud-init/cloud-init.yaml"
    content_type = "text/cloud-config"
    content      = "${data.template_file.script.rendered}"
  }
}