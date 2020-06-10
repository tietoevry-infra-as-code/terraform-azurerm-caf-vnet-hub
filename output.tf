# Resource Group
output "resource_group_name" {
  description = "The name of the resource group in which resources are created"
  value       = element(coalescelist(data.azurerm_resource_group.rgrp.*.name, azurerm_resource_group.rg.*.name, [""]), 0)
}

output "resource_group_id" {
  description = "The id of the resource group in which resources are created"
  value       = element(coalescelist(data.azurerm_resource_group.rgrp.*.id, azurerm_resource_group.rg.*.id, [""]), 0)
}

output "resource_group_location" {
  description = "The location of the resource group in which resources are created"
  value       = element(coalescelist(data.azurerm_resource_group.rgrp.*.location, azurerm_resource_group.rg.*.location, [""]), 0)
}

# Vnet and Subnets
output "virtual_network_name" {
  description = "The name of the virtual network"
  value       = element(concat(azurerm_virtual_network.vnet.*.name, [""]), 0)
}

output "virtual_network_id" {
  description = "The id of the virtual network"
  value       = element(concat(azurerm_virtual_network.vnet.*.id, [""]), 0)
}

output "virtual_network_address_space" {
  description = "List of address spaces that are used the virtual network."
  value       = element(coalescelist(azurerm_virtual_network.vnet.*.address_space, [""]), 0)
}

output "subnet_ids" {
  description = "List of IDs of subnets"
  value       = flatten(concat([for s in azurerm_subnet.snet : s.id], [azurerm_subnet.gw_snet.id]))
}

output "subnet_address_prefixes" {
  description = "List of address prefix for subnets"
  value       = flatten(concat([for s in azurerm_subnet.snet : s.address_prefix], [azurerm_subnet.gw_snet.address_prefixes]))
}

# Network Security group ids
output "network_security_group_ids" {
  description = "List of Network security groups and ids"
  value       = [for n in azurerm_network_security_group.nsg : n.id]
}

# DDoS Protection Plan
output "ddos_protection_plan_id" {
  description = "Ddos protection plan details"
  value       = element(concat(azurerm_network_ddos_protection_plan.ddos.*.id, [""]), 0)
}

# Network Watcher
output "network_watcher_id" {
  description = "ID of Network Watcher"
  value       = element(concat(azurerm_network_watcher.nwatcher.*.id, [""]), 0)
}

output "private_dns_zone_name" {
  description = "The name of Private DNS zones within Azure DNS"
  value       = azurerm_private_dns_zone.dz[0].name
}
output "private_dns_zone_id" {
  description = "The resource id of Private DNS zones within Azure DNS"
  value       = azurerm_private_dns_zone.dz[0].id
}

output "storage_account_id" {
  description = "The ID of the storage account."
  value       = azurerm_storage_account.storeacc.id
}

output "storage_account_name" {
  description = "The name of the storage account."
  value       = azurerm_storage_account.storeacc.name
}

output "storage_primary_access_key" {
  sensitive   = true
  description = "The primary access key for the storage account."
  value       = azurerm_storage_account.storeacc.primary_access_key
}

output "log_analytics_workspace_name" {
  description = "Specifies the name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.logws.name
}

output "log_analytics_workspace_id" {
  description = "Specifies the id of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.logws.id
}

output "log_analytics_customer_id" {
  description = "The Workspace (or Customer) ID for the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.logws.workspace_id
}

output "log_analytics_logs_retention_in_days" {
  description = "The workspace data retention in days. Possible values range between 30 and 730."
  value       = var.log_analytics_logs_retention_in_days
}
