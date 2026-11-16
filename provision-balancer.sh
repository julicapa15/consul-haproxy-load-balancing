#!/usr/bin/env bash
# ============================================================================
# provision-balancer.sh  ->  balancer (Consul client + HAProxy + consul-template)
# Aprovisiona el balanceador: agente Consul (client) + HAProxy + consul-template.
# consul-template lee el servicio "web" de Consul y regenera solo la config de
# HAProxy. Incluye pagina 503 personalizada y GUI de estadisticas en :8404.
# ============================================================================
set -e

BIND_IP="192.168.100.10"
SERVER_IP="192.168.100.3"    # IP del servidor Consul

# --- 1. Instalar Consul, consul-template y HAProxy ---
if ! command -v consul >/dev/null; then
  apt-get update -y
  apt-get install -y curl gpg lsb-release
  curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
  apt-get update -y
fi
apt-get install -y consul consul-template haproxy

# --- 2. Configuracion de Consul (agente cliente) ---
cat > /etc/consul.d/consul.hcl <<EOF
datacenter  = "dc1"
data_dir    = "/opt/consul"
server      = false
bind_addr   = "${BIND_IP}"
client_addr = "0.0.0.0"
retry_join  = ["${SERVER_IP}"]
EOF

# --- 3. Arreglo de systemd para Consul ---
mkdir -p /etc/systemd/system/consul.service.d
cat > /etc/systemd/system/consul.service.d/override.conf <<EOF
[Service]
Type=exec
RuntimeMaxSec=infinity
EOF

# --- 4. Pagina 503 personalizada (cuando NO hay servidores disponibles) ---
cat > /etc/haproxy/errors/503-custom.http <<'EOF'
HTTP/1.0 503 Service Unavailable
Cache-Control: no-cache
Connection: close
Content-Type: text/html; charset=utf-8

<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><title>Sitio no disponible</title></head>
<body style="font-family:sans-serif;text-align:center;margin-top:80px">
<h1>503 - Sitio no disponible</h1>
<p>Lo sentimos, en este momento no hay servidores disponibles para atender tu solicitud.</p>
<p>Por favor intenta de nuevo en unos minutos.</p>
</body>
</html>
EOF

# --- 5. Plantilla de HAProxy (consul-template la convierte en haproxy.cfg) ---
cat > /etc/haproxy/haproxy.ctmpl <<'EOF'
global
    log /dev/log local0
    maxconn 2048

defaults
    log     global
    mode    http
    option  httplog
    option  http-server-close
    timeout connect 5s
    timeout client  30s
    timeout server  30s
    errorfile 503 /etc/haproxy/errors/503-custom.http

frontend http_front
    bind *:80
    default_backend http_back

backend http_back
    balance roundrobin
{{ range service "web" }}
    server {{ .Node }}-{{ .Port }} {{ .Address }}:{{ .Port }} check
{{ end }}

listen stats
    bind *:8404
    stats enable
    stats uri /
    stats refresh 5s
EOF

# --- 6. Configuracion de consul-template ---
mkdir -p /etc/consul-template.d
cat > /etc/consul-template.d/haproxy.hcl <<EOF
consul {
  address = "127.0.0.1:8500"
}

template {
  source      = "/etc/haproxy/haproxy.ctmpl"
  destination = "/etc/haproxy/haproxy.cfg"
  command     = "systemctl reload haproxy"
}
EOF

# --- 7. Servicio systemd de consul-template ---
cat > /etc/systemd/system/consul-template.service <<EOF
[Unit]
Description=consul-template
After=network.target consul.service

[Service]
ExecStart=/usr/bin/consul-template -config=/etc/consul-template.d/haproxy.hcl
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# --- 8. Arrancar todo ---
systemctl daemon-reload
systemctl enable consul haproxy consul-template
systemctl restart consul
systemctl enable --now haproxy
sleep 3
systemctl restart consul-template

echo ">> Balanceador en ${BIND_IP} configurado"
