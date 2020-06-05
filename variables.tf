variable "create_resource_group" {
  description = "Whether to create resource group and use it for all networking resources"
  default     = true
}

variable "resource_group_name" {
  description = "A container that holds related resources for an Azure solution"
  default     = ""
}

variable "location" {
  description = "The location/region to keep all your network resources. To get the list of all locations with table format from azure cli, run 'az account list-locations -o table'"
  default     = ""
}

variable "project_name" {
  description = "The name of the project."
  default     = ""
}

variable "subscription_type" {
  description = "Summary description of the purpose of the subscription that contains the resource. Often broken down by deployment environment type or specific workloads"
  default     = ""
}

variable "environment" {
  description = "The stage of the development lifecycle for the workload that the resource supports"
  default     = ""
}

variable "vnet_address_space" {
  description = "The address space to be used for the Azure virtual network."
  default     = ["10.0.0.0/16"]
}

variable "create_ddos_plan" {
  description = "Create an ddos plan - Default is false"
  default     = true
}

variable "dns_servers" {
  description = "List of dns servers to use for virtual network"
  default     = []
}

variable "create_network_watcher" {
  description = "Controls if Network Watcher resources should be created for the Azure subscription"
  default     = true
}

variable "subnets" {
  description = "For each subnet, create an object that contain fields"
  default     = {}
}

/*variable "service_principals" {
  description = "List of principal ids that need access to peer to this Hub network. All service principals used to deploy spoke networks must have access to peer."
  type        = list(string)
  default     = []
}*/

variable "private_dns_zone_name" {
  description = "The name of the Private DNS zone"
  default     = null
}

variable "log_analytics_workspace_sku" {
  description = "The Sku of the Log Analytics Workspace. Possible values are Free, PerNode, Premium, Standard, Standalone, Unlimited, and PerGB2018"
  default     = "PerGB2018"
}

variable "log_analytics_logs_retention_in_days" {
  description = "The log analytics workspace data retention in days. Possible values range between 30 and 730."
  default     = 30
}

variable "azure_monitor_logs_retention_in_days" {
  description = "The Azure Monitoring data retention in days."
  default     = 30
}

variable "nsg_diag_logs" {
  description = "NSG Monitoring Category details for Azure Diagnostic setting"
  default     = ["NetworkSecurityGroupEvent", "NetworkSecurityGroupRuleCounter"]
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
