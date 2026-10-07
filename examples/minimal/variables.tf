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

variable "openbao_address" {
  description = "External OpenBao HTTPS API address reachable from task instances."
  type        = string
}
