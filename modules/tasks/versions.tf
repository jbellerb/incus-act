terraform {
  required_version = ">= 1.12.0, < 2.0.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "~> 1.2.0"
    }
  }
}
