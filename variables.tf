variable "customer-name" {}
variable "location" {}
variable "location-prefix" {}
variable "hub-prefix" {}
variable "environment" {}
variable "createdby" {}
variable "creationdate" {}
variable "bastion-sku" {}

variable "kv-softdelete-retention-days" {
  type = number
  default = 7
}

variable "hub-vnet-address-space" {}
variable "spoke-vnet-address-space" {}
variable "firewall-subnet-address-space" {}
variable "appgw-subnet-address-space" {}
variable "bastion-subnet-address-space" {}
variable "mgmt-subnet1-address-space" {}
variable "aks-subnet-address-space" {}
variable "sharedsvc-subnet-address-space" {}

###################### JUMP SERVERS (WINDOWS & LINUX) #######
variable "windows-admin-userid" {
  default = "adminuser"
}

variable "windows-admin-password" { 
  default = "P@$$w0rd1234!"
}

variable "linux-admin-userid" { 
  default = "adminuser"
}

variable "linux-admin-password" {
  default = "P@$$w0rd1234!"
}

variable "la-log-retention-in-days" {
  type   =  number
  default =  30
}
