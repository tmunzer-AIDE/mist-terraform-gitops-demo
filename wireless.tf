resource "mist_org_rftemplate" "campus" {
  name          = "campus-rf"
  org_id        = mist_org.demo.id
  band_24_usage = "auto"

  band_24 = {
    bandwidth = 20
    power_max = 15
    power_min = 10
  }

  band_5 = {
    bandwidth = 40
    channels  = [60, 104, 132]
  }
}

resource "mist_org_wlantemplate" "corp" {
  name   = "corporate"
  org_id = mist_org.demo.id

  applies = {
    sitegroup_ids = [mist_org_sitegroup.wlan_corp.id]
  }
}

resource "mist_org_wlan" "corp" {
  org_id       = mist_org.demo.id
  template_id  = mist_org_wlantemplate.corp.id
  ssid         = "corp"
  bands        = ["5", "6"]
  roam_mode    = "11r"
  vlan_enabled = true

  auth = {
    type = "eap"
  }

  mist_nac = {
    enabled = true
  }

  dynamic_vlan = {
    default_vlan_ids = ["{{vlan_user}}"]
    enabled          = true
    type             = "standard"
    vlans = {
      "{{vlan_admin}}" = ""
      "{{vlan_user}}"  = ""
      "{{vlan_vip}}"   = ""
    }
  }

  rateset = {
    "5" = {
      template = "high-density"
    }
    "6" = {
      template = "high-density"
    }
  }
}

resource "mist_org_wlantemplate" "guest" {
  name   = "guest"
  org_id = mist_org.demo.id

  applies = {
    sitegroup_ids = [mist_org_sitegroup.wlan_guest.id]
  }
}

resource "mist_org_wlan" "guest" {
  org_id       = mist_org.demo.id
  template_id  = mist_org_wlantemplate.guest.id
  ssid         = "guest"
  bands        = ["24"]
  vlan_enabled = true
  vlan_id      = "{{vlan_guest}}"

  auth = {
    type = "open"
  }

  portal = {
    email_enabled = true
    enabled       = true
    expire        = 60
  }

  rateset = {
    "24" = {
      min_rssi = 0
      template = "high-density"
    }
  }
}

resource "mist_org_wxtag" "private_networks" {
  org_id = mist_org.demo.id
  name   = "RFC1918"
  type   = "match"
  match  = "ip_range_subnet"
  op     = "in"
  values = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

resource "mist_org_wxrule" "guest_private_networks" {
  org_id      = mist_org.demo.id
  template_id = mist_org_wlantemplate.guest.id
  order       = 1
  action      = "block"
  enabled     = true

  dst_deny_wxtags = [mist_org_wxtag.private_networks.id]
}

