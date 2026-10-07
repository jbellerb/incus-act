# Minimal configuration

Installs the task runner and scheduler with external OpenBao and no OpenTofu update task.

Copy this directory to a new repo, update the module `source` in `main.tf` to point to the GitHub repository, and follow the instructions in [BOOTSTRAP.md](../../BOOTSTRAP.md) with these changes:

- Step 1: skip entirely
- Step 2: skip S3 setup and defer `tofu init` to step 3
- Step 3: skip entirely. Instead, copy your OpenBao CA certificate to `openbao/tls.crt`, ensure there exists AppRole mounts matching `task_approle_backend` and `scheduler_approle_backend` in `main.tf` and a KV mount matching `secret_mount`, and prepare the broker's key volume:

  ```sh
  tofu init
  tofu apply \
      -target=module.scheduler.vault_approle_auth_backend_role.act_scheduler_broker \
      -target=module.scheduler.incus_storage_volume.act_scheduler_broker_auth
  ```

- Step 4: skip entirely. Instead, run:

  ```sh
  bao write -format=json -f auth/approle/role/scheduler-broker/secret-id \
      | jq '{role_id: "scheduler-broker", secret_id: .data.secret_id}' \
      | incus storage volume file push - "$INCUS_STORAGE_POOL" \
          act-scheduler-broker-auth/broker-auth --uid=0 --gid=0 --mode=0600

  tofu plan
  tofu apply
  ```

- Step 5: skip entirely
