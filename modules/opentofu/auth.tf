resource "vault_policy" "act_tasks_opentofu" {
  name   = "tasks-opentofu"
  policy = <<-HCL
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
    path "auth/token/create" {
      capabilities = ["update"]
    }

    path "sys/auth/${var.scheduler_approle_backend}" {
      capabilities = ["read", "update", "delete", "sudo"]
    }
    path "sys/auth/${var.task_approle_backend}" {
      capabilities = ["read", "update", "delete", "sudo"]
    }
    path "sys/mounts/auth/${var.scheduler_approle_backend}" {
      capabilities = ["read"]
    }
    path "sys/mounts/auth/${var.scheduler_approle_backend}/tune" {
      capabilities = ["read", "update"]
    }
    path "sys/mounts/auth/${var.task_approle_backend}" {
      capabilities = ["read"]
    }
    path "sys/mounts/auth/${var.task_approle_backend}/tune" {
      capabilities = ["read", "update"]
    }
    path "sys/mounts/${var.secret_mount}" {
      capabilities = ["read", "update", "delete"]
    }
    path "sys/mounts/${var.secret_mount}/tune" {
      capabilities = ["read", "update"]
    }

    path "sys/policies/acl/*" {
      capabilities = ["read", "update", "delete"]
    }
    path "auth/${var.scheduler_approle_backend}/role/*" {
      capabilities = ["create", "read", "update", "delete"]
    }
    path "auth/${var.task_approle_backend}/role/*" {
      capabilities = ["create", "read", "update", "delete"]
    }

    path "${var.secret_mount}/data/scheduler/incus" {
      capabilities = ["create", "read", "update", "delete"]
    }
    path "${var.secret_mount}/metadata/scheduler/incus" {
      capabilities = ["read", "update"]
    }
    path "${var.secret_mount}/data/tasks/*" {
      capabilities = ["create", "read", "update", "delete"]
    }
    path "${var.secret_mount}/metadata/tasks/*" {
      capabilities = ["read", "update"]
    }
  HCL
}

resource "vault_approle_auth_backend_role" "act_tasks_opentofu" {
  backend                 = var.task_approle_backend
  role_name               = "tasks-opentofu"
  role_id                 = "tasks-opentofu"
  bind_secret_id          = true
  secret_id_num_uses      = 1
  secret_id_ttl           = 600
  token_policies          = [vault_policy.act_tasks_opentofu.name]
  token_no_default_policy = true
  token_ttl               = 3600
  token_max_ttl           = 86400
}
