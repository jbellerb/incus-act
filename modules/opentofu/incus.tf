ephemeral "tls_private_key" "act_opentofu" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "act_opentofu" {
  private_key_pem_wo         = ephemeral.tls_private_key.act_opentofu.private_key_pem
  private_key_pem_wo_version = 1
  validity_period_hours      = 87600
  early_renewal_hours        = 720
  allowed_uses               = ["digital_signature", "client_auth"]

  subject {
    common_name = "opentofu@incus-act"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "incus_certificate" "act_opentofu" {
  name        = "act-opentofu"
  remote      = var.incus_remote
  certificate = tls_self_signed_cert.act_opentofu.cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "vault_kv_secret_v2" "act_opentofu_incus" {
  mount = var.secret_mount
  name  = "tasks/opentofu/incus"
  data_json_wo = jsonencode({
    incus-client = jsonencode({
      certificate = tls_self_signed_cert.act_opentofu.cert_pem
      private_key = ephemeral.tls_private_key.act_opentofu.private_key_pem
    })
  })
  data_json_wo_version = parseint(
    substr(sha256(tls_self_signed_cert.act_opentofu.cert_pem), 0, 12),
    16,
  )

  depends_on = [incus_certificate.act_opentofu]

  lifecycle {
    prevent_destroy = true
  }
}
