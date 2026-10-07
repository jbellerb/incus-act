output "scheduler_files" {
  value = merge({
    for filename in fileset("${path.module}/scheduler", "**") :
    filename => file("${path.module}/scheduler/${filename}")
    if !endswith(filename, ".tftpl")
    }, {
    "etc/openbao/credential-broker.d/opentofu.toml" = templatefile(
      "${path.module}/scheduler/etc/openbao/credential-broker.d/opentofu.toml.tftpl",
      { secret_mount = var.secret_mount },
    )
    "root/task-opentofu/config.yml" = yamlencode({
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
    "root/task-opentofu/server.crt"              = var.incus_server_cert
    "root/task-opentofu/openbao-address"         = var.openbao_address
    "root/task-opentofu/openbao-approle-backend" = var.task_approle_backend
  })
  depends_on = [vault_kv_secret_v2.act_opentofu_incus]
}
