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

variable "s3_endpoint" {
  description = "S3 state bucket URL reachable from task instances."
  type        = string
}

variable "seal_key_id" {
  description = "SHA-256 identifier of OpenBao's static seal key."
  type        = string
}
