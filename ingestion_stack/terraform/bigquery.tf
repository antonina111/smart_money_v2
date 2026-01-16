# Datasets

resource "google_bigquery_dataset" "raw" {
  project      = var.project_id
  dataset_id   = "raw"
  description  = "Raw layer for ingested market data"
  location     = var.region
}

resource "google_bigquery_dataset" "curated" {
  project      = var.project_id
  dataset_id   = "curated"
  description  = "Curated layer for ingested market data"
  location     = var.region
}

# Tables

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

# Scheduled quey
resource "google_bigquery_data_transfer_config" "raw_to_curated" {
  project                = var.project_id
  display_name           = "raw_to_curated_hourly"
  location               = var.region
  data_source_id         = "scheduled_query"
  destination_dataset_id = google_bigquery_dataset.curated.dataset_id
  schedule = "every 1 hours"
  schedule_options {
    start_time = "2025-12-01T17:01:00Z"
  }
  service_account_name = google_service_account.bq_schedule_sa.email

  params = {
    destination_table_name_template = "market_klines"

    write_disposition = "WRITE_TRUNCATE"

    query = file("${path.module}/../app/bq_scripts/raw_to_curated.sql")
  }
}

# view

resource "google_bigquery_table" "missing_klines" {
  dataset_id = google_bigquery_dataset.curated.dataset_id
  table_id   = "vw_missing_klines"

  deletion_protection = false

  view {
    query          = file("${path.module}/../app/bq_scripts/vw_missing_klines.sql")
    use_legacy_sql = false
  }
}

resource "google_bigquery_table" "klines_clean" {
  dataset_id = google_bigquery_dataset.curated.dataset_id
  table_id   = "vw_market_klines_clean"

  deletion_protection = false

  view {
    query          = file("${path.module}/../app/bq_scripts/vw_market_klines_clean.sql")
    use_legacy_sql = false
  }
}
