resource "google_compute_instance" "devops_lab" {
  name         = "lab-instance-thomas"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["http-server", "monitoring"]

  attached_disk {
    source      = google_compute_disk.grafana_data.id
    device_name = "grafana-data" # Doit correspondre à DEVICE_PATH dans monitoring.tf
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = var.network
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  # Script de démarrage défini dans monitoring.tf
  metadata_startup_script = local.startup_script
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http-thomas"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["80", "443"] # HTTP + HTTPS (Caddy gère le certificat automatiquement)
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

# Disque persistant : données Grafana, Prometheus et certificats Caddy
resource "google_compute_disk" "grafana_data" {
  name = "grafana-storage-thomas"
  type = "pd-ssd"
  zone = var.zone
  size = 10

  lifecycle {
    prevent_destroy = true
  }
}

# IP statique pour que le DNS reste valide après redéploiement
resource "google_compute_address" "static_ip" {
  name   = "grafana-static-ip-thomas"
  region = var.region

  lifecycle {
    prevent_destroy = true
  }
}
