resource "google_cloud_run_v2_job" "smart_money_job" {
  name     = "smart-money-job"
  location = var.region


template {
    template {
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/smart-money-jobs/smart-money-job:latest"
      }

      max_retries = 1
      timeout     = "3600s"
    }
  }
}
