resource "mist_site" "demo" {
  for_each = local.sites

  org_id       = mist_org.demo.id
  name         = each.value.name
  address      = each.value.address
  country_code = each.value.country_code
  timezone     = each.value.timezone

  sitegroup_ids = [
    mist_org_sitegroup.region_emea.id,
    mist_org_sitegroup.wlan_corp.id,
    mist_org_sitegroup.wlan_guest.id,
  ]

  networktemplate_id = mist_org_networktemplate.campus.id
  rftemplate_id      = mist_org_rftemplate.campus.id
}

resource "mist_site_setting" "demo" {
  for_each = local.sites

  site_id = mist_site.demo[each.key].id
  vars = {
    vlan_admin = each.value.vlan_admin
    vlan_guest = each.value.vlan_guest
    vlan_mgmt  = each.value.vlan_mgmt
    vlan_user  = each.value.vlan_user
    vlan_vip   = each.value.vlan_vip
  }
}

