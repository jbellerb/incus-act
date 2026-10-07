module "incus_act" {
  source             = "../.."
  incus_address      = var.incus_address
  incus_remote       = var.incus_remote
  incus_project      = var.incus_project
  incus_storage_pool = var.incus_storage_pool
  incus_server_cert  = file("${path.module}/incus/server.crt")
  openbao_ca_cert    = file("${path.module}/openbao/tls.crt")
  seal_key_id        = var.seal_key_id
}

output "buildkit_instance" {
  value = module.incus_act.buildkit_instance
}

output "openbao_address" {
  value = module.incus_act.openbao_address
}
