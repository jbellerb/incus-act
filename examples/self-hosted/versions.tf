terraform {
  required_version = ">= 1.12.0, < 2.0.0"

  backend "s3" {
    bucket                      = "act-opentofu-state"
    key                         = "cluster.tfstate"
    region                      = "us-east-1"
    endpoints                   = { s3 = var.s3_endpoint }
    use_lockfile                = true
    use_path_style              = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }

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

provider "vault" {}
