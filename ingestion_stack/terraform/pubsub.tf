resource "google_pubsub_topic" "market_klines_raw" {
  name = var.pubsub_topic
}

resource "google_pubsub_subscription" "market_klines_raw_bq" {
  name  = "${var.pubsub_topic}-bq"
  topic = google_pubsub_topic.market_klines_raw.id

  bigquery_config {
    table          = "${var.project_id}.${google_bigquery_dataset.raw.dataset_id}.market_klines"
    write_metadata = true
  }
  ack_deadline_seconds = 30
}