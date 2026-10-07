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

variable "secret_mount" {
  description = "OpenBao mount path for task credentials."
  type        = string
}
