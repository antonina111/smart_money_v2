resource "google_service_account" "vm_fetcher_sa" {
  account_id   = "vm-fetcher-sa"
  display_name = "VM Fetcher Service Account"
}

resource "google_project_iam_member" "vm_fetcher_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.vm_fetcher_sa.email}"
}

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_bigquery_dataset_iam_member" "raw_pubsub_writer" {
  dataset_id = google_bigquery_dataset.raw.dataset_id
  role       = "roles/bigquery.dataEditor"

  member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}