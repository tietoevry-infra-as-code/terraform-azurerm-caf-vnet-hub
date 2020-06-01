module "vnet-hub" {
  source = "github.com/tietoevry-infra-as-code/terraform-azurerm-caf-vnet-hub?ref=v1.0.0"

  # By default, this module will create a resource group, proivde the name here 
  # to use an existing resource group, specify the existing resource group name, 
  # and set the argument to `create_resource_group = false`. Location will be same as existing RG. 
  # RG name must follow Azure naming convention. ex.: rg-<App or project name>-<Subscription type>-<Region>-<###>
  # Resource group is named like this: rg-tieto-internal-prod-westeurope-001
  create_resource_group = true
  resource_group_name   = "rg-tieto-internal-shared-westeurope-001"
  location              = "westeurope"

  # (Required) Project_Name, Subscription_type and environment are must to create resource names.
  project_name      = "tieto-internal"
  subscription_type = "shared"
  environment       = "dev"

  # Provide valid VNet Address space and specify valid domain name for Private DNS Zone.  
  vnet_address_space    = ["10.1.0.0/16"]
  private_dns_zone_name = "publiccloud.tieto.com"

  # (Required) To enable Azure Monitoring and flow logs
  # Possible values range between 30 and 730
  log_analytics_workspace_sku          = "PerGB2018"
  log_analytics_logs_retention_in_days = 30
  azure_monitor_logs_retention_in_days = 30

  # Adding Standard DDoS Plan, and custom DNS servers (Optional)
  dns_servers = []

  # Multiple Subnets, Service delegation, Service Endpoints, Network security groups
  # These are default subnets with required configuration, check README.md for more details
  # Route_table and NSG association to be added automatically for all subnets listed here.
  # subnet name will be set as per Azure naming convention by defaut. expected value here is: <App or project name>
  subnets = {

    gw_subnet = {
      subnet_name           = "gateway"
      subnet_address_prefix = ["10.1.1.0/24"]
      service_endpoints     = ["Microsoft.Storage"]
    }

    mgnt_subnet = {
      subnet_name           = "management"
      subnet_address_prefix = ["10.1.2.0/24"]
      service_endpoints     = ["Microsoft.Storage"]

      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any value and to use this subnet as a source or destination prefix.
        ["weballow", "200", "Inbound", "Allow", "Tcp", "22", "*", ""],
        ["weballow1", "201", "Inbound", "Allow", "Tcp", "3389", "*", ""],
      ]

      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any value and to use this subnet as a source or destination prefix.
        ["ntp_out", "103", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"],
      ]
    }

    dmz_subnet = {
      subnet_name           = "appgateway"
      subnet_address_prefix = ["10.1.3.0/24"]
      service_endpoints     = ["Microsoft.Storage"]
      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any value and to use this subnet as a source or destination prefix.
        ["weballow", "100", "Inbound", "Allow", "Tcp", "80", "*", "0.0.0.0/0"],
        ["weballow1", "101", "Inbound", "Allow", "Tcp", "443", "*", ""],

      ]
      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any value and to use this subnet as a source or destination prefix.
        ["ntp_out", "103", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"],
      ]
    }
  }

  # Adding TAG's to your Azure resources (Required)
  # ProjectName and Env are already declared above, to use them here, create a varible. 
  tags = {
    ProjectName  = "tieto-internal"
    Env          = "dev"
    Owner        = "user@example.com"
    BusinessUnit = "CORP"
    ServiceClass = "Gold"
  }
}
