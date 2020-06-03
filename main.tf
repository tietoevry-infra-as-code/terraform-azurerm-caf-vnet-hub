#---------------------------------------------------------
# Resource Group Creation or selection - Default is "false"
#----------------------------------------------------------
locals {
  resource_group_name = element(coalescelist(data.azurerm_resource_group.rgrp.*.name, azurerm_resource_group.rg.*.name, [""]), 0)
  location            = element(coalescelist(data.azurerm_resource_group.rgrp.*.location, azurerm_resource_group.rg.*.location, [""]), 0)
  if_ddos_enabled     = var.create_ddos_plan ? [{}] : []
}

data "azurerm_resource_group" "rgrp" {
  count = var.create_resource_group == false ? 1 : 0
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "rg" {
  count    = var.create_resource_group ? 1 : 0
  name     = lower(var.resource_group_name)
  location = var.location
  tags     = merge({ "ResourceName" = format("%s", var.resource_group_name) }, var.tags, )
}

#-------------------------------------
# VNET Creation - Default is "true"
#-------------------------------------

resource "azurerm_virtual_network" "vnet" {
  name                = lower("vnet-${var.project_name}-${var.subscription_type}-${var.environment}-${local.location}-01")
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = var.vnet_address_space
  dns_servers         = var.dns_servers
  tags                = merge({ "ResourceName" = lower("vnet-${var.project_name}-${var.subscription_type}-${var.environment}-${local.location}-01") }, var.tags, )

  dynamic "ddos_protection_plan" {
    for_each = local.if_ddos_enabled

    content {
      id     = azurerm_network_ddos_protection_plan.ddos[0].id
      enable = true
    }
  }
}

#--------------------------------------------
# Ddos protection plan - Default is "false"
#--------------------------------------------

resource "azurerm_network_ddos_protection_plan" "ddos" {
  count               = var.create_ddos_plan ? 1 : 0
  name                = lower("${var.project_name}-ddos-protection-plan-${var.subscription_type}")
  resource_group_name = local.resource_group_name
  location            = local.location
  tags                = merge({ "ResourceName" = lower("${var.project_name}-ddos-protection-plan-${var.subscription_type}") }, var.tags, )
}

#-------------------------------------
# Network Watcher - Default is "true"
#-------------------------------------

resource "azurerm_network_watcher" "nwatcher" {
  count               = var.create_network_watcher ? 1 : 0
  name                = "NetworkWatcher_${local.location}"
  location            = local.location
  resource_group_name = local.resource_group_name
  tags                = merge({ "ResourceName" = format("%s", "NetworkWatcher_${local.location}") }, var.tags, )
}

#--------------------------------------------
# Subnets Creation - Depends on VNET Resource
#--------------------------------------------
resource "azurerm_subnet" "snet" {
  for_each             = var.subnets
  name                 = lower(format("snet-%s-${var.subscription_type}-${local.location}", each.value.subnet_name))
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.subnet_address_prefix
  service_endpoints    = lookup(each.value, "service_endpoints", [])
  # Applicable to the subnets which used for Private link endpoints or services 
  enforce_private_link_endpoint_network_policies = lookup(each.value, "enforce_private_link_endpoint_network_policies", null)
  enforce_private_link_service_network_policies  = lookup(each.value, "enforce_private_link_service_network_policies", null)

  dynamic "delegation" {
    for_each = lookup(each.value, "delegation", {}) != {} ? [1] : []
    content {
      name = lookup(each.value.delegation, "name", null)
      service_delegation {
        name    = lookup(each.value.delegation.service_delegation, "name", null)
        actions = lookup(each.value.delegation.service_delegation, "actions", null)
      }
    }
  }
}

#-----------------------------------------------
# Network security group - Default is "false"
#-----------------------------------------------
resource "azurerm_network_security_group" "nsg" {
  for_each            = var.subnets
  name                = lower("nsg_${each.key}_in")
  resource_group_name = local.resource_group_name
  location            = local.location
  tags                = merge({ "ResourceName" = lower("nsg_${each.key}_in") }, var.tags, )
  dynamic "security_rule" {
    for_each = concat(lookup(each.value, "nsg_inbound_rules", []), lookup(each.value, "nsg_outbound_rules", []))
    content {
      name                       = security_rule.value[0] == "" ? "Default_Rule" : security_rule.value[0]
      priority                   = security_rule.value[1]
      direction                  = security_rule.value[2] == "" ? "Inbound" : security_rule.value[2]
      access                     = security_rule.value[3] == "" ? "Allow" : security_rule.value[3]
      protocol                   = security_rule.value[4] == "" ? "Tcp" : security_rule.value[4]
      source_port_range          = "*"
      destination_port_range     = security_rule.value[5] == "" ? "*" : security_rule.value[5]
      source_address_prefix      = security_rule.value[6] == "" ? element(each.value.subnet_address_prefix, 0) : security_rule.value[6]
      destination_address_prefix = security_rule.value[7] == "" ? element(each.value.subnet_address_prefix, 0) : security_rule.value[7]
      description                = "${security_rule.value[2]}_Port_${security_rule.value[5]}"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg-assoc" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.snet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

#-----------------------------------------------
# route_table for all subnets - Default is "true"
#-----------------------------------------------

resource "azurerm_route_table" "rtout" {
  name                = "route-network-outbound"
  resource_group_name = local.resource_group_name
  location            = local.location
  tags                = merge({ "ResourceName" = "route-network-outbound" }, var.tags, )
}

resource "azurerm_subnet_route_table_association" "rtassoc" {
  for_each       = var.subnets
  subnet_id      = azurerm_subnet.snet[each.key].id
  route_table_id = azurerm_route_table.rtout.id
}

#----------------------------------------
# Private DNS Zone - Default is "true"
#----------------------------------------

resource "azurerm_private_dns_zone" "dz" {
  count               = var.private_dns_zone_name != null ? 1 : 0
  name                = var.private_dns_zone_name
  resource_group_name = local.resource_group_name
  tags                = merge({ "ResourceName" = format("%s", lower(var.private_dns_zone_name)) }, var.tags, )
}

resource "azurerm_private_dns_zone_virtual_network_link" "dzvlink" {
  count                 = var.private_dns_zone_name != null ? 1 : 0
  name                  = lower("${var.private_dns_zone_name}-link")
  resource_group_name   = local.resource_group_name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  private_dns_zone_name = azurerm_private_dns_zone.dz[0].name
  tags                  = merge({ "ResourceName" = format("%s", lower("${var.private_dns_zone_name}-link")) }, var.tags, )
}

#----------------------------------------------------------------
# Azure Role Assignment for Service Principal - Default is "true"
#-----------------------------------------------------------------
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "peering" {
  scope                = azurerm_virtual_network.vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "dns" {
  scope                = azurerm_private_dns_zone.dz[0].id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

/* Need to work on multiple service principles, groups roles assignment. 
  resource "azurerm_role_assignment" "peering" {
  count                = length(var.service_principals)
  scope                = azurerm_virtual_network.vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = var.service_principals[count.index] 
}

resource "azurerm_role_assignment" "dns" {
  count                = var.private_dns_zone_name != null ? length(var.service_principals) : 0
  scope                = azurerm_private_dns_zone.dz[0].id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = var.service_principals[count.index]
}

*/
#-----------------------------------------------
# Network Watcher flow logs - Default is "true"
#-----------------------------------------------
resource "azurerm_storage_account" "storeacc" {
  count                     = var.enable_network_watcher_flow_logs ? 1 : 0
  name                      = format("stdiaglogs%s", lower(replace(var.project_name, "/[[:^alnum:]]/", "")))
  resource_group_name       = local.resource_group_name
  location                  = local.location
  account_kind              = "StorageV2"
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = true
  tags                      = merge({ "ResourceName" = format("%s%s", lower(replace(var.project_name, "/[[:^alnum:]]/", "")), "stdiaglogs") }, var.tags, )
}

resource "random_string" "main" {
  length  = 8
  special = false
  keepers = {
    name = var.project_name
  }
}


resource "azurerm_log_analytics_workspace" "logws" {
  count               = var.enable_network_watcher_flow_logs ? 1 : 0
  name                = lower("log-${random_string.main.result}-${var.project_name}-${var.subscription_type}-${var.environment}-${local.location}")
  resource_group_name = local.resource_group_name
  location            = local.location
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = var.log_analytics_logs_retention_in_days
  tags                = merge({ "ResourceName" = lower("log-${random_string.main.result}-${var.project_name}-${var.subscription_type}-${var.environment}-${local.location}") }, var.tags, )
}

resource "azurerm_network_watcher_flow_log" "nwflog" {
  for_each                  = var.subnets
  network_watcher_name      = azurerm_network_watcher.nwatcher.0.name
  resource_group_name       = local.resource_group_name
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
  storage_account_id        = azurerm_storage_account.storeacc.0.id
  enabled                   = true
  version                   = 2

  retention_policy {
    enabled = true
    days    = var.log_analytics_logs_retention_in_days
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.logws.0.workspace_id
    workspace_region      = local.location
    workspace_resource_id = azurerm_log_analytics_workspace.logws.0.id
    interval_in_minutes   = 10
  }
}

#----------------------------------------------------
# azurerm monitoring diagnostics - Default is "true"
#----------------------------------------------------
# vpc, and all other resources. 

resource "azurerm_monitor_diagnostic_setting" "vnet" {
  name                       = lower("vnet-${var.project_name}-diag")
  target_resource_id         = azurerm_virtual_network.vnet.id
  storage_account_id         = azurerm_storage_account.storeacc.0.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logws.0.id

  log {
    category = "VMProtectionAlerts"
    enabled  = true

    retention_policy {
      enabled = true
      days    = var.azure_monitor_logs_retention_in_days
    }
  }
  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = true
      days    = var.azure_monitor_logs_retention_in_days
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  for_each                   = var.subnets
  name                       = lower("${each.key}-diag")
  target_resource_id         = azurerm_network_security_group.nsg[each.key].id
  storage_account_id         = azurerm_storage_account.storeacc.0.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logws.0.id

  dynamic "log" {
    for_each = var.nsg_diag_logs
    content {
      category = log.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = var.azure_monitor_logs_retention_in_days
      }
    }
  }
}
