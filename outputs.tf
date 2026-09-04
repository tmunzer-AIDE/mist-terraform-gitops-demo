output "organization_id" {
  description = "ID of the Mist organization managed by this configuration."
  value       = mist_org.demo.id
}

output "sites" {
  description = "Mist site IDs keyed by the stable CSV site key."
  value = {
    for key, site in mist_site.demo : key => {
      id   = site.id
      name = site.name
      role = local.sites[key].role
    }
  }
}

output "wan_topology" {
  description = "IDs of the Mist WAN objects created for the hub-and-spoke topology."
  value = {
    hub_profiles = {
      for key, profile in mist_org_deviceprofile_gateway.hub : key => profile.id
    }
    overlay_vpn            = mist_org_vpn.corporate.id
    spoke_gateway_template = mist_org_gatewaytemplate.branch.id
  }
}
