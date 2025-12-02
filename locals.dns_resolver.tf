locals {
  private_dns_resolver_enabled = { for key, value in var.hub_virtual_networks : key => value.enabled_resources.private_dns_resolver }
}

locals {
  private_dns_resolver = { for key, value in var.hub_virtual_networks : key => {
    name                = coalesce(value.private_dns_resolver.name, local.default_names[key].private_dns_resolver_name)
    location            = value.location
    resource_group_name = coalesce(value.private_dns_resolver.resource_group_name, local.hub_virtual_networks_resource_group_names[key])
    inbound_endpoints = local.private_dns_zones_enabled[key] && value.private_dns_resolver.default_inbound_endpoint_enabled ? merge(tomap({
      dns = {
        name                         = "dns"
        subnet_name                  = module.hub_and_spoke_vnet.virtual_networks[key].subnets["${key}-dns_resolver"].name
        private_ip_allocation_method = "Static"
        private_ip_address           = local.private_dns_resolver_ip_addresses[key]
        tags                         = coalesce(value.private_dns_resolver.tags, var.tags, {})
        merge_with_module_tags       = false
      }
    }), value.private_dns_resolver.inbound_endpoints) : value.private_dns_resolver.inbound_endpoints
    outbound_endpoints = local.private_dns_zones_enabled[key] && value.private_dns_resolver.default_outbound_endpoint_enabled ? merge(tomap({
      "dns-outbound" = {
        name                   = "dns-outbound"
        subnet_name            = module.hub_and_spoke_vnet.virtual_networks[key].subnets["${key}-dns_resolver_outbound"].name
        tags                   = coalesce(value.private_dns_resolver.tags, var.tags, {})
        merge_with_module_tags = false
        forwarding_ruleset = {
          "default-outbound-ruleset" = {
            name                                        = "default-ruleset"
            link_with_outbound_endpoint_virtual_network = true
            tags                                        = coalesce(value.private_dns_resolver.tags, var.tags, {})
            merge_with_module_tags                      = false
            additional_virtual_network_links            = {}
            rules = {}
          }
        }
      }
    }), value.private_dns_resolver.outbound_endpoints) : value.private_dns_resolver.outbound_endpoints
    tags = coalesce(value.private_dns_resolver.tags, var.tags, {})
    } if local.private_dns_resolver_enabled[key]
  }
  private_dns_resolver_ip_addresses = { for key, value in var.hub_virtual_networks : key =>
    (value.private_dns_resolver.ip_address == null ?
      cidrhost(coalesce(value.private_dns_resolver.subnet_address_prefix, local.virtual_network_subnet_default_ip_prefixes[key]["dns_resolver"]), 4) :
    value.private_dns_resolver.ip_address) if local.private_dns_resolver_enabled[key]
  }
  private_dns_resolver_outbound_ip_addresses = { for key, value in var.hub_virtual_networks : key =>
    (value.private_dns_resolver.outbound_ip_address == null ?
      cidrhost(coalesce(value.private_dns_resolver.outbound_subnet_address_prefix, local.virtual_network_subnet_default_ip_prefixes[key]["dns_resolver_outbound"]), 4) :
    value.private_dns_resolver.outbound_ip_address) if local.private_dns_resolver_enabled[key] && value.private_dns_resolver.default_outbound_endpoint_enabled
  }
}
