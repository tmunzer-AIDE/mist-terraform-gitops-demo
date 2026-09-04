locals {
  overlay_name = "Corporate-Overlay"

  hub_profiles = {
    paris = {
      name         = "DC-Paris-Hub"
      network_name = "dc-paris-services"
      subnet       = "10.200.10.0/24"
    }
    frankfurt = {
      name         = "DC-Frankfurt-Hub"
      network_name = "dc-frankfurt-services"
      subnet       = "10.200.20.0/24"
    }
  }

  hub_vpn_paths = merge([
    for hub in values(local.hub_profiles) : {
      "${hub.name}-WAN1" = {
        bfd_profile = "broadband"
        pod         = 1
      }
      "${hub.name}-WAN2" = {
        bfd_profile = "broadband"
        pod         = 1
      }
    }
  ]...)
}

resource "mist_org_vpn" "corporate" {
  org_id = mist_org.demo.id
  name   = local.overlay_name
  type   = "hub_spoke"

  path_selection = {
    strategy = "simple"
  }

  paths = local.hub_vpn_paths
}

resource "mist_org_network" "branch_lan" {
  depends_on = [mist_org_vpn.corporate]

  org_id                 = mist_org.demo.id
  name                   = "branch-lan"
  subnet                 = "10.10.{{site_network_id}}.0/24"
  vlan_id                = "{{vlan_user}}"
  disallow_mist_services = false

  vpn_access = {
    (local.overlay_name) = {
      routed                     = true
      no_readvertise_to_lan_bgp  = false
      no_readvertise_to_lan_ospf = false
      no_readvertise_to_overlay  = false
    }
  }
}

resource "mist_org_network" "dc_services" {
  for_each   = local.hub_profiles
  depends_on = [mist_org_vpn.corporate]

  org_id                 = mist_org.demo.id
  name                   = each.value.network_name
  subnet                 = each.value.subnet
  disallow_mist_services = false

  vpn_access = {
    (local.overlay_name) = {
      routed                     = true
      no_readvertise_to_lan_bgp  = false
      no_readvertise_to_lan_ospf = false
      no_readvertise_to_overlay  = false
    }
  }
}

resource "mist_org_service" "branch_networks" {
  org_id       = mist_org.demo.id
  name         = "branch-networks"
  type         = "custom"
  addresses    = ["10.10.0.0/16"]
  traffic_type = "default"

  specs = [{
    protocol = "any"
  }]
}

resource "mist_org_service" "dc_services" {
  org_id       = mist_org.demo.id
  name         = "dc-services"
  type         = "custom"
  addresses    = [for hub in values(local.hub_profiles) : hub.subnet]
  traffic_type = "default"

  specs = [{
    protocol = "any"
  }]
}

resource "mist_org_service" "internet" {
  org_id       = mist_org.demo.id
  name         = "public-internet"
  type         = "custom"
  addresses    = ["0.0.0.0/0"]
  traffic_type = "default"

  specs = [{
    protocol = "any"
  }]
}

resource "mist_org_deviceprofile_gateway" "hub" {
  for_each   = local.hub_profiles
  depends_on = [mist_org_vpn.corporate]

  org_id       = mist_org.demo.id
  name         = each.value.name
  dns_servers  = ["1.1.1.1", "9.9.9.9"]
  ntp_servers  = ["0.pool.ntp.org", "1.pool.ntp.org"]
  dns_override = true
  ntp_override = true

  port_config = {
    "ge-0/0/0" = {
      usage    = "wan"
      name     = "WAN1"
      wan_type = "broadband"

      ip_config = {
        type    = "static"
        ip      = "{{wan1_ip}}"
        netmask = "/{{wan1_prefix}}"
        gateway = "{{wan1_gateway}}"
      }

      vpn_paths = {
        (format("%s-WAN1.%s", each.value.name, local.overlay_name)) = {
          role        = "hub"
          bfd_profile = "broadband"
        }
      }

      wan_source_nat = {
        disabled = false
      }
    }

    "ge-0/0/1" = {
      usage    = "wan"
      name     = "WAN2"
      wan_type = "broadband"

      ip_config = {
        type    = "static"
        ip      = "{{wan2_ip}}"
        netmask = "/{{wan2_prefix}}"
        gateway = "{{wan2_gateway}}"
      }

      vpn_paths = {
        (format("%s-WAN2.%s", each.value.name, local.overlay_name)) = {
          role        = "hub"
          bfd_profile = "broadband"
        }
      }

      wan_source_nat = {
        disabled = false
      }
    }

    "ge-0/0/2" = {
      usage    = "lan"
      networks = [mist_org_network.dc_services[each.key].name]
    }
  }

  ip_configs = {
    (mist_org_network.dc_services[each.key].name) = {
      type    = "static"
      ip      = "{{dc_lan_gateway}}"
      netmask = "/24"
    }
  }

  path_preferences = {
    branch_overlay = {
      strategy = "ordered"
      paths = [
        {
          type = "vpn"
          name = format("%s-WAN1.%s", each.value.name, local.overlay_name)
        },
        {
          type = "vpn"
          name = format("%s-WAN2.%s", each.value.name, local.overlay_name)
        },
      ]
    }
    internet = {
      strategy = "ecmp"
      paths = [
        {
          type = "wan"
          name = "WAN1"
        },
        {
          type = "wan"
          name = "WAN2"
        },
      ]
    }
    local_services = {
      strategy = "ordered"
      paths = [{
        type     = "local"
        networks = [mist_org_network.dc_services[each.key].name]
      }]
    }
  }

  service_policies = [
    {
      name            = "branches-to-services"
      tenants         = [mist_org_network.branch_lan.name]
      services        = [mist_org_service.dc_services.name]
      action          = "allow"
      path_preference = "local_services"
    },
    {
      name            = "services-to-branches"
      tenants         = [mist_org_network.dc_services[each.key].name]
      services        = [mist_org_service.branch_networks.name]
      action          = "allow"
      path_preference = "branch_overlay"
    },
    {
      name            = "centralized-internet"
      tenants         = [mist_org_network.branch_lan.name]
      services        = [mist_org_service.internet.name]
      action          = "allow"
      path_preference = "internet"
    },
  ]
}

resource "mist_org_gatewaytemplate" "branch" {
  depends_on = [mist_org_vpn.corporate]

  org_id      = mist_org.demo.id
  name        = "Branch-Spoke"
  type        = "spoke"
  dns_servers = ["1.1.1.1", "9.9.9.9"]
  ntp_servers = ["0.pool.ntp.org", "1.pool.ntp.org"]

  port_config = {
    "ge-0/0/0" = {
      usage       = "wan"
      name        = "WAN1"
      description = "Primary broadband uplink"
      wan_type    = "broadband"

      ip_config = {
        type = "dhcp"
      }

      vpn_paths = {
        (format("%s-WAN1.%s", local.hub_profiles.paris.name, local.overlay_name)) = {
          role        = "spoke"
          bfd_profile = "broadband"
          preference  = 10
        }
        (format("%s-WAN1.%s", local.hub_profiles.frankfurt.name, local.overlay_name)) = {
          role        = "spoke"
          bfd_profile = "broadband"
          preference  = 20
        }
      }

      wan_source_nat = {
        disabled = false
      }
    }

    "ge-0/0/1" = {
      usage       = "wan"
      name        = "WAN2"
      description = "Secondary broadband uplink"
      wan_type    = "broadband"

      ip_config = {
        type = "dhcp"
      }

      vpn_paths = {
        "DC-Paris-Hub-WAN2.Corporate-Overlay" = {
          role        = "spoke"
          bfd_profile = "broadband"
          preference  = 30
        }
        "DC-Frankfurt-Hub-WAN2.Corporate-Overlay" = {
          role        = "spoke"
          bfd_profile = "broadband"
          preference  = 40
        }
      }

      wan_source_nat = {
        disabled = false
      }
    }

    "ge-0/0/2" = {
      usage        = "lan"
      networks     = [mist_org_network.branch_lan.name]
      port_network = mist_org_network.branch_lan.name
    }
  }

  ip_configs = {
    (mist_org_network.branch_lan.name) = {
      type    = "static"
      ip      = "10.10.{{site_network_id}}.1"
      netmask = "/24"
    }
  }

  dhcpd_config = {
    enabled = true
    config = {
      (mist_org_network.branch_lan.name) = {
        type        = "local"
        gateway     = "10.10.{{site_network_id}}.1"
        ip_start    = "10.10.{{site_network_id}}.100"
        ip_end      = "10.10.{{site_network_id}}.199"
        dns_servers = ["1.1.1.1", "9.9.9.9"]
      }
    }
  }

  path_preferences = {
    dc_overlay = {
      strategy = "ordered"
      paths = [
        {
          type = "vpn"
          name = "DC-Paris-Hub-WAN1.Corporate-Overlay"
        },
        {
          type = "vpn"
          name = "DC-Frankfurt-Hub-WAN1.Corporate-Overlay"
        },
        {
          type = "vpn"
          name = "DC-Paris-Hub-WAN2.Corporate-Overlay"
        },
        {
          type = "vpn"
          name = "DC-Frankfurt-Hub-WAN2.Corporate-Overlay"
        },
      ]
    }
    local_internet = {
      strategy = "ecmp"
      paths = [
        {
          type = "wan"
          name = "WAN1"
        },
        {
          type = "wan"
          name = "WAN2"
        },
      ]
    }
    local_lan = {
      strategy = "ordered"
      paths = [{
        type     = "local"
        networks = [mist_org_network.branch_lan.name]
      }]
    }
  }

  service_policies = [
    {
      name            = "branches-to-dc"
      tenants         = [mist_org_network.branch_lan.name]
      services        = [mist_org_service.dc_services.name]
      action          = "allow"
      path_preference = "dc_overlay"
    },
    {
      name            = "dc-to-branches"
      tenants         = [for network in mist_org_network.dc_services : network.name]
      services        = [mist_org_service.branch_networks.name]
      action          = "allow"
      path_preference = "local_lan"
    },
    {
      name            = "direct-internet"
      tenants         = [mist_org_network.branch_lan.name]
      services        = [mist_org_service.internet.name]
      action          = "allow"
      path_preference = "local_internet"
    },
  ]
}
