FROM ghcr.io/opentofu/opentofu:1.13.1-minimal AS tofu

FROM alpine:3.24

RUN apk add --no-cache ca-certificates curl incus-client jq

RUN --mount=type=bind,from=tofu,source=/usr/local/bin/tofu,target=/usr/local/bin/tofu,ro \
    --mount=type=bind,target=/work,rw \
    --mount=type=tmpfs,target=/run/incus \
    --mount=type=bind,source=config.yml,target=/run/incus/config.yml,ro \
    --mount=type=bind,source=server.crt,target=/run/incus/server.crt,ro \
    --mount=type=bind,source=openbao-address,target=/run/incus/openbao-address,ro \
    --mount=type=bind,source=openbao-approle-backend,target=/run/incus/openbao-approle-backend,ro \
    --mount=type=cache,id=opentofu-plugins,target=/plugins,sharing=locked \
    --mount=type=secret,id=opentofu-s3-credentials,target=/run/secrets/opentofu-s3-credentials \
    --mount=type=secret,id=opentofu-incus-client,target=/run/secrets/opentofu-incus-client \
    --mount=type=secret,id=openbao-approle-secret-id,target=/run/secrets/openbao-approle-secret-id \
    --mount=type=secret,id=openbao-ca,target=/run/secrets/openbao-ca \
    << 'EOF'
export INCUS_CONF=/run/incus
remote=$(incus remote get-default) || exit 1
export TF_VAR_incus_remote=$remote

mkdir -p /run/incus/servercerts || exit 1
ln -s ../server.crt "/run/incus/servercerts/$remote.crt" || exit 1
jq -er .certificate /run/secrets/opentofu-incus-client > /run/incus/client.crt || exit 1
jq -er .private_key /run/secrets/opentofu-incus-client > /run/incus/client.key || exit 1
chmod 600 /run/incus/client.key || exit 1

export TF_PLUGIN_CACHE_DIR=/plugins
export AWS_SHARED_CREDENTIALS_FILE=/run/secrets/opentofu-s3-credentials
export AWS_CA_BUNDLE=/run/incus/server.crt

export VAULT_ADDR=$(cat /run/incus/openbao-address)
task_approle_backend=$(cat /run/incus/openbao-approle-backend) || exit 1
export VAULT_CACERT=/run/secrets/openbao-ca
export VAULT_TOKEN=$(
    jq -n --rawfile secret_id /run/secrets/openbao-approle-secret-id \
        '{ role_id: "tasks-opentofu", secret_id: ($secret_id | rtrimstr("\n")) }' \
        | curl --fail --silent --show-error --cacert "$VAULT_CACERT" \
            --header 'Content-Type: application/json' --data-binary @- \
            "$VAULT_ADDR/v1/auth/$task_approle_backend/login" | jq -er .auth.client_token
) || exit 1

tofu -chdir=/work/repo init -input=false -lockfile=readonly || exit 1
tofu -chdir=/work/repo apply -input=false -auto-approve || exit 1
EOF
