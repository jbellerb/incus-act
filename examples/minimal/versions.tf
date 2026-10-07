terraform {
  required_version = ">= 1.12.0, < 2.0.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "~> 1.2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.4.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.12.0"
    }
  }
}

provider "incus" {
  default_remote = var.incus_remote

  remote {
    name     = "images"
    address  = "https://images.linuxcontainers.org"
    protocol = "simplestreams"
    public   = true
  }

  remote {
    name     = "docker"
    address  = "https://docker.io"
    protocol = "oci"
    public   = true
  }
}

provider "vault" {
  address = var.openbao_address
}
