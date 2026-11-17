# Stack de monitoring : Prometheus + Grafana + Node Exporter + Caddy (HTTPS)
#
# Script de démarrage de la VM. Il s'exécute à chaque boot et doit rester idempotent.
#
# Attention aux niveaux d'échappement dans ce heredoc Terraform :
#   - ${...} et %{...} : interpolation / directive Terraform (écrire $${ ou %%{ pour un littéral)
#   - $VAR             : variable shell, développée dans les heredocs shell non quotés (<<EOF)
#   - $$               : dans docker-compose.yml, produit un "$" littéral pour Compose

locals {
  startup_script = <<-EOT
    #!/bin/bash
    set -e
    export LANG=C.UTF-8
    export DEBIAN_FRONTEND=noninteractive

    DOMAIN="${var.domain}"
    DATA_DIR="/mnt/disks/grafana"
    DEVICE_PATH="/dev/disk/by-id/google-grafana-data"

    # --- Docker -------------------------------------------------------------
    if ! command -v docker >/dev/null 2>&1; then
      apt-get update
      apt-get install -y curl
      curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
      sh /tmp/get-docker.sh
    fi
    systemctl enable --now docker

    # --- Disque persistant --------------------------------------------------
    while [ ! -e "$DEVICE_PATH" ]; do
      echo "Waiting for disk..."
      sleep 1
    done

    # Formater uniquement si le disque n'a pas de système de fichiers
    if ! blkid "$DEVICE_PATH" >/dev/null 2>&1; then
      echo "Formatting disk..."
      mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard "$DEVICE_PATH"
    fi

    mkdir -p "$DATA_DIR"
    if ! mountpoint -q "$DATA_DIR"; then
      mount -o discard,defaults "$DEVICE_PATH" "$DATA_DIR"
    fi
    grep -q "$DEVICE_PATH" /etc/fstab || echo "$DEVICE_PATH $DATA_DIR ext4 discard,defaults,nofail 0 2" >> /etc/fstab

    # --- Répertoires de données (UID des images officielles) ----------------
    mkdir -p "$DATA_DIR"/{telemetry,caddy_data,caddy_config,grafana_data,prometheus_data,secrets}
    chown -R 472:0 "$DATA_DIR/grafana_data"              # grafana
    chown -R 65534:65534 "$DATA_DIR/prometheus_data"     # nobody (prometheus)

    # Mot de passe admin Grafana, transmis en base64 pour éviter tout problème d'échappement
    echo '${base64encode(var.grafana_admin_password)}' | base64 -d > "$DATA_DIR/secrets/grafana_admin_password"
    chown 472:0 "$DATA_DIR/secrets/grafana_admin_password"
    chmod 400 "$DATA_DIR/secrets/grafana_admin_password"

    cd "$DATA_DIR/telemetry"

    # --- docker-compose.yml -------------------------------------------------
    cat <<EOF > docker-compose.yml
    services:
      caddy:
        image: caddy:2-alpine
        container_name: caddy
        restart: unless-stopped
        ports:
          - "80:80"
          - "443:443"
        volumes:
          - ./Caddyfile:/etc/caddy/Caddyfile:ro
          - $DATA_DIR/caddy_data:/data
          - $DATA_DIR/caddy_config:/config
        depends_on:
          - grafana

      prometheus:
        image: prom/prometheus
        container_name: prometheus
        restart: unless-stopped
        ports:
          - "127.0.0.1:9090:9090" # Accessible uniquement via tunnel SSH
        volumes:
          - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
          - $DATA_DIR/prometheus_data:/prometheus
        command:
          - "--config.file=/etc/prometheus/prometheus.yml"
          - "--storage.tsdb.path=/prometheus"

      grafana:
        image: grafana/grafana-oss
        container_name: grafana
        restart: unless-stopped
        volumes:
          - $DATA_DIR/grafana_data:/var/lib/grafana
          - $DATA_DIR/secrets/grafana_admin_password:/run/secrets/grafana_admin_password:ro
        environment:
          - GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/grafana_admin_password
          - GF_SERVER_ROOT_URL=https://$DOMAIN
        depends_on:
          - prometheus

      node-exporter:
        image: prom/node-exporter
        container_name: node-exporter
        restart: unless-stopped
        volumes:
          - /proc:/host/proc:ro
          - /sys:/host/sys:ro
          - /:/rootfs:ro
        command:
          - "--path.procfs=/host/proc"
          - "--path.sysfs=/host/sys"
          - "--path.rootfs=/rootfs"
          - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(\$$|/)"
    EOF

    # --- Caddyfile (reverse proxy avec HTTPS automatique) -------------------
    cat <<EOF > Caddyfile
    $DOMAIN {
        reverse_proxy grafana:3000
    }
    EOF

    # --- prometheus.yml -----------------------------------------------------
    cat <<'EOF' > prometheus.yml
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['prometheus:9090']

      - job_name: 'node'
        static_configs:
          - targets: ['node-exporter:9100']
    EOF

    docker compose up -d

    echo "Stack de monitoring démarrée : https://$DOMAIN"
  EOT
}
