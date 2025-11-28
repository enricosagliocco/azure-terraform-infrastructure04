# terraform/variables.tf - Variables for Private AKS Cluster

##############################################################################
# General Variables
##############################################################################

variable "resource_group_name" {
  description = "Nome del Resource Group"
  type        = string
  default     = "rg-private-aks"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nome del progetto (usato per naming convention)"
  type        = string
  default     = "private-aks"
}

##############################################################################
# Network Variables
##############################################################################

variable "vnet_name" {
  description = "Nome della Virtual Network"
  type        = string
  default     = "vnet-private-aks"
}

variable "vnet_address_space" {
  description = "CIDR della Virtual Network"
  type        = string
  default     = "10.240.0.0/16"
}

variable "aks_subnet_address_prefix" {
  description = "CIDR della subnet per i nodi AKS"
  type        = string
  default     = "10.240.1.0/24"
}

variable "pe_subnet_address_prefix" {
  description = "CIDR della subnet per i Private Endpoints"
  type        = string
  default     = "10.240.2.0/24"
}

##############################################################################
# AKS Cluster Variables
##############################################################################

variable "aks_name" {
  description = "Nome del cluster AKS"
  type        = string
  default     = "aks-private-cluster"
}

variable "aks_dns_prefix" {
  description = "DNS prefix per il cluster AKS"
  type        = string
  default     = "aks-private"
}

variable "kubernetes_version" {
  description = "Versione di Kubernetes"
  type        = string
  default     = "1.28.5"  # Aggiorna alla versione desiderata
}

##############################################################################
# Node Pool Variables
##############################################################################

variable "aks_node_count" {
  description = "Numero iniziale di nodi"
  type        = number
  default     = 2
}

variable "aks_min_node_count" {
  description = "Numero minimo di nodi per auto-scaling"
  type        = number
  default     = 1
}

variable "aks_max_node_count" {
  description = "Numero massimo di nodi per auto-scaling"
  type        = number
  default     = 5
}

variable "aks_vm_size" {
  description = "Dimensione delle VM per i nodi"
  type        = string
  default     = "Standard_D2s_v3"
}

##############################################################################
# Network Profile Variables
##############################################################################

variable "service_cidr" {
  description = "CIDR per i servizi Kubernetes (deve essere diverso dalla VNet)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "IP del servizio DNS di Kubernetes (deve essere nel service_cidr)"
  type        = string
  default     = "10.0.0.10"
}

##############################################################################
# Security Variables
##############################################################################

variable "aks_admin_group_object_ids" {
  description = "Lista di Object ID dei gruppi Azure AD con accesso admin al cluster"
  type        = list(string)
  default     = []
  
  # Esempio:
  # default = ["12345678-1234-1234-1234-123456789012"]
}

variable "disable_local_accounts" {
  description = "Disabilita gli account locali per maggiore sicurezza"
  type        = bool
  default     = true
}

##############################################################################
# Tags Variables
##############################################################################

variable "tags" {
  description = "Tags da applicare a tutte le risorse"
  type        = map(string)
  default     = {
    ManagedBy = "Terraform"
    CostCenter = "IT"
  }
}