# terraform/outputs.tf

output "resource_group_name" {
  description = "Nome del Resource Group creato"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID del Resource Group"
  value       = azurerm_resource_group.main.id
}

output "virtual_network_name" {
  description = "Nome della Virtual Network"
  value       = azurerm_virtual_network.main.name
}


output "aks_name" {
  description = "Nome del cluster AKS"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_kube_config" {
  description = "Kube config del cluster AKS"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}
