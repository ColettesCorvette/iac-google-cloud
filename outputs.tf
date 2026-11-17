# Sorties du déploiement

output "instance_name" {
  description = "Nom de l'instance VM"
  value       = google_compute_instance.devops_lab.name
}

output "instance_zone" {
  description = "Zone où l'instance est déployée"
  value       = google_compute_instance.devops_lab.zone
}

output "instance_public_ip" {
  description = "IP statique publique (cible de l'enregistrement DNS)"
  value       = google_compute_address.static_ip.address
}

output "instance_private_ip" {
  description = "Adresse IP privée de l'instance"
  value       = google_compute_instance.devops_lab.network_interface[0].network_ip
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à l'instance"
  value       = "gcloud compute ssh ${google_compute_instance.devops_lab.name} --zone=${google_compute_instance.devops_lab.zone} --project=${var.project_id}"
}

output "grafana_url" {
  description = "URL d'accès à Grafana (via Caddy, en HTTPS)"
  value       = "https://${var.domain}"
}

output "prometheus_tunnel_command" {
  description = "Prometheus n'est pas exposé publiquement : tunnel SSH pour y accéder sur http://localhost:9090"
  value       = "gcloud compute ssh ${google_compute_instance.devops_lab.name} --zone=${google_compute_instance.devops_lab.zone} --project=${var.project_id} -- -L 9090:localhost:9090"
}
