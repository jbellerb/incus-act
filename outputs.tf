output "buildkit_instance" {
  value = module.tasks.buildkit_instance
}

output "scheduler_approle_backend" {
  value = module.openbao.scheduler_approle_backend
}

output "secret_mount" {
  value = module.openbao.secret_mount
}

output "task_approle_backend" {
  value = module.openbao.task_approle_backend
}

output "openbao_address" {
  value = module.openbao.address
}
