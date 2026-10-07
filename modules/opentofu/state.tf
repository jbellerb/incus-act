resource "incus_storage_bucket" "act_opentofu_state" {
  name    = "act-opentofu-state"
  pool    = var.incus_storage_pool
  project = var.incus_project
  remote  = var.incus_remote

  lifecycle {
    prevent_destroy = true
  }
}
