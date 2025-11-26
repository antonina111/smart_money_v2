variable "project_id" {
  type        = string
  description = "GCP project ID"
  default     = "mineral-brand-231612"
}

variable "region" {
  type        = string
  description = "GCP region for regional resources"
  default     = "europe-west1"
}

variable "zone" {
  type        = string
  description = "GCP zone for the compute instance"
  default     = "europe-west1-d"
}

variable "vm_name" {
  type        = string
  description = "Name of the kline fetcher VM instance"
  default     = "vm-fetcher-2-0"
}

variable "machine_type" {
  type        = string
  description = "Machine type for the compute instance"
  default     = "e2-micro"
}

variable "pubsub_topic" {
  type        = string
  description = "Pub/Sub topic for raw market kline data"
  default     = "market-klines-raw"
}