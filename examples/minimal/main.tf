module "tasks" {
  source             = "../../modules/tasks"
  incus_remote       = var.incus_remote
  incus_project      = var.incus_project
  incus_storage_pool = var.incus_storage_pool
}

module "scheduler" {
  source                    = "../../modules/scheduler"
  incus_address             = var.incus_address
  incus_remote              = var.incus_remote
  incus_project             = var.incus_project
  incus_storage_pool        = var.incus_storage_pool
  incus_server_cert         = file("${path.module}/incus/server.crt")
  openbao_address           = var.openbao_address
  openbao_ca_cert           = file("${path.module}/openbao/tls.crt")
  task_approle_backend      = "tasks"
  scheduler_approle_backend = "approle"
  secret_mount              = "secret"
  tasks_root_volume         = module.tasks.tasks_root_volume
  job_results_volume        = module.tasks.job_results_volume
  job_runner_template       = module.tasks.job_runner_template
}

output "buildkit_instance" {
  value = module.tasks.buildkit_instance
}
