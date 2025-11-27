# terraform/variables.tf

variable "resource_group_name" {
  description = "Nome del Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vnet_name" {
  description = "Nome della Virtual Network"
  type        = string
}

variable "vnet_address_space" {
  description = "CIDR della Virtual Network"
  type        = string
}

variable "subnet_name" {
  description = "Nome della Subnet"
  type        = string
}

variable "subnet_address_prefix" {
  description = "CIDR della Subnet"
  type        = string
}

variable "aks_name" {
  description = "Nome del cluster AKS"
  type        = string
}

variable "aks_dns_prefix" {
  description = "DNS prefix per AKS"
  type        = string
}

variable "aks_node_count" {
  description = "Numero di nodi nel pool AKS"
  type        = number
}

variable "aks_vm_size" {
  description = "VM size per i nodi AKS"
  type        = string
}
