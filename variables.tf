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
  description = "Incus storage pool for custom volumes and the state bucket."
  type        = string
  default     = "local"
}
variable "incus_server_cert" {
  type = string
}

variable "openbao_ca_cert" {
  type = string
}

variable "seal_key_id" {
  description = "SHA-256 identifier of the externally installed static seal key."
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
