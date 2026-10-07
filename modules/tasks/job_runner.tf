locals {
  job_runner_files = sort(tolist(setsubtract(
    fileset("${path.module}/job-runner", "**"),
    ["cloud-init.yaml"],
  )))

  job_runner_cloud_init = "#cloud-config\n${yamlencode(merge(
    yamldecode(file("${path.module}/job-runner/cloud-init.yaml")),
    {
      write_files = [for filename in local.job_runner_files : {
        path        = "/${filename}"
        owner       = "root:root"
        permissions = startswith(filename, "usr/local/libexec/") ? "0755" : "0644"
        encoding    = "b64"
        content     = filebase64("${path.module}/job-runner/${filename}")
      }]
    },
  ))}"

  job_runner_revision = sha256(join(":", [
    filesha256("${path.module}/job_runner.tf"),
    sha256(local.job_runner_cloud_init),
  ]))
}

resource "incus_instance" "act_job_runner_template" {
  name     = "act-job-runner-template"
  project  = var.incus_project
  remote   = var.incus_remote
  image    = "images:debian/trixie/cloud"
  type     = "container"
  profiles = ["default"]
  running  = true

  config = {
    "boot.autostart"            = "false"
    "cloud-init.user-data"      = local.job_runner_cloud_init
    "environment.HOME"          = "/tmp/job-runner-home"
    "environment.BUILDKIT_ADDR" = "tcp://${local.buildkit_name}.incus:1234"
    "user.incus-act.role"       = "job-runner"
    "user.incus-act.builder"    = local.buildkit_name
    "user.incus-act.scheduler"  = "act-scheduler"
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
    name = "act-tasks-root"
    type = "disk"
    properties = {
      path     = "/root"
      pool     = var.incus_storage_pool
      readonly = "true"
      source   = incus_storage_volume.act_tasks_root.name
    }
  }

  device {
    name = "act-client-tls"
    type = "disk"
    properties = {
      path     = "/etc/buildkit-client"
      pool     = var.incus_storage_pool
      readonly = "true"
      source   = incus_storage_volume.act_buildkit_tls_client.name
    }
  }

  device {
    name = "act-secrets-tmpfs"
    type = "disk"
    properties = {
      path           = "/tmp"
      source         = "tmpfs:"
      size           = "64MiB"
      "initial.mode" = "1777"
    }
  }

  device {
    name = "act-job-results"
    type = "disk"
    properties = {
      path   = "/var/log/task-jobs"
      pool   = var.incus_storage_pool
      source = incus_storage_volume.act_job_results.name
    }
  }

  depends_on = [incus_instance.act_buildkit]

  wait_for {
    type = "cloud-init"
  }

  provisioner "local-exec" {
    # stop the instance after cloud-init finishes so clones are pre-initialized.
    # Disable cloud-init after the wait completes; clones have new instance ids.
    command = <<-SH
      incus exec --project '${self.project}' '${self.remote}:${self.name}' -- touch /etc/cloud/cloud-init.disabled
      incus stop --project '${self.project}' '${self.remote}:${self.name}'
    SH
  }

  lifecycle {
    ignore_changes       = [running]
    replace_triggered_by = [terraform_data.act_job_runner_revision]
  }
}

resource "terraform_data" "act_job_runner_revision" {
  triggers_replace = local.job_runner_revision
}

resource "incus_storage_volume" "act_job_results" {
  name         = "act-task-job-results"
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
