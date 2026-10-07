variable "incus_address" {
  description = "Incus server URL reachable from task instances."
  type        = string
}

variable "incus_remote" {
  type    = string
  default = "incus"
}

variable "incus_project" {
  type    = string
  default = "default"
}

variable "incus_storage_pool" {
  type    = string
  default = "local"
}

variable "incus_server_cert" {
  type = string
}

variable "openbao_address" {
  description = "OpenBao API address used by the credential broker."
  type        = string
}

variable "openbao_ca_cert" {
  type = string
}

variable "task_approle_backend" {
  description = "OpenBao AppRole auth mount for tasks."
  type        = string
}

variable "scheduler_approle_backend" {
  description = "OpenBao AppRole auth mount for the task scheduler."
  type        = string
}

variable "scheduler_files" {
  description = "Additional scheduler host files, keyed by path relative to /."
  type        = map(string)
  default     = {}
}

variable "scheduler_commands" {
  description = "Additional cloud-init commands appended to the scheduler's commands."
  type        = list(list(string))
  default     = []
}

variable "secret_mount" {
  description = "OpenBao mount path for task credentials."
  type        = string
}

variable "tasks_root_volume" {
  description = "Shared volume containing task Dockerfiles and job files."
  type        = string
}

variable "job_results_volume" {
  description = "Shared volume containing job logs and exit statuses."
  type        = string
}

variable "job_runner_template" {
  description = "Initialized runner template that must exist before the scheduler starts."
  type        = string
}
