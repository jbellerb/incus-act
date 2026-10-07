locals {
  openbao_name    = "act-openbao"
  openbao_address = "https://${local.openbao_name}.incus:8200"
  cluster_address = "https://${local.openbao_name}.incus:8201"
}

resource "incus_instance" "act_openbao" {
  name     = local.openbao_name
  project  = var.incus_project
  remote   = var.incus_remote
  image    = "docker:openbao/openbao@sha256:6d2b93856e3fcf7b18ad855a0b51eaba474dc8b79cf554379ea32034797d2acf"
  type     = "container"
  profiles = ["default"]
  running  = true

  config = {
    "boot.autostart" = "true"
    # image entrypoint adds -config=/openbao/config
    "oci.entrypoint" = "/usr/local/bin/docker-entrypoint.sh server"
  }

  device {
    name = "eth0"
    type = "nic"

    properties = {
      name    = "eth0"
      network = "incusbr0"
    }
  }

  device {
    name = "act-openbao-config-volume"
    type = "disk"

    properties = {
      path     = "/openbao/config"
      pool     = var.incus_storage_pool
      readonly = "true"
      source   = incus_storage_volume.act_openbao_config.name
    }
  }

  device {
    name = "act-openbao-data-volume"
    type = "disk"

    properties = {
      path   = "/openbao/data"
      pool   = var.incus_storage_pool
      source = incus_storage_volume.act_openbao_data.name
    }
  }

  device {
    name = "act-openbao-seal-volume"
    type = "disk"

    properties = {
      path     = "/openbao/seal"
      pool     = var.incus_storage_pool
      readonly = "true"
      source   = incus_storage_volume.act_openbao_seal.name
    }
  }
}

resource "incus_storage_volume" "act_openbao_config" {
  name         = "act-openbao-config"
  pool         = var.incus_storage_pool
  project      = var.incus_project
  remote       = var.incus_remote
  type         = "custom"
  content_type = "filesystem"

  # restrict the volume root because it will also contain the TLS private key
  config = {
    "initial.uid"  = "100"
    "initial.gid"  = "1000"
    "initial.mode" = "0700"
  }

  file {
    content = templatefile("${path.module}/openbao/config/openbao.hcl.tftpl", {
      seal_key_id     = var.seal_key_id
      api_address     = local.openbao_address
      cluster_address = local.cluster_address
    })
    target_path = "/openbao.hcl"
    uid         = 100
    gid         = 1000
    mode        = "0644"
  }

  file {
    content     = var.ca_cert
    target_path = "/tls.crt"
    uid         = 100
    gid         = 1000
    mode        = "0644"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "incus_storage_volume" "act_openbao_data" {
  name         = "act-openbao-data"
  pool         = var.incus_storage_pool
  project      = var.incus_project
  remote       = var.incus_remote
  type         = "custom"
  content_type = "filesystem"

  # the image runs as openbao:openbao (100:1000)
  config = {
    "initial.uid"  = "100"
    "initial.gid"  = "1000"
    "initial.mode" = "0700"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "incus_storage_volume" "act_openbao_seal" {
  name         = "act-openbao-seal"
  pool         = var.incus_storage_pool
  project      = var.incus_project
  remote       = var.incus_remote
  type         = "custom"
  content_type = "filesystem"

  config = {
    "initial.uid"  = "100"
    "initial.gid"  = "1000"
    "initial.mode" = "0700"
  }

  lifecycle {
    prevent_destroy = true
  }
}
