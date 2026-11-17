# Déclaration des variables

variable "project_id" {
  description = "L'ID du projet Google Cloud"
  type        = string
}

variable "region" {
  description = "Région GCP (doit contenir la zone)"
  type        = string
  default     = "europe-west9"
}

variable "zone" {
  description = "Zone GCP de la VM et du disque persistant"
  type        = string
  default     = "europe-west9-b"
}

variable "network" {
  description = "Réseau VPC existant dans lequel déployer la VM (non créé par Terraform)"
  type        = string
  default     = "default"
}

variable "domain" {
  description = "Nom de domaine servi par Caddy (un enregistrement DNS A doit pointer vers l'IP statique)"
  type        = string
}

variable "grafana_admin_password" {
  description = "Mot de passe initial du compte admin Grafana (appliqué uniquement à la première initialisation de Grafana)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 12
    error_message = "Le mot de passe admin Grafana doit faire au moins 12 caractères."
  }
}
