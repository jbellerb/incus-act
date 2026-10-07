locals {
  buildkit_files = sort(tolist(setsubtract(
    fileset("${path.module}/buildkit", "**"),
    ["cloud-init.yaml", "network.yaml"],
  )))

  buildkit_cloud_init = "#cloud-config\n${yamlencode(merge(
    yamldecode(file("${path.module}/buildkit/cloud-init.yaml")),
    {
      write_files = [for filename in local.buildkit_files : {
        path        = "/${filename}"
        owner       = "root:root"
        permissions = startswith(filename, "usr/local/libexec/") ? "0755" : "0644"
        encoding    = "b64"
        content     = filebase64("${path.module}/buildkit/${filename}")
      }]
    },
  ))}"

  buildkit_revision = sha256(join(":", [
    filesha256("${path.module}/buildkit.tf"),
    sha256(local.buildkit_cloud_init),
    filesha256("${path.module}/buildkit/network.yaml"),
  ]))
  buildkit_name = "act-buildkit-${substr(local.buildkit_revision, 0, 12)}"
}

output "buildkit_instance" {
  description = "Current BuildKit instance name."
  value       = incus_instance.act_buildkit.name
}

resource "terraform_data" "act_buildkit_revision" {
  triggers_replace = local.buildkit_revision
}

resource "incus_instance" "act_buildkit" {
  name     = local.buildkit_name
  project  = var.incus_project
  remote   = var.incus_remote
  image    = "images:debian/trixie/cloud"
  type     = "container"
  profiles = ["default"]
  running  = true

  config = {
    "boot.autostart"            = "true"
    "cloud-init.user-data"      = local.buildkit_cloud_init
    "cloud-init.network-config" = trimspace(file("${path.module}/buildkit/network.yaml"))
    "security.nesting"          = "true"
    "security.privileged"       = "true"
    "user.incus-act.role"       = "buildkit"
    "user.incus-act.revision"   = local.buildkit_revision
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
    name = "act-client-tls"
    type = "disk"
    properties = {
      path   = "/var/lib/buildkit-tls/client"
      pool   = var.incus_storage_pool
      source = incus_storage_volume.act_buildkit_tls_client.name
    }
  }

  wait_for {
    type = "cloud-init"
  }

  lifecycle {
    # the scheduler marks us as activated when the job template is ready
    ignore_changes        = [config["user.incus-act.activated"]]
    replace_triggered_by  = [terraform_data.act_buildkit_revision]
    create_before_destroy = true
    destroy               = false
  }
}

resource "incus_storage_volume" "act_buildkit_tls_client" {
  name         = "${local.buildkit_name}-client-tls"
  pool         = var.incus_storage_pool
  project      = var.incus_project
  remote       = var.incus_remote
  type         = "custom"
  content_type = "filesystem"

  config = {
    "initial.uid"      = "0"
    "initial.gid"      = "0"
    "initial.mode"     = "0700"
    "security.shifted" = "true"
  }

  lifecycle {
    # Retain activation evidence for cleanup retries after instance deletion.
    ignore_changes        = [config["user.incus-act.activated"]]
    replace_triggered_by  = [terraform_data.act_buildkit_revision]
    create_before_destroy = true
    destroy               = false
  }
}
