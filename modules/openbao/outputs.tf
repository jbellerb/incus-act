output "scheduler_approle_backend" {
  value = vault_auth_backend.act_approle.path
}

output "secret_mount" {
  value = vault_mount.act_secret.path
}

output "task_approle_backend" {
  value = vault_auth_backend.act_tasks.path
}

output "address" {
  value      = local.openbao_address
  depends_on = [incus_instance.act_openbao]
}
