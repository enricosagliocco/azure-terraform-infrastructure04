# terraform.tfvars.example
# Copia questo file in terraform.tfvars e personalizza i valori

##############################################################################
# General Configuration
##############################################################################

resource_group_name = "rg-mycompany-private-aks"
location            = "westeurope"
environment         = "production"
project_name        = "myapp-aks"

##############################################################################
# Network Configuration
##############################################################################

vnet_name                   = "vnet-myapp-aks"
vnet_address_space          = "10.240.0.0/16"
aks_subnet_address_prefix   = "10.240.1.0/24"
pe_subnet_address_prefix    = "10.240.2.0/24"

##############################################################################
# AKS Cluster Configuration
##############################################################################

aks_name           = "aks-myapp-private"
aks_dns_prefix     = "myapp-aks"
kubernetes_version = "1.28.5"

##############################################################################
# Node Pool Configuration
##############################################################################

aks_node_count     = 3
aks_min_node_count = 2
aks_max_node_count = 10
aks_vm_size        = "Standard_D4s_v3"

##############################################################################
# Network Profile
##############################################################################

service_cidr    = "10.0.0.0/16"
dns_service_ip  = "10.0.0.10"

##############################################################################
# Security Configuration
##############################################################################

# Inserisci qui gli Object ID dei gruppi Azure AD con accesso admin
# Puoi trovarli con: az ad group show --group "Nome-Gruppo" --query id -o tsv
aks_admin_group_object_ids = [
  # "12345678-1234-1234-1234-123456789012",
  # "87654321-4321-4321-4321-210987654321"
]

disable_local_accounts = true

##############################################################################
# Tags
##############################################################################

tags = {
  Environment  = "Production"
  ManagedBy    = "Terraform"
  Project      = "MyApp"
  CostCenter   = "IT-Infrastructure"
  Owner        = "DevOps-Team"
}