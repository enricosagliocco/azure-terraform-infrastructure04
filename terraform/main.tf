# terraform/main.tf - Fully Private AKS Cluster Configuration

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  
  # Backend Terraform Cloud configuration
  cloud { 
    organization = "enrico-sagliocco" 
    workspaces { 
      name = "azure-terraform-infrastructure" 
    } 
  } 
}

provider "azurerm" {
  features {}
}

##############################################################################
# Data Sources - Existing Resources
##############################################################################

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    CreatedDate = timestamp()
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

##############################################################################
# Network Security Group
##############################################################################

resource "azurerm_network_security_group" "aks_nsg" {
  name                = "${var.project_name}-aks-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Regole di sicurezza per traffico interno
  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

##############################################################################
# Route Table for User Defined Routing (UDR)
##############################################################################

resource "azurerm_route_table" "aks_route_table" {
  name                          = "${var.project_name}-aks-rt"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  bgp_route_propagation_enabled = true

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

##############################################################################
# Subnet for AKS Nodes (Private)
##############################################################################

resource "azurerm_subnet" "aks_nodes" {
  name                 = "${var.project_name}-aks-nodes-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_address_prefix]
  
  # Abilita private endpoint policies
  private_endpoint_network_policies = "Enabled"
}

# Associazione NSG alla subnet AKS
resource "azurerm_subnet_network_security_group_association" "aks_nodes_nsg" {
  subnet_id                 = azurerm_subnet.aks_nodes.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

# Associazione Route Table alla subnet AKS
resource "azurerm_subnet_route_table_association" "aks_nodes_rt" {
  subnet_id      = azurerm_subnet.aks_nodes.id
  route_table_id = azurerm_route_table.aks_route_table.id
}

##############################################################################
# Subnet for Private Endpoints
##############################################################################

resource "azurerm_subnet" "private_endpoints" {
  name                 = "${var.project_name}-pe-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.pe_subnet_address_prefix]
  
  private_endpoint_network_policies = "Enabled"
}

##############################################################################
# Private DNS Zone for AKS
##############################################################################

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${azurerm_resource_group.main.location}.azmk8s.io"
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = "${var.project_name}-aks-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

##############################################################################
# User Assigned Identity for AKS
# REQUIRED: User-assigned identity is mandatory when using custom private DNS zone
##############################################################################

resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.project_name}-aks-identity"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

##############################################################################
# Role Assignment for Private DNS Zone
# NOTE: This requires User Access Administrator or Owner role for Terraform
# If you get 403 errors, see solutions below
##############################################################################

resource "azurerm_role_assignment" "aks_private_dns_zone_contributor" {
  scope                = azurerm_private_dns_zone.aks.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  # Add skip_service_principal_aad_check to avoid potential race conditions
  skip_service_principal_aad_check = true

  depends_on = [
    azurerm_user_assigned_identity.aks,
    azurerm_private_dns_zone.aks
  ]
}

##############################################################################
# Private AKS Cluster
##############################################################################

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.aks_dns_prefix
  
  # Kubernetes version
  kubernetes_version = var.kubernetes_version

  # *** CONFIGURAZIONE CLUSTER PRIVATO ***
  private_cluster_enabled             = true
  private_dns_zone_id                 = azurerm_private_dns_zone.aks.id
  private_cluster_public_fqdn_enabled = false  # Disabilita FQDN pubblico per sicurezza massima

  # Default Node Pool
  default_node_pool {
    name                = "system"
    vm_size             = var.aks_vm_size
    vnet_subnet_id      = azurerm_subnet.aks_nodes.id
    type                = "VirtualMachineScaleSets"
    
    # Auto-scaling - FIXED: Changed from enable_auto_scaling to auto_scaling_enabled for v4.x
    auto_scaling_enabled = true
    min_count            = var.aks_min_node_count
    max_count            = var.aks_max_node_count
    
    # OS configuration
    os_disk_type       = "Ephemeral"
    os_disk_size_gb    = 100
    
    # Pod per nodo
    max_pods           = 30
    
    # Upgrade settings
    upgrade_settings {
      max_surge = "10%"
    }

    # Labels per system node pool
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
      "nodepoolos"    = "linux"
    }

    tags = {
      Environment = var.environment
      NodePool    = "system"
    }
  }

  # User Assigned Identity (REQUIRED for custom private DNS zone)
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Network Profile per cluster privato
  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"
    load_balancer_sku  = "standard"
    
    # *** IMPORTANTE: User Defined Routing per cluster privato ***
    outbound_type      = "userDefinedRouting"
    
    # Service e DNS CIDR - devono essere diversi dalla VNet
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
  }

  # API Server Access Profile - Solo accesso privato
  api_server_access_profile {
    authorized_ip_ranges = []  # Vuoto = solo accesso privato
  }

  # Azure Active Directory Integration
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.aks_admin_group_object_ids # Keep your admin group IDs here
  }

  # Disable local accounts for enhanced security
  local_account_disabled = var.disable_local_accounts

  # Azure Policy Add-on
  azure_policy_enabled = true

  # OMS Agent per monitoring
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Key Vault Secrets Provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Maintenance Window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3, 4]
    }
  }

  # Tags
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    ClusterType = "Private"
  }

  depends_on = [
    azurerm_subnet.aks_nodes,
    azurerm_subnet_network_security_group_association.aks_nodes_nsg,
    azurerm_subnet_route_table_association.aks_nodes_rt,
    azurerm_private_dns_zone.aks,
    azurerm_private_dns_zone_virtual_network_link.aks,
    azurerm_role_assignment.aks_private_dns_zone_contributor
  ]
}

##############################################################################
# Log Analytics Workspace per monitoring
##############################################################################

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

##############################################################################
# Role Assignment - AKS to VNet (Optional but recommended)
##############################################################################

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_virtual_network.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  skip_service_principal_aad_check = true
  
  depends_on = [azurerm_user_assigned_identity.aks]
}

##############################################################################
# Private Endpoint for AKS (opzionale, per connessioni aggiuntive)
##############################################################################

resource "azurerm_private_endpoint" "aks" {
  name                = "${var.project_name}-aks-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${var.project_name}-aks-psc"
    private_connection_resource_id = azurerm_kubernetes_cluster.main.id
    is_manual_connection           = false
    subresource_names              = ["management"]
  }

  private_dns_zone_group {
    name                 = "aks-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.aks.id]
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

##############################################################################
# Outputs
##############################################################################

output "aks_cluster_name" {
  value       = azurerm_kubernetes_cluster.main.name
  description = "Nome del cluster AKS"
}

output "aks_cluster_id" {
  value       = azurerm_kubernetes_cluster.main.id
  description = "ID del cluster AKS"
}

output "aks_private_fqdn" {
  value       = azurerm_kubernetes_cluster.main.private_fqdn
  description = "FQDN privato del cluster AKS"
}

output "aks_node_resource_group" {
  value       = azurerm_kubernetes_cluster.main.node_resource_group
  description = "Resource Group dei nodi AKS"
}

output "aks_identity_principal_id" {
  value       = azurerm_user_assigned_identity.aks.principal_id
  description = "Principal ID della managed identity del cluster"
}

output "private_dns_zone_id" {
  value       = azurerm_private_dns_zone.aks.id
  description = "ID della Private DNS Zone"
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.main.id
  description = "ID del Log Analytics Workspace"
}

output "kube_config_command" {
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
  description = "Comando per ottenere le credenziali kubectl (da eseguire da una VM nella VNet o tramite VPN)"
}