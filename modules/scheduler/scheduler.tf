locals {
  scheduler_files = merge({
    for filename in fileset("${path.module}/scheduler", "**") :
    filename => file("${path.module}/scheduler/${filename}")
    if !contains(["cloud-init.yaml", "network.yaml"], filename) && !endswith(filename, ".tftpl")
    }, {
    "etc/incus/config.yml" = yamlencode({
      default-remote = var.incus_remote
      remotes = {
        (var.incus_remote) = {
          auth_type = "tls"
          project   = var.incus_project
          protocol  = "incus"
          public    = false
          addr      = var.incus_address
        }
      }
      aliases = {}
    })
    "etc/incus/server.crt" = var.incus_server_cert
    "etc/openbao/tls.crt"  = var.openbao_ca_cert
    "etc/systemd/system/openbao-credential-broker.service" = templatefile(
      "${path.module}/scheduler/etc/systemd/system/openbao-credential-broker.service.tftpl",
      {
        openbao_address           = var.openbao_address
        scheduler_approle_backend = var.scheduler_approle_backend
        task_approle_backend      = var.task_approle_backend
      },
    )
    "etc/openbao/credential-broker.d/defaults.toml" = templatefile(
      "${path.module}/scheduler/etc/openbao/credential-broker.d/defaults.toml.tftpl",
      { secret_mount = var.secret_mount },
    )
  }, var.scheduler_files)

  scheduler_cloud_init = "#cloud-config\n${yamlencode(merge(
    yamldecode(file("${path.module}/scheduler/cloud-init.yaml")),
    {
      runcmd = concat(yamldecode(file("${path.module}/scheduler/cloud-init.yaml")).runcmd, var.scheduler_commands)
      write_files = [for filename, content in local.scheduler_files : {
        path        = "/${filename}"
        owner       = "root:root"
        permissions = startswith(filename, "usr/local/libexec/") ? "0755" : "0644"
        encoding    = "b64"
        content     = base64encode(content)
      } if !contains(["cloud-init.yaml", "network.yaml"], filename)]
    },
  ))}"

  scheduler_revision = sha256(join("", [
    filesha256("${path.module}/scheduler.tf"),
    sha256(local.scheduler_cloud_init),
    filesha256("${path.module}/scheduler/network.yaml"),
  ]))
}

resource "terraform_data" "act_scheduler_revision" {
  triggers_replace = local.scheduler_revision
}

resource "incus_instance" "act_scheduler" {
  name     = "act-scheduler"
  project  = var.incus_project
  remote   = var.incus_remote
  image    = "images:debian/trixie/cloud"
  type     = "container"
  profiles = ["default"]
  running  = true

  config = {
    "boot.autostart"                 = "true"
    "cloud-init.user-data"           = local.scheduler_cloud_init
    "cloud-init.network-config"      = trimspace(file("${path.module}/scheduler/network.yaml"))
    "user.incus-act.runner-template" = var.job_runner_template
    "user.incus-act.role"            = "scheduler"
    "user.incus-act.revision"        = local.scheduler_revision
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
    name = "act-tasks-root-volume"
    type = "disk"

    properties = {
      path   = "/root"
      pool   = var.incus_storage_pool
      source = var.tasks_root_volume
    }
  }

  device {
    name = "act-openbao-broker-key-volume"
    type = "disk"

    properties = {
      path     = "/var/lib/openbao-broker-key"
      pool     = var.incus_storage_pool
      readonly = "true"
      source   = incus_storage_volume.act_scheduler_broker_auth.name
    }
  }

  device {
    name = "act-job-results"
    type = "disk"
    properties = {
      path   = "/var/log/task-jobs"
      pool   = var.incus_storage_pool
      source = var.job_results_volume
    }
  }

  wait_for {
    type = "cloud-init"
  }

  depends_on = [
    vault_approle_auth_backend_role.act_scheduler_broker,
    vault_kv_secret_v2.act_scheduler_incus,
  ]

  lifecycle {
    replace_triggered_by  = [terraform_data.act_scheduler_revision]
    create_before_destroy = false
    destroy               = true
  }
}

resource "incus_storage_volume" "act_scheduler_broker_auth" {
  name         = "act-scheduler-broker-auth"
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
    prevent_destroy = true
  }
}

resource "vault_policy" "act_scheduler_broker" {
  name   = "scheduler-broker"
  policy = <<-HCL
    path "${var.secret_mount}/data/scheduler/incus" {
      capabilities = ["read"]
    }
    path "${var.secret_mount}/data/tasks/*" {
      capabilities = ["read"]
    }
    path "${var.secret_mount}/metadata/tasks/*" {
      capabilities = ["read"]
    }
    path "auth/${var.task_approle_backend}/role/+/secret-id" {
      capabilities = ["update"]
    }
  HCL
}

resource "vault_approle_auth_backend_role" "act_scheduler_broker" {
  backend                 = var.scheduler_approle_backend
  role_name               = "scheduler-broker"
  role_id                 = "scheduler-broker"
  bind_secret_id          = true
  secret_id_num_uses      = 0
  secret_id_ttl           = 0
  token_policies          = [vault_policy.act_scheduler_broker.name]
  token_no_default_policy = true
  token_ttl               = 3600
  token_max_ttl           = 86400
}

ephemeral "tls_private_key" "act_scheduler" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "act_scheduler" {
  private_key_pem_wo         = ephemeral.tls_private_key.act_scheduler.private_key_pem
  private_key_pem_wo_version = 1
  validity_period_hours      = 87600
  early_renewal_hours        = 720
  allowed_uses               = ["digital_signature", "client_auth"]

  subject {
    common_name = "act-scheduler.incus"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "incus_certificate" "act_scheduler" {
  name        = "act-scheduler"
  remote      = var.incus_remote
  certificate = tls_self_signed_cert.act_scheduler.cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "vault_kv_secret_v2" "act_scheduler_incus" {
  mount = var.secret_mount
  name  = "scheduler/incus"
  data_json_wo = jsonencode({
    incus-client = jsonencode({
      certificate = tls_self_signed_cert.act_scheduler.cert_pem
      private_key = ephemeral.tls_private_key.act_scheduler.private_key_pem
    })
  })
  # update the saved pair whenever the public certificate changes
  data_json_wo_version = parseint(
    substr(sha256(tls_self_signed_cert.act_scheduler.cert_pem), 0, 12),
    16,
  )

  depends_on = [incus_certificate.act_scheduler]

  lifecycle {
    prevent_destroy = true
  }
}
