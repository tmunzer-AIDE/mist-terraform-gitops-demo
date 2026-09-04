resource "mist_org_networktemplate" "campus" {
  name   = "campus-switches"
  org_id = mist_org.demo.id

  dhcp_snooping = {
    all_networks           = false
    enable_arp_spoof_check = true
    enable_ip_source_guard = true
    enabled                = true
    networks               = ["admin", "user", "vip", "guest"]
  }

  mist_nac = {
    enabled = true
    network = "mgmt"
  }

  networks = {
    guest = {
      vlan_id = "{{vlan_guest}}"
    }
    user = {
      vlan_id = "{{vlan_user}}"
    }
    admin = {
      vlan_id = "{{vlan_admin}}"
    }
    vip = {
      vlan_id = "{{vlan_vip}}"
    }
    mgmt = {
      vlan_id = "{{vlan_mgmt}}"
    }
  }

  port_usages = {
    disabled = {
      disabled     = true
      mode         = "access"
      port_network = "default"
    }
    access = {
      enable_mac_auth = true
      mode            = "access"
      port_auth       = "dot1x"
      port_network    = "guest"
      stp_edge        = true
    }
    ap = {
      mode     = "trunk"
      networks = ["guest", "user", "admin", "vip", "mgmt"]
    }
  }

  switch_matching = {
    enable = true
    rules = [
      {
        match_role = "access"
        name       = "access-switch"
        port_config = {
          "ge-0/0/0-9" = {
            usage = "access"
          }
          "ge-0/0/10-19" = {
            usage = "ap"
          }
          "ge-0/0/20-23" = {
            usage = "uplink"
          }
        }
      }
    ]
  }
}

