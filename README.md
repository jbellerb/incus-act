# incus-act

incus-act is a hyper-minimal task runner framework for automations and CI on Incus. Tasks are defined in Dockerfiles, and executed by BuildKit in gVisor sandboxes.

incus-act is distributed as a set of Terraform modules. The main module contains the full, opinionated setup: the BuildKit runner, a scheduler using systemd timers, OpenBao for secrets, and an OpenTofu task for the system to update itself. Each component is a submodule for further customization. See [`examples/minimal`](examples/minimal) for a setup that uses the runner and scheduler with external OpenBao and OpenTofu.

## Usage

For initial setup, refer to the [examples](examples). The rest of this document assumes you're running a configuration based on the [self-hosted](examples/self-hosted) example and have followed the steps in [BOOTSTRAP.md](BOOTSTRAP.md).

### Adding a task

Tasks start with a Dockerfile. Create one at `tasks/root/task-example/Dockerfile`:

```dockerfile
FROM alpine:3.24

RUN echo "Hello, world!"
```

To run it, we will use a timer. Create a `oneshot` systemd service at `tasks/etc/systemd/system/task-example.service`:

```ini
[Unit]
Description=Hello, world!

[Service]
Type=oneshot
PrivateTmp=yes
ExecStart=/usr/local/libexec/run-job-runner build \
    --frontend=dockerfile.v0 \
    --local=context=/root/task-example \
    --local=dockerfile=/root/task-example \
    --no-cache
TimeoutStartSec=infinity
```

A secrets drop-in at `tasks/etc/systemd/system/task-example.service.d/zzzz-credential.conf` (this is needed to override the `zzz-lxc-service.conf` drop-in from LXC's Debian image):

```ini
[Unit]
Requires=openbao-credential-broker.service
After=openbao-credential-broker.service

[Service]
LoadCredential=incus-client:/run/openbao-credential-broker/socket
```

And a timer that runs daily at `tasks/etc/systemd/system/task-example.timer`:

```ini
[Unit]
Description=Hello, world!

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

Configure the credentials broker to pass the `incus-client` credential in `tasks/etc/openbao/credential-broker.d/example.toml`:

```toml
[[credentials]]
unit = "task-example.service"
id = "incus-client"
kv_path = "secret/data/scheduler/incus"
kv_field = "incus-client"
```

We need to install these files on the scheduler. In your main.tf, add:

```diff
 module "incus_act" {
   source             = "github.com/jbellerb/incus-act"
   incus_address      = var.incus_address
 ...
   openbao_ca_cert    = file("${path.module}/openbao/tls.crt")
   seal_key_id        = var.seal_key_id
+
+  scheduler_files = {
+    for filename in fileset("${path.module}/tasks", "**") :
+    filename => file("${path.module}/tasks/${filename}")
+  }
+  scheduler_commands = [
+    ["systemctl", "enable", "--now", "task-example.timer"],
+  ]
 }
```

Copy the updated repo to `act-scheduler:/root/task-opentofu/repo` and dispatch a new job with:

```sh
git ls-files -z | tar --files-from - --null -cf - | incus exec act-scheduler -- \
    sh -c 'cd /root/task-opentofu && rm -rf repo && mkdir repo && tar -C repo -xf -'

incus exec act-scheduler -- systemctl start task-opentofu.service
```

Wait for the deploy to finish and you should see your new task working:

```sh
incus exec act-scheduler -- systemctl start task-example.service
incus exec act-scheduler -- journalctl -u task-example.service

# the journal entry will show the job's name. When it completes, you can query
# its status with
incus exec act-scheduler -- cat "/var/log/task-jobs/act-job-runner-<id>.status"
```

### Adding secrets

Extend your Dockerfile with a secret mount:

```diff
 FROM alpine:3.24
 
-RUN echo "Hello, world!"
+RUN --mount=type=secret,id=example-secret,target=/run/secrets/example-secret \
+    printf 'Hello, world! Proof: %s\n' "$(sha256sum /run/secrets/example-secret)"
```

Now add the credential to your drop-in and broker config:

```diff
 [Service]
 LoadCredential=incus-client:/run/openbao-credential-broker/socket
+LoadCredential=example-secret:/run/openbao-credential-broker/socket
```

```diff
 kv_path = "secret/data/scheduler/incus"
 kv_field = "incus-client"
+
+[[credentials]]
+unit = "task-example.service"
+id = "example-secret"
+kv_path = "secret/data/tasks/example"
+kv_field = "example-secret"
```

Finally, upload the secret to OpenBao:

```sh
incus exec act-openbao -- sh

export VAULT_ADDR=https://act-openbao.incus:8200
export VAULT_CACERT=/openbao/config/tls.crt
bao login -method=userpass -path=admin username=admin
# use the password generated during the bootstrap procedure

read -r -s secret
# type any secret
printf '%s' "$secret" | bao kv put -mount=secret tasks/example example-secret=-

bao token revoke -self
exit
```

And redeploy like before.

<br />

#### License

<sup>
Copyright (C) jae beller, 2026.
</sup>
<br />
<sup>
Released under the Apache License, Version 2.0. See <a href="LICENSE">LICENSE</a> for more information.
</sup>
