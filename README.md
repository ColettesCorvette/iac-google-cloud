# Stack d'observabilité sur GCP

Infrastructure as Code (Terraform) qui déploie une stack de monitoring Prometheus / Grafana sur une VM Google Cloud, exposée en HTTPS derrière Caddy et Cloudflare.

## Architecture

```
Internet ──> Cloudflare (DNS, proxy) ──> Caddy :443 (HTTPS) ──> Grafana :3000
                                                                   │
                                                              Prometheus :9090 <── Node Exporter :9100
```

| Composant | Rôle |
|-----------|------|
| Caddy | Reverse proxy, certificat Let's Encrypt obtenu et renouvelé automatiquement |
| Grafana | Visualisation des métriques |
| Prometheus | Collecte et stockage des métriques (TSDB) |
| Node Exporter | Métriques système de la VM (CPU, RAM, disque, réseau) |

Seuls les ports 80 et 443 sont ouverts. Prometheus et Node Exporter ne sont joignables que depuis le réseau Docker interne ; Prometheus est en plus publié sur `127.0.0.1:9090` pour un accès par tunnel SSH.

### Provisionnement

Tout est fait par le script de démarrage défini dans `monitoring.tf`. Il s'exécute à chaque boot et est idempotent :

1. Installe Docker s'il est absent.
2. Monte le disque persistant (formaté uniquement s'il est vierge) et l'ajoute à `/etc/fstab`.
3. Écrit `docker-compose.yml`, `Caddyfile` et `prometheus.yml`, puis lance `docker compose up -d`.

## Structure

| Fichier | Contenu |
|---------|---------|
| `providers.tf` | Provider Google |
| `main.tf` | VM, règle de pare-feu, disque persistant, IP statique |
| `monitoring.tf` | Script de démarrage (Docker Compose, Caddy, Prometheus) |
| `variables.tf` | Variables d'entrée |
| `outputs.tf` | IP, URL Grafana, commandes SSH |
| `terraform.tfvars.example` | Exemple de configuration |

## Prérequis

- Un projet GCP avec la facturation activée
- [`gcloud`](https://cloud.google.com/sdk/docs/install) authentifié (`gcloud auth application-default login`)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- Un nom de domaine dont vous gérez le DNS (ici via Cloudflare)

## Déploiement

```bash
cp terraform.tfvars.example terraform.tfvars   # renseigner project_id, domain, grafana_admin_password
terraform init
terraform apply
```

Ensuite :

1. Créer un enregistrement DNS `A` pour le domaine vers `terraform output -raw instance_public_ip`. Avec le proxy Cloudflare activé, utiliser le mode SSL/TLS « Full (strict) ».
2. Attendre environ 3 minutes que Docker s'installe et que Caddy obtienne le certificat.
3. Ouvrir `terraform output -raw grafana_url` et se connecter avec `admin` et le mot de passe défini dans `grafana_admin_password`.

`grafana_admin_password` n'est appliqué qu'à la première initialisation de Grafana. Sur une base existante, changer le mot de passe depuis l'interface ou avec `docker exec grafana grafana cli admin reset-admin-password <nouveau>`.

## Configuration de Grafana

1. Ajouter une data source Prometheus avec l'URL `http://prometheus:9090`.
2. Importer le dashboard **1860** (Node Exporter Full).

Pour consulter l'interface Prometheus directement :

```bash
$(terraform output -raw prometheus_tunnel_command)
# puis http://localhost:9090
```

## Persistance des données

Le disque persistant (`/mnt/disks/grafana`) conserve les dashboards et data sources Grafana, l'historique Prometheus et les certificats Caddy. L'IP statique garde le DNS valide entre deux déploiements.

Ces deux ressources sont protégées par `lifecycle { prevent_destroy = true }`, un `terraform destroy` complet échoue donc volontairement. Pour arrêter la VM sans perdre les données :

```bash
terraform destroy \
  -target=google_compute_instance.devops_lab \
  -target=google_compute_firewall.allow_http
```

Un `terraform apply` recrée la VM et la stack reprend avec les données existantes.

## Technologies

Terraform, Google Cloud Platform (Compute Engine), Docker Compose, Prometheus, Grafana, Node Exporter, Caddy, Cloudflare.

## Licence

[MIT](LICENSE)
