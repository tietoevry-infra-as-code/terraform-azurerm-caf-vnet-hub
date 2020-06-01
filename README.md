# Azure Virtual Network Hub Terraform Module

This module deploys a hub network using the [Microsoft recommended Hub-Spoke network topology](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke). Usually, only one hub in each region with multiple spokes and each of them can also be in separate subscriptions.

The following reference architecture shows how to implement a hub-spoke topology in Azure. The hub is a virtual network in Azure that acts as a central point of connectivity to an on-premises network. The spokes are virtual networks that peer with the hub and can be used to isolate workloads. Traffic flows between the on-premises datacenter and the hub through an ExpressRoute or VPN gateway connection.

AzureFirewallSubnet and GatewaySubnet will not contain any UDR (User Defined Route) or NSG (Network Security Group). Management and DMZ will route all outgoing traffic through firewall instance.

![enter image description here](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/images/hub-spoke.png)

Source: [Microsoft Azure Hub-Spoke Topology Documentation](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)

These types of resources are supported:

* [Virtual Network](https://www.terraform.io/docs/providers/azurerm/r/virtual_network.html)
* [Subnets](https://www.terraform.io/docs/providers/azurerm/r/subnet.html)
* [Subnet Service Delegation](https://www.terraform.io/docs/providers/azurerm/r/subnet.html#delegation)
* [Virtual Network service endpoints](https://www.terraform.io/docs/providers/azurerm/r/subnet.html#service_endpoints)
* [AzureNetwork DDoS Protection Plan](https://www.terraform.io/docs/providers/azurerm/r/network_ddos_protection_plan.html)
* [Network Watcher](https://www.terraform.io/docs/providers/azurerm/r/network_watcher.html)
* [Network Security Groups](https://www.terraform.io/docs/providers/azurerm/r/network_security_group.html)
* [Route Table](https://www.terraform.io/docs/providers/azurerm/r/route_table.html)
* [Role Assignment for Peering](https://www.terraform.io/docs/providers/azurerm/r/role_assignment.html)
* [Storage Account](https://www.terraform.io/docs/providers/azurerm/r/storage_account.html)
* [Log Analytics Workspace](https://www.terraform.io/docs/providers/azurerm/r/log_analytics_workspace.html)
* [Azure Monitoring Diagnostics](https://www.terraform.io/docs/providers/azurerm/r/monitor_diagnostic_setting.html)
* [Network Watcher Workflow Logs](https://www.terraform.io/docs/providers/azurerm/r/network_watcher_flow_log.html)
* [Private DNS Zone](https://www.terraform.io/docs/providers/azurerm/r/private_dns_zone.html)

## Module Usage

```
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
```

## Create resource group

By default, this module will create a resource group and the name of the resource group to be given in an argument `resource_group_name`. If you want to use an existing resource group, specify the existing resource group name, and set the argument to `create_resource_group = false`.

> #### *If you are using an existing resource group, then this module uses the same resource group location to create all resources in this module.*

## Azure Network DDoS Protection Plan

By default, this module will create a DDoS Protection Plan. You can enable/disable it by appending an argument `create_ddos_plan`. If you want to disable a DDoS plan using this module, set argument `create_ddos_plan = false`

## Subnets

This module handles the creation and a list of address spaces for subnets. This module uses `for_each` to create subnets and corresponding service endpoints, service delegation, and network security groups. This module associates the subnets to network security groups as well with additional user-defined NSG rules.  

This module creates 4 subnets by default: Gateway Subnet, AzureFirewallSubnet, and Management Subnet.

Name | Description 
---- | ----------- 
Gateway Subnet| Contain VPN Gateway, Express route Gateway
AzureFirewallSubnet|If added the Firewall module, it Deploys an Azure Firewall that will monitor all incoming and outgoing traffic
ApplicationGateway|Contain an Application Gateway etc...
Management|Management subnet for Bastion host, accessible from gateway

Both Gateway Subnet and AzureFirewallSubnet allow traffic out and can have public IPs. ApplicationGateway and Management subnet route traffic through the firewall and does not support public IPs due to asymmetric routing.

## Virtual Network service endpoints

Service Endpoints allows connecting certain platform services into virtual networks.  With this option, Azure virtual machines can interact with Azure SQL and Azure Storage accounts, as if they’re part of the same virtual network, rather than Azure virtual machines accessing them over the public endpoint.

This module supports enabling the service endpoint of your choosing under the virtual network and with the specified subnet. The list of Service endpoints to associate with the subnet values include: `Microsoft.AzureActiveDirectory`, `Microsoft.AzureCosmosDB`, `Microsoft.ContainerRegistry`, `Microsoft.EventHub`, `Microsoft.KeyVault`, `Microsoft.ServiceBus`, `Microsoft.Sql`, `Microsoft.Storage` and `Microsoft.Web`.

```
module "vnet-hub" {
  source = "github.com/tietoevry-infra-as-code/terraform-azurerm-caf-vnet-hub?ref=v1.0.0"

  # .... omitted

  # Multiple Subnets, Service delegation, Service Endpoints 
  subnets = {
    mgnt_subnet = {
      subnet_name           = "management"
      subnet_address_prefix = "10.1.2.0/24"

      service_endpoints     = ["Microsoft.Storage"]  
    }
  }

# ....omitted

}
```

## Subnet Service Endpoints

Subnet delegation enables you to designate a specific subnet for an Azure PaaS service of your choice that needs to be injected into your virtual network. The Subnet delegation provides full control to manage the integration of Azure services into virtual networks.

This module supports enabling the service delegation of your choosing under the virtual network and with the specified subnet.  For more information, check the [terraform resource documentation](https://www.terraform.io/docs/providers/azurerm/r/subnet.html#service_delegation).

```
module "vnet-hub" {
  source = "github.com/tietoevry-infra-as-code/terraform-azurerm-caf-vnet-hub?ref=v1.0.0"

  # .... omitted

  # Multiple Subnets, Service delegation, Service Endpoints 
  subnets = {
    mgnt_subnet = {
      subnet_name           = "management"
      subnet_address_prefix = "10.1.2.0/24"

      delegation = {
        name = "demodelegationcg"
        service_delegation = {
          name    = "Microsoft.ContainerInstance/containerGroups"
          actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
        }
      }
    }
  }

# ....omitted

}
```

## `enforce_private_link_endpoint_network_policies` - Private Link Endpoint on the subnet

Network policies, like network security groups (NSG), are not supported for Private Link Endpoints=. In order to deploy a Private Link Endpoint on a given subnet, you must set the `enforce_private_link_endpoint_network_policies` attribute to `true`. This setting is only applicable for the Private Link Endpoint, for all other resources in the subnet access is controlled based via the Network Security Group which can be configured using the `azurerm_subnet_network_security_group_association` resource. 

This module Enable or Disable network policies for the private link endpoint on the subnet. The default value is `false`. If you are enabling the Private Link Endpoints on the subnet you shouldn't use Private Link Services as it's conflicts. 

```
module "vnet-hub" {
  source = "github.com/tietoevry-infra-as-code/terraform-azurerm-caf-vnet-hub?ref=v1.0.0"

  # .... omitted

  # Multiple Subnets, Service delegation, Service Endpoints 
  subnets = {
    mgnt_subnet = {
      subnet_name           = "management"
      subnet_address_prefix = "10.1.2.0/24"
      enforce_private_link_endpoint_network_policies = true

        }
      }
    }
  }

# ....omitted

}
```

## `enforce_private_link_service_network_policies` - private link service on the subnet

In order to deploy a Private Link Service on a given subnet, you must set the `enforce_private_link_service_network_policies` attribute to `true`. This setting is only applicable for the Private Link Service, for all other resources in the subnet access is controlled based on the Network Security Group which can be configured using the `azurerm_subnet_network_security_group_association` resource.

This module Enable or Disable network policies for the private link service on the subnet. The default value is `false`. If you are enabling the Private Link service on the subnet then, you shouldn't use Private Link endpoints as it's conflicts. 

```
module "vnet-hub" {
  source = "github.com/tietoevry-infra-as-code/terraform-azurerm-caf-vnet-hub?ref=v1.0.0"

  # .... omitted

  # Multiple Subnets, Service delegation, Service Endpoints 
  subnets = {
    mgnt_subnet = {
      subnet_name           = "management"
      subnet_address_prefix = "10.1.2.0/24"
      enforce_private_link_service_network_policies = true

        }
      }
    }
  }

# ....omitted

}
```

## Network Watcher

This module handle the provision of Network Watcher. Note that you cannot create more than one network watcher resource per subscription in any region.

By default, this enabled to create the necessary resources in that region. You can exclude this from the Terraform plan using `create_network_watcher = false` argument in case you already have a network watcher available in your subscription.

## Network Security Groups

By default, the network security groups connected to Management and ApplicationGateway will only allow necessary traffic and block everything else (deny-all rule). Use `nsg_inbound_rules` and `nsg_outbound_rules` in this Terraform module to create a Network Security Group (NSG) for each subnet and allow it to add additional rules for inbound flows.

In the Source and Destination columns, `VirtualNetwork`, `AzureLoadBalancer`, and `Internet` are service tags, rather than IP addresses. In the protocol column, Any encompasses `TCP`, `UDP`, and `ICMP`. When creating a rule, you can specify `TCP`, `UDP`, `ICMP` or `*`. `0.0.0.0/0` in the Source and Destination columns represents all addresses.

*You cannot remove the default rules, but you can override them by creating rules with higher priorities.*

```
module "vnet-hub" {
  source = "github.com/tietoevry-infra-as-code/terraform-azurerm-caf-vnet-hub?ref=v1.0.0"

  # .... omitted

  # Multiple Subnets, Service delegation, Service Endpoints 
  subnets = {
    mgnt_subnet = {
      subnet_name           = "management"
      subnet_address_prefix = "10.1.2.0/24"

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
  }
}
```

## Azure Monitoring Diagnostics

Platform logs in Azure, including the Azure Activity log and resource logs, provide detailed diagnostic and auditing information for Azure resources and the Azure platform they depend on. Platform metrics are collected by default and typically stored in the Azure Monitor metrics database. This module enables to send all the logs and metrics to either storage account, event hub or Log Analytics workspace. 

## Peering

To peer spoke networks to the hub networks requires the service principal that performs the peering has `Network Contributor` role on hub network. Linking the Spoke to Hub DNS zones, the service principal also needs the `Private DNS Zone Contributor` role on hub network.

## Private DNS Zone

This module facilitates the private DNS zone for the virtual network.  To create a zone, set the domain name for the private DNS zone with variable `private_dns_zone_name`. This will additionally link the virtual network hub to the private DNS zone.  It will assign all principals that have peering access as contributors so, spokes can remain linked to the same zone.

## Recommended naming and tagging conventions
Well-defined naming and metadata tagging conventions help to quickly locate and manage resources. These conventions also help associate cloud usage costs with business teams via chargeback and show back accounting mechanisms.

> ### Resource naming 
An effective naming convention assembles resource names by using important resource information as parts of a resource's name. For example, using these [recommended naming conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging#example-names), a public IP resource for a production SharePoint workload is named like this: `pip-sharepoint-prod-westus-001`.

> ### Metadata tags
When applying metadata tags to the cloud resources, you can include information about those assets that couldn't be included in the resource name. You can use that information to perform more sophisticated filtering and reporting on resources. This information can be used by IT or business teams to find resources or generate reports about resource usage and billing.

The following list provides the recommended common tags that capture important context and information about resources. Use this list as a starting point to establish your tagging conventions.

Tag Name|Description|Key|Example Value|Required?
--------|-----------|---|-------------|---------|
Project Name|Name of the Project for the infra is created. This is mandatory to create a resource names.|ProjectName|{Project name}|Yes
Application Name|Name of the application, service, or workload the resource is associated with.|ApplicationName|{app name}|Yes
Approver|Name	Person responsible for approving costs related to this resource.|Approver|{email}|Yes
Business Unit|Top-level division of your company that owns the subscription or workload the resource belongs to. In smaller organizations, this may represent a single corporate or shared top-level organizational element.|BusinessUnit|FINANCE, MARKETING,{Product Name},CORP,SHARED|Yes
Cost Center|Accounting cost center associated with this resource.|CostCenter|{number}|Yes
Disaster Recovery|Business criticality of this application, workload, or service.|DR|Mission Critical, Critical, Essential|Yes
End Date of the Project|Date when this application, workload, or service is planned to be retired.|EndDate|{date}|No
Environment|Deployment environment of this application, workload, or service.|Env|Prod, Dev, QA, Stage, Test|Yes
Owner Name|Owner of the application, workload, or service.|Owner|{email}|Yes
Requester Name|User that requested the creation of this application.|Requestor|	{email}|Yes
Service Class|Service Level Agreement level of this application, workload, or service.|ServiceClass|Dev, Bronze, Silver, Gold|Yes
Start Date of the project|Date when this application, workload, or service was first deployed.|StartDate|{date}|No

> This module allows you to manage the above metadata tags directly or as a variable using `variables.tf`. All Azure resources which support tagging can be tagged by specifying key-values in argument `tags`. Tag `ResourceName` is added automatically to all resources. 

```
module "vnet-hub" {
  source = "github.com/tietoevry-infra-as-code/terraform-azurerm-caf-vnet-hub?ref=v1.0.0"
  create_resource_group   = true

  # ... omitted

  tags = {
    ProjectName  = "PublicCloud"
    Env          = "dev"
    Owner        = "user@example.com"
    BusinessUnit = "CORP"
    ServiceClass = "Gold"
  }
}
```

## Inputs

Name | Description | Type | Default
---- | ----------- | ---- | -------
`create_resource_group` | Whether to create resource group and use it for all networking resources | string | `"false"`
`resource_group_name` | The name of the resource group in which resources are created | string | `""`
`location`|The location of the resource group in which resources are created| string | `""`
`project_name`|The name of the project|string | `""`
`subscription_type`|Summary description of the purpose of the subscription that contains the resource. Often broken down by deployment environment type or specific workloads|string | `""`
`environment`|The stage of the development lifecycle for the workload that the resource supports|list |`{}`
`vnet_address_space`|Virtual Network address space to be used |list|`[]`
`create_ddos_plan` | Controls if DDoS protection plan should be created | string | `"false"`
`dns_servers` | List of DNS servers to use for virtual network | list |`[]`
`subnets`|For each subnet, create an object that contain fields|object|`{}`
`subnet_name`|A name of subnets inside virtual network| object |`{}`
`subnet_address_prefix`|A list of subnets address prefixes inside virtual network| 
`delegation`|defines a subnet delegation feature. takes an object as described in the following example|object|`{}`
`service_endpoints`|service endpoints for the virtual subnet|object|`{}`
`nsg_inbound_rule`|network security groups settings - a NSG is always created for each subnet|object|`{}`
`nsg_outbound_rule`|network security groups settings - a NSG is always created for each subnet|object|`{}`
`private_dns_zone_name`|The name of the Private DNS Zone. Must be a valid domain name to enable the resource creation|string|`""`
`create_network_watcher`|Controls if Network Watcher resources should be created for the Azure subscription |string|`"true"`
`enable_network_watcher_flow_logs`|Manages a Network Watcher Flow Logs|string|`"true"`
`log_analytics_workspace_sku`|The Sku of the Log Analytics Workspace. Possible values are `Free`, `PerNode`, `Premium`, `Standard`, `Standalone`, `Unlimited`, and `PerGB2018`|string|`PerGB2018`
`log_analytics_logs_retention_in_days`|The log analytics workspace data retention in days. Possible values range between `30` and `730`|number|`30`
`azure_monitor_logs_retention_in_days`|The Azure Monitoring data retention in days|number|`30`
`Tags`|A map of tags to add to all resources|map|`{}`

## Outputs

|Name | Description|
|---- | -----------|
`resource_group_name` | The name of the resource group in which resources are created
`resource_group_id` | The id of the resource group in which resources are created
`resource_group_location`| The location of the resource group in which resources are created
`virtual_network_name` | The name of the virtual network.
`virtual_network_id` |The virtual NetworkConfiguration ID.
`virtual_network_address_space` | List of address spaces that are used the virtual network.
`subnet_ids` | List of IDs of subnets
`subnet_address_prefixes` | List of address prefix for  subnets
`network_security_group_ids`|List of Network security groups and ids
`ddos_protection_plan_id` | Azure Network DDoS protection plan id
`network_watcher_id` | ID of Network Watcher
`route_table_name`|The resource id of the route table
`route_table_id`|The resource id of the route table
`private_dns_zone_name`|The resource name of Private DNS zones within Azure DNS
`private_dns_zone_id`|The resource id of Private DNS zones within Azure DNS
`storage_account_id`|The ID of the storage account
`storage_account_name`|The name of the storage account
`storage_primary_access_key`|The primary access key for the storage account
`log_analytics_workspace_name`|Specifies the name of the Log Analytics Workspace
`log_analytics_workspace_id`|The resource id of the Log Analytics Workspace
`log_analytics_logs_retention_in_days`|The workspace data retention in days. Possible values range between 30 and 730
`azure_monitor_logs_retention_in_days`|The Azure Monitoring data retention in days

## Resource Graph

![Resource Graph](graph.png)

## Authors

Module is maintained by [Kumaraswamy Vithanala](mailto:kumaraswamy.vithanala@tieto.com) with the help from other awesome contributors.

## Other resources

* [Hub-spoke network topology in Azure](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)

* [Terraform AzureRM Provider Documentation](https://www.terraform.io/docs/providers/azurerm/index.html)
