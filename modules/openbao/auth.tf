resource "vault_auth_backend" "act_approle" {
  type = "approle"
  path = "approle"
}

resource "vault_mount" "act_secret" {
  path        = "secret"
  type        = "kv"
  description = "Workload secrets"
  options = {
    version = "2"
  }
}

resource "vault_auth_backend" "act_tasks" {
  type = "approle"
  path = "tasks"
}
