resource "mist_org" "demo" {
  name = var.org_name
}

resource "mist_org_sitegroup" "region_emea" {
  org_id = mist_org.demo.id
  name   = "EMEA"
}

resource "mist_org_sitegroup" "wlan_corp" {
  org_id = mist_org.demo.id
  name   = "WLAN-Corp"
}

resource "mist_org_sitegroup" "wlan_guest" {
  org_id = mist_org.demo.id
  name   = "WLAN-Guest"
}

