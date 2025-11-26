locals {
  streamer_py = file("${path.module}/../app/binance_kline_streamer.py")
}

resource "google_compute_instance" "vm-fetcher-2-0" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  allow_stopping_for_update = true

  boot_disk {
    auto_delete = true
    device_name = var.vm_name

    initialize_params {
      image = "projects/debian-cloud/global/images/debian-12-bookworm-v20251014"
      size  = 10
      type  = "pd-standard"
    }

    mode = "READ_WRITE"
  }

  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false

  labels = {
    goog-ec-src           = "vm_add-tf"
    goog-ops-agent-policy = "v2-x86-template-1-4-0"
  }

  metadata = {
    enable-osconfig = "TRUE"
    startup-script  = templatefile("${path.module}/../scripts/startup.sh.tpl", {
      streamer_py = local.streamer_py
      project_id  = var.project_id
      topic_id    = var.pubsub_topic
    })
  }

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    queue_count = 0
    stack_type  = "IPV4_ONLY"

    # default subnet in the chosen region & project
    subnetwork = "projects/${var.project_id}/regions/${var.region}/subnetworks/default"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = google_service_account.vm_fetcher_sa.email
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/pubsub"
    ]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }
}
