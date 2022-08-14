# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.99"
    }
  }

  required_version = ">=1.2.3"
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

data "azurerm_client_config" "current" {}

output "current_client_id" {
  value = data.azurerm_client_config.current.client_id
}

output "current_tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "current_subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}

output "current_object_id" {
  value = data.azurerm_client_config.current.object_id
}

resource "azurerm_resource_group" "hub-rg" {
  name     = "rg-${var.customer-name}-hub-${var.location-prefix}-01"
  location = var.hub-location
  tags = {
    Environment   = var.environment
    CreatedBy     = var.createdby
    CreationDate  = var.creationdate
  }
}

#module "diag-storage" {
#    source         = "./storage"
#    rg-name        = module.hub-rg.rg-name
#    rg-location    = module.hub-rg.rg-location
#    customer-name  = var.customer-name
#}

#module "laworkspace" {
#    source         = "./laworkspace"
#    rg-name        = module.hub-rg.rg-name
#    rg-location    = module.hub-rg.rg-location
#    la-log-retention-in-days = var.la-log-retention-in-days
#}




