resource "google_service_account" "vm_fetcher_sa" {
  account_id   = "vm-fetcher-sa"
  display_name = "VM Fetcher Service Account"
}

resource "google_project_iam_member" "vm_fetcher_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.vm_fetcher_sa.email}"
}

resource "google_bigquery_dataset_iam_member" "vm_fetcher_data_raw_writer" {
  dataset_id = "raw"
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.vm_fetcher_sa.email}"
}

resource "google_project_iam_member" "vm_fetcher_bq_jobuser" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
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

resource "google_service_account" "bq_schedule_sa" {
  account_id   = "bq-scheduled-query"
  display_name = "BQ Scheduled Query Runner"
}

resource "google_project_iam_member" "bq_scheduled_query_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.bq_schedule_sa.email}"
}

resource "google_bigquery_dataset_iam_member" "bq_scheduled_query_source" {
  dataset_id = google_bigquery_dataset.raw.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.bq_schedule_sa.email}"
}

resource "google_bigquery_dataset_iam_member" "bq_scheduled_query_dest" {
  dataset_id = google_bigquery_dataset.curated.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.bq_schedule_sa.email}"
}
