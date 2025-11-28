resource "google_bigquery_dataset" "raw" {
  project      = var.project_id
  dataset_id   = "raw"
  description  = "Raw layer for ingested market data"
  location     = var.region
}

resource "google_bigquery_table" "raw_market_klines" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.raw.dataset_id
  table_id   = "market_klines"

  description = "Raw market kline messages from Pub/Sub subscription"

  deletion_protection = false

  schema = jsonencode([
    {
      name        = "data"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Raw Pub/Sub message data"
    },
    {
      name        = "attributes"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Flattened Pub/Sub attributes"
    },
    {
      name        = "message_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Pub/Sub message ID"
    },
    {
      name        = "publish_time"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Time when the message was published to Pub/Sub"
    },
    {
      name        = "subscription_name"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Name of the subscription that wrote this row"
    }
  ])
}
