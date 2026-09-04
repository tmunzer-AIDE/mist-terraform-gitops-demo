locals {
  sites = {
    for site in csvdecode(file("${path.module}/${var.sites_file}")) :
    site.site_key => site
  }
}

