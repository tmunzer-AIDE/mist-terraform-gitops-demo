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
    }
  }
}

