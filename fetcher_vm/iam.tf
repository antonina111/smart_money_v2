resource "google_service_account" "vm_fetcher_sa" {
  account_id   = "vm-fetcher-sa"
  display_name = "VM Fetcher Service Account"
}

resource "google_project_iam_member" "vm_fetcher_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.vm_fetcher_sa.email}"
}
