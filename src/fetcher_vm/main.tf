# This code is compatible with Terraform 4.25.0 and versions that are backwards compatible to 4.25.0.
# For information about validating this Terraform code, see https://developer.hashicorp.com/terraform/tutorials/gcp-get-started/google-cloud-platform-build#format-and-validate-the-configuration

locals {
  streamer_py = file("${path.module}/app/binance_kline_streamer.py")
}

resource "google_compute_instance" "vm-fetcher-2-0" {
  boot_disk {
    auto_delete = true
    device_name = "vm-fetcher-2-0"

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


  machine_type = "e2-micro"

  metadata = {
    enable-osconfig = "TRUE"
    startup-script  = templatefile("${path.module}/scripts/startup.sh.tpl", {
      streamer_py = local.streamer_py
    })
  }

  name = "vm-fetcher-2-0"

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "projects/mineral-brand-231612/regions/europe-west1/subnetworks/default"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = "504389925601-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  zone = "europe-west1-d"
}
