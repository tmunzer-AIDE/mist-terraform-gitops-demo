resource "mist_site" "demo" {
  for_each = local.sites

  org_id       = mist_org.demo.id
  name         = each.value.name
  address      = each.value.address
  country_code = each.value.country_code
  timezone     = each.value.timezone

  notes = each.value.role == "hub" ? "SD-WAN hub data center" : "SD-WAN branch spoke"

  sitegroup_ids = concat(
    [mist_org_sitegroup.region_emea.id],
    each.value.role == "hub" ? [
      mist_org_sitegroup.wan_hubs.id,
      ] : [
      mist_org_sitegroup.wan_spokes.id,
      mist_org_sitegroup.wlan_corp.id,
      mist_org_sitegroup.wlan_guest.id,
    ],
  )

  gatewaytemplate_id = each.value.role == "spoke" ? mist_org_gatewaytemplate.branch.id : null
  networktemplate_id = each.value.role == "spoke" ? mist_org_networktemplate.campus.id : null
  rftemplate_id      = each.value.role == "spoke" ? mist_org_rftemplate.campus.id : null

  lifecycle {
    precondition {
      condition     = contains(["hub", "spoke"], each.value.role)
      error_message = "Site ${each.key} has unsupported role '${each.value.role}'. Expected 'hub' or 'spoke'."
    }
  }
}

resource "mist_site_setting" "demo" {
  for_each = local.sites

  site_id = mist_site.demo[each.key].id
  vars = {
    for key, value in {
      dc_lan_gateway  = each.value.dc_lan_gateway
      site_network_id = each.value.site_network_id
      site_role       = each.value.role
      vlan_admin      = each.value.vlan_admin
      vlan_guest      = each.value.vlan_guest
      vlan_mgmt       = each.value.vlan_mgmt
      vlan_user       = each.value.vlan_user
      vlan_vip        = each.value.vlan_vip
      wan1_gateway    = each.value.wan1_gateway
      wan1_ip         = each.value.wan1_ip
      wan1_prefix     = each.value.wan1_prefix
      wan2_gateway    = each.value.wan2_gateway
      wan2_ip         = each.value.wan2_ip
      wan2_prefix     = each.value.wan2_prefix
    } : key => value if value != ""
  }
}
