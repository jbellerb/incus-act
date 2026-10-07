resource "incus_storage_volume" "act_tasks_root" {
  name         = "act-tasks-root"
  pool         = var.incus_storage_pool
  project      = var.incus_project
  remote       = var.incus_remote
  type         = "custom"
  content_type = "filesystem"

  config = {
    "initial.uid"      = "0"
    "initial.gid"      = "0"
    "initial.mode"     = "0700"
    "security.shifted" = "true"
  }

  lifecycle {
    prevent_destroy = true
  }
}
