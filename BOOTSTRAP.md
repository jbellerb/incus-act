# Bootstrapping a fresh Incus installation

This installs the full, opinionated task system, including a self-hosted OpenTofu task for applying updates. If using an external OpenBao instance or you don't want to use the OpenTofu apply task, refer to [examples/minimal/README.md](examples/minimal/README.md).

These instructions assume an amd64 server and the `default` Incus project.

## 1. Start the temporary bootstrap instance

First, create an instance to work in and mount the local Incus control socket. From your configuration directory:

```sh
incus launch images:debian/trixie bootstrap --network incusbr0 -c security.privileged=true
incus exec bootstrap -- mkdir -p /var/lib/incus /root/incus-cluster
incus config device add bootstrap incus-socket disk \
    source=/var/lib/incus/unix.socket path=/var/lib/incus/unix.socket
git ls-files -z | tar --files-from - --null -cf - \
    | incus exec bootstrap -- tar -C /root/incus-cluster -xf -
incus exec bootstrap --cwd /root/incus-cluster -- bash
```

Inside bootstrap as root, install the required programs and set up the secrets directory:

```sh
apt-get update
apt-get install -y incus-client curl jq openssl
curl -fsSLo /tmp/tofu.tar.gz \
    https://github.com/opentofu/opentofu/releases/download/v1.13.1/tofu_1.13.1_linux_amd64.tar.gz
tar -C /usr/local/bin -xzf /tmp/tofu.tar.gz tofu
mkdir -m 700 /root/bootstrap-secrets
```

## 2. Prepare the checkout and state bucket

Get Incus's server certificate and host information:

```sh
mkdir -p incus
incus query /1.0 | jq -r .environment.certificate \
    > incus/server.crt
INCUS_HOST=$(incus query /1.0 | jq -r .environment.server_name)
printf 'incus_address = "https://%s:8443"\ns3_endpoint = "https://%s:8555"\n' \
    "$INCUS_HOST" "$INCUS_HOST" > terraform.tfvars
INCUS_STORAGE_POOL=$(incus profile device get default root pool)
printf 'incus_storage_pool = "%s"\n' "$INCUS_STORAGE_POOL" >> terraform.tfvars
INCUS_BRIDGE_IP=$(incus network get incusbr0 ipv4.address | cut -d/ -f1)
```

The certificate hostname must resolve to the gateway from instances. `$INCUS_HOST` doesn't resolve, add a record to `incusbr0`'s `raw.dnsmasq` configuration:

```text
host-record=<INCUS_HOST>.incus,<INCUS_BRIDGE_IP>
```

The S3 listener is disabled by default. If it's not already configured, enable it on the bridge address:

```sh
incus config set core.storage_buckets_address="$INCUS_BRIDGE_IP:8555"
```

Also, if it's not already enabled, expose the HTTPS API:

```sh
incus config set core.https_address=:8443
```

Create the bucket to store OpenTofu's state:

```sh
incus storage bucket create "$INCUS_STORAGE_POOL" act-opentofu-state --quiet
incus query "/1.0/storage-pools/$INCUS_STORAGE_POOL/buckets/act-opentofu-state/keys/admin" \
    | jq -r '"[default]\naws_access_key_id = \(."access-key")\naws_secret_access_key = \(."secret-key")"' \
    > /root/bootstrap-secrets/s3-credentials
chmod 600 /root/bootstrap-secrets/s3-credentials
export AWS_SHARED_CREDENTIALS_FILE=/root/bootstrap-secrets/s3-credentials
export AWS_CA_BUNDLE="$PWD/incus/server.crt"
```

Initialize OpenTofu against S3 and generate the provider lock file:

```sh
incus remote add incus unix://
tofu init
```

## 3. Start and initialize OpenBao

Generate OpenBao's certificate, static seal key, and initial admin password:

```sh
mkdir -p openbao
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc -days 3650 \
    -subj '/CN=act-openbao.incus' -addext 'subjectAltName=DNS:act-openbao.incus' \
    -keyout /root/bootstrap-secrets/openbao-tls.key \
    -out openbao/tls.crt
openssl rand -out /root/bootstrap-secrets/static-seal.key 32
key_id=$(sha256sum /root/bootstrap-secrets/static-seal.key | cut -d' ' -f1)
printf '%s\n' "$key_id" > /root/bootstrap-secrets/static-seal-key-id
printf 'seal_key_id = "%s"\n' "$key_id" >> terraform.tfvars
openssl rand -hex 32 | tr -d '\n' > /root/bootstrap-secrets/admin-password
chmod 600 /root/bootstrap-secrets/*

tofu import module.incus_act.module.opentofu.incus_storage_bucket.act_opentofu_state \
    "incus:default/$INCUS_STORAGE_POOL/act-opentofu-state"
tofu apply \
    -target=module.incus_act.module.openbao.incus_storage_volume.act_openbao_config \
    -target=module.incus_act.module.openbao.incus_storage_volume.act_openbao_data \
    -target=module.incus_act.module.openbao.incus_storage_volume.act_openbao_seal \
    -target=module.incus_act.module.scheduler.incus_storage_volume.act_scheduler_broker_auth
incus config device add bootstrap bao-config disk pool="$INCUS_STORAGE_POOL" \
    source=act-openbao-config path=/mnt/bao-config
incus config device add bootstrap bao-seal disk pool="$INCUS_STORAGE_POOL" \
    source=act-openbao-seal path=/mnt/bao-seal
incus config device add bootstrap broker-auth disk pool="$INCUS_STORAGE_POOL" \
    source=act-scheduler-broker-auth path=/mnt/broker-auth
install -o 100 -g 1000 -m 600 /root/bootstrap-secrets/openbao-tls.key /mnt/bao-config/tls.key
install -o 100 -g 1000 -m 600 /root/bootstrap-secrets/static-seal.key /mnt/bao-seal/static-seal.key
install -o 100 -g 1000 -m 600 /root/bootstrap-secrets/admin-password /mnt/bao-seal/admin-password

# detach so Incus can remap ownership for the unprivileged OpenBao instance
incus config device remove bootstrap bao-config
incus config device remove bootstrap bao-seal

tofu apply -target=module.incus_act.module.openbao.incus_instance.act_openbao
```

OpenBao initializes itself on first start and creates an `admin` login from the password file. Copy the CLI from the running instance so its version matches the server. Wait for `bao status` to report both initialized and unsealed, then log in and generate the recovery shares:

```sh
incus file pull act-openbao/usr/bin/bao /usr/local/bin/bao
chmod 755 /usr/local/bin/bao

export VAULT_ADDR=$(tofu output -raw openbao_address)
export VAULT_CACERT="$PWD/openbao/tls.crt"
bao status

export VAULT_TOKEN=$(bao login -method=userpass -path=admin -token-only \
    username=admin password=@/root/bootstrap-secrets/admin-password)

bao write -format=json sys/rotate/recovery/init \
    secret_shares=3 secret_threshold=2 \
    > /root/bootstrap-secrets/recovery-shares.json
chmod 600 /root/bootstrap-secrets/recovery-shares.json

tofu apply \
    -target=module.incus_act.module.openbao \
    -target=module.incus_act.module.scheduler.vault_approle_auth_backend_role.act_scheduler_broker \
    -target=module.incus_act.module.scheduler.vault_kv_secret_v2.act_scheduler_incus \
    -target=module.incus_act.module.opentofu
```

## 4. Configure credentials and create the task system

Store the bucket credentials in OpenBao and seed the scheduler's AppRole credential:

```sh
bao kv put secret/tasks/opentofu/s3 \
    opentofu-s3-credentials=@/root/bootstrap-secrets/s3-credentials
bao write -format=json -f auth/approle/role/scheduler-broker/secret-id \
    | jq '{role_id: "scheduler-broker", secret_id: .data.secret_id}' \
    > /root/bootstrap-secrets/broker-auth
chmod 600 /root/bootstrap-secrets/broker-auth
install -o 0 -g 0 -m 600 /root/bootstrap-secrets/broker-auth /mnt/broker-auth/broker-auth
```

Finally, provision the task runner, revoke bootstrap's OpenBao token, and exit the bootstrap instance:

```sh
tofu plan
tofu apply

bao operator raft snapshot save /root/bootstrap-secrets/openbao.snap
bao token revoke -self

exit
```

## 5. Save recovery files and remove bootstrap

In the original repository checkout, copy back the deployment configuration and public certificates:

```sh
incus exec bootstrap -- tar -C /root/incus-cluster -cf - \
    terraform.tfvars \
    .terraform.lock.hcl \
    incus/server.crt \
    openbao/tls.crt \
    | tar --no-same-owner --no-same-permissions -xf -
```

Save the OpenBao recovery files and bootstrap secrets using your preferred encryption tool or password manager:

```sh
incus exec bootstrap -- tar -C /root -cf - bootstrap-secrets \
    | age ...
```

**Verify you can read the backup**, then:

```sh
incus delete bootstrap --force
```
