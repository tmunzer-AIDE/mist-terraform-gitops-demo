variable "org_name" {
  description = "Name of the Mist organization created for the demo."
  type        = string
  default     = "Terraform GitOps Demo"
}

variable "sites_file" {
  description = "CSV file containing the sites and their site variables."
  type        = string
  default     = "data/sites.csv"
}

