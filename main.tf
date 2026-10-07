module "tasks" {
  source             = "./modules/tasks"
  incus_remote       = var.incus_remote
  incus_project      = var.incus_project
  incus_storage_pool = var.incus_storage_pool
}

module "scheduler" {
  source                    = "./modules/scheduler"
  incus_remote              = var.incus_remote
  incus_project             = var.incus_project
  incus_storage_pool        = var.incus_storage_pool
  incus_address             = var.incus_address
  incus_server_cert         = var.incus_server_cert
  scheduler_approle_backend = module.openbao.scheduler_approle_backend
  task_approle_backend      = module.openbao.task_approle_backend
  secret_mount              = module.openbao.secret_mount
  openbao_ca_cert           = var.openbao_ca_cert
  openbao_address           = module.openbao.address
  scheduler_files           = merge(module.opentofu.scheduler_files, var.scheduler_files)
  scheduler_commands        = var.scheduler_commands
  tasks_root_volume         = module.tasks.tasks_root_volume
  job_results_volume        = module.tasks.job_results_volume
  job_runner_template       = module.tasks.job_runner_template
}

module "openbao" {
  source             = "./modules/openbao"
  incus_remote       = var.incus_remote
  incus_project      = var.incus_project
  incus_storage_pool = var.incus_storage_pool
  seal_key_id        = var.seal_key_id
  ca_cert            = var.openbao_ca_cert
}

module "opentofu" {
  source                    = "./modules/opentofu"
  incus_remote              = var.incus_remote
  incus_project             = var.incus_project
  incus_storage_pool        = var.incus_storage_pool
  scheduler_approle_backend = module.openbao.scheduler_approle_backend
  task_approle_backend      = module.openbao.task_approle_backend
  secret_mount              = module.openbao.secret_mount
  incus_address             = var.incus_address
  incus_server_cert         = var.incus_server_cert
  openbao_address           = module.openbao.address
}
