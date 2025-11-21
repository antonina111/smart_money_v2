terraform {
  required_version = ">= 1.3.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"   # recent, stable
    }
  }
}

provider "google" {
  project = "mineral-brand-231612"
  region  = "europe-west1"
  zone    = "europe-west1-d"
  # credentials are picked up from ADC by default (see step 3)
}