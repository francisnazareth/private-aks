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
  location = var.location
  tags = {
    Environment   = var.environment
    CreatedBy     = var.createdby
    CreationDate  = var.creationdate
  }
}

resource "azurerm_resource_group" "spoke-rg" {
  name     = "rg-${var.customer-name}-spoke-${var.location-prefix}-01"
  location = var.location
  tags = {
    Environment   = var.environment
    CreatedBy     = var.createdby
    CreationDate  = var.creationdate
  }
}

resource "azurerm_log_analytics_workspace" "la-workspace-hub" {
  name                = "laworkspace-hub-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  sku                 = "PerGB2018"
  retention_in_days   = var.la-log-retention-in-days
}

resource "azurerm_log_analytics_solution" "la-hub-solution" {
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = azurerm_resource_group.hub-rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.la-workspace-hub.id
  workspace_name        = azurerm_log_analytics_workspace.la-workspace-hub.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

resource "azurerm_virtual_network" "hub-vnet" {
  name                = "vnet-hub-${var.location-prefix}-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  address_space       = [var.hub-vnet-address-space]

  tags = {
    Environment = var.environment
    CreatedBy   = var.createdby
    CreationDate = var.creationdate
  }
}

resource "azurerm_subnet" "hub-bastion-subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = [var.bastion-subnet-address-space]
}

resource "azurerm_subnet" "hub-firewall-subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = [var.firewall-subnet-address-space]
}

resource "azurerm_virtual_network" "spoke-vnet" {
  name                = "vnet-spoke-${var.location-prefix}-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke-rg.name
  address_space       = [var.spoke-vnet-address-space]

  tags = {
    Environment = var.environment
    CreatedBy   = var.createdby
    CreationDate = var.creationdate
  }
}

resource "azurerm_subnet" "aks-subnet" {
  name                 = "snet-aks-${var.location-prefix}-01"
  resource_group_name  = azurerm_resource_group.spoke-rg.name
  virtual_network_name = azurerm_virtual_network.spoke-vnet.name
  address_prefixes     = [var.aks-subnet-address-space]
}

resource "azurerm_virtual_network_peering" "hub-to-spoke" {
  name                      = "hub-to-spoke"
  resource_group_name       = azurerm_resource_group.hub-rg.name
  virtual_network_name      = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.spoke-vnet.id
}

resource "azurerm_virtual_network_peering" "spoke-to-hub" {
  name                      = "spoke-to-hub"
  resource_group_name       = azurerm_resource_group.spoke-rg.name
  virtual_network_name      = azurerm_virtual_network.spoke-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id
}

resource "azurerm_public_ip" "pip-firewall" {
  name                = "pip-azure-firewall"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  allocation_method   = "Static"
  availability_zone   = "Zone-Redundant"
  sku                 = "Standard"

  tags = {
    Environment  = var.environment,
    CreatedBy    = var.createdby,
    CreationDate = var.creationdate
  }
}

resource "azurerm_firewall_policy" "fw-policy" {
  name                = "fw-policy-01"
  resource_group_name = azurerm_resource_group.hub-rg.name
  location            = var.location
  sku                 = "Premium"
  threat_intelligence_mode = "Deny"
  intrusion_detection  {
    mode = "Deny"
  }
}

resource "azurerm_firewall" "azure-ext-fw" {
  name                = "fw-${var.customer-name}-hub-we-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  sku_tier            = "Premium"
  zones               = [1,2,3]
  firewall_policy_id = azurerm_firewall_policy.fw-policy.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub-firewall-subnet.id
    public_ip_address_id = azurerm_public_ip.pip-firewall.id
  }

  tags = {
    Environment  = var.environment,
    CreatedBy    = var.createdby,
    CreationDate = var.creationdate
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "aks-rule-collection" {
  name                = "aks-collection"
  firewall_policy_id = azurerm_firewall_policy.fw-policy.id
  priority            = 100

  network_rule_collection {
    priority = 400
    action = "Allow"
    name = "aks-network-rule-collection"
    rule {
       name = "FWR-AKS-AZURE-GLOBAL-001"
       source_addresses = [var.aks-subnet-address-space]
       destination_addresses = ["AzureCloud"]
       destination_ports = ["1194"]
       protocols = ["UDP"]
    }   
    rule {
       name = "FWR-AKS-AZURE-GLOBAL-002"
       source_addresses = [var.aks-subnet-address-space]
       destination_ports = ["9000"]
       destination_addresses = ["AzureCloud"]
       protocols = ["TCP"]
    }
    rule {
       name = "FWR-AKS-AZURE-GLOBAL-003"
       source_addresses = [var.aks-subnet-address-space]
       destination_ports = ["123"]
       destination_addresses = ["ntp.ubuntu.com"]
       protocols = ["UDP"]
    }
  }
  
  application_rule_collection {
    priority = 500
    action = "Allow"
    name = "aks-application-rule-collection"

    rule {
       name = "FWARG-AKS-REQUIREMENTS-001"

       source_addresses = [var.aks-subnet-address-space]
       destination_fqdn_tags = ["AzureKubernetesService"]

       protocols {
         port = "443"
         type = "Https"
       }

       protocols {
         port = "80"
         type = "Http"
       }
    }
  }   
}

resource "azurerm_route_table" "rt-hub-firewall" {
  name                          = "route-to-hub-firewall"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.spoke-rg.name
  disable_bgp_route_propagation = false

  route {
    name                        = "route_internal_traffic_in_vnet"
    address_prefix              = var.spoke-vnet-address-space
    next_hop_type               = "VnetLocal"
  }

  route {
    name                        = "route_all_traffic_to_fw"
    address_prefix              = "0.0.0.0/0"
    next_hop_type               = "VirtualAppliance"
    next_hop_in_ip_address      = azurerm_firewall.azure-ext-fw.ip_configuration[0].private_ip_address
  }

  tags = {
    Environment  = var.environment,
    CreatedBy    = var.createdby,
    CreationDate = var.creationdate
  }
}

resource "azurerm_subnet_route_table_association" "aks-subnet-to-route-table" {
  subnet_id      = azurerm_subnet.aks-subnet.id
  route_table_id = azurerm_route_table.rt-hub-firewall.id
}

resource "azurerm_kubernetes_cluster" "private-aks" {
  name                       = "aks-${var.customer-name}-web-we-01"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.spoke-rg.name
  dns_prefix                 = "aks-${var.customer-name}-web"
  private_cluster_enabled    = true
  oidc_issuer_enabled        = true
  workload_identity_enabled  = true
  
  sku_tier            = "Paid"
  node_resource_group = "rg-aksnode-${var.customer-name}-web-${var.location-prefix}-01"
  azure_policy_enabled = true

  default_node_pool {
    name       = "systempool"
    node_count = 3
    max_pods   = 30
    os_disk_size_gb = 128
    os_disk_type = "Managed"
    availability_zones = [1, 2, 3]
    vm_size    = var.aks-system-node-vm-size
    vnet_subnet_id = azurerm_subnet.aks-subnet.id
    type           = "VirtualMachineScaleSets" 
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin       = "azure"
    network_policy       = "calico"
    load_balancer_sku    = "standard"
    outbound_type        = "userDefinedRouting"  
    dns_service_ip       = "172.23.156.10"
    docker_bridge_cidr   = "172.17.0.1/24"
    service_cidr         = "172.23.156.0/22" 
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.la-workspace-hub.id
  }  
  
  tags = {
    Environment  = var.environment,
    CreatedBy    = var.createdby,
    CreationDate = var.creationdate
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "webapp-np" {
  name                  = "webapp01"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.private-aks.id
  vm_size               = "Standard_D32ds_v4"
  node_count            = 10
  enable_auto_scaling   = true
  min_count             = 10
  max_count             = 40
  vnet_subnet_id        = azurerm_subnet.aks-subnet.id
  availability_zones    = [1, 2, 3]
  max_pods              = 20
  os_disk_size_gb = 128
  os_disk_type = "Ephemeral"

  node_taints = ["workload=webapp:NoSchedule"]
  node_labels = {"workload"="webapp"}

  tags = {
    Environment  = var.environment,
    CreatedBy    = var.createdby,
    CreationDate = var.creationdate
  }
}
