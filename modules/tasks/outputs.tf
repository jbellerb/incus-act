output "tasks_root_volume" {
  value = incus_storage_volume.act_tasks_root.name
}

output "job_results_volume" {
  value = incus_storage_volume.act_job_results.name
}

output "job_runner_template" {
  value = incus_instance.act_job_runner_template.name
}
