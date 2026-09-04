terraform {
  required_version = ">= 1.10.0"

  required_providers {
    mist = {
      source  = "Juniper/mist"
      version = "~> 0.10.0"
    }
  }

  backend "local" {}
}

