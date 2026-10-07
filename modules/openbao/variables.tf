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

variable "seal_key_id" {
  description = "SHA-256 identifier of the externally installed static seal key."
  type        = string
}

variable "ca_cert" {
  description = "Public self-signed OpenBao server certificate."
  type        = string
}
