#!/usr/bin/env bash
# ============================================================================
# provision-web1.sh  ->  servidorUbuntu (Consul server + 2 apps Node.js)
# Aprovisiona un nodo web: agente Consul (server o client) + 2 instancias
# Node.js (puertos 3000 y 3001) + registro de ambas en Consul como servicio "web".
# Se ejecuta automaticamente desde el Vagrantfile.
# ============================================================================
set -e

BIND_IP="192.168.100.3"
ROLE="server"
SERVER_IP="192.168.100.3"    # IP del servidor Consul (servidorUbuntu)

# --- 1. Instalar Consul desde el repo oficial de HashiCorp (solo si falta) ---
if ! command -v consul >/dev/null; then
  apt-get update -y
  apt-get install -y curl gpg lsb-release
  curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
  apt-get update -y
  apt-get install -y consul
fi

# --- 2. Configuracion de Consul segun el rol ---
if [ "$ROLE" = "server" ]; then
cat > /etc/consul.d/consul.hcl <<EOF
datacenter       = "dc1"
data_dir         = "/opt/consul"
server           = true
bootstrap_expect = 1
bind_addr        = "${BIND_IP}"
client_addr      = "0.0.0.0"
ui_config { enabled = true }
EOF
else
cat > /etc/consul.d/consul.hcl <<EOF
datacenter  = "dc1"
data_dir    = "/opt/consul"
server      = false
bind_addr   = "${BIND_IP}"
client_addr = "0.0.0.0"
retry_join  = ["${SERVER_IP}"]
EOF
fi

# --- 3. Arreglo de systemd: marca Consul "activo" al arrancar (sin esperar señal) ---
mkdir -p /etc/systemd/system/consul.service.d
cat > /etc/systemd/system/consul.service.d/override.conf <<EOF
[Service]
Type=exec
RuntimeMaxSec=infinity
EOF

# --- 4. Instalar Node.js 20 (solo si falta) ---
if ! command -v node >/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

# --- 5. Crear la app web (responde su hostname y tiene ruta /health) ---
cat > /home/vagrant/app.js <<'EOF'
const http = require('http');
const os = require('os');
const PORT = process.env.PORT || 3000;
http.createServer((req, res) => {
  if (req.url === '/health') { res.writeHead(200); res.end('OK'); return; }
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Hola desde ' + os.hostname() + ' en el puerto ' + PORT + '\n');
}).listen(PORT, () => console.log('Web escuchando en ' + PORT));
EOF

# --- 6. Limpiar servicios/registros de versiones anteriores (idempotencia) ---
systemctl disable --now webapp webapp2 2>/dev/null || true
rm -f /etc/systemd/system/webapp.service /etc/systemd/system/webapp2.service
rm -f /etc/consul.d/web.hcl /etc/consul.d/web2.hcl

# --- 7. Dos instancias de la app como servicios systemd (puertos 3000 y 3001) ---
for P in 3000 3001; do
cat > /etc/systemd/system/webapp-${P}.service <<EOF
[Unit]
Description=Web App Node.js puerto ${P}
After=network.target

[Service]
Environment=PORT=${P}
ExecStart=/usr/bin/node /home/vagrant/app.js
Restart=always
User=vagrant

[Install]
WantedBy=multi-user.target
EOF
done

# --- 8. Registrar las 2 instancias en Consul (un archivo por instancia) ---
cat > /etc/consul.d/web-3000.hcl <<EOF
service {
  id   = "web-3000"
  name = "web"
  port = 3000
  check {
    http     = "http://localhost:3000/health"
    interval = "10s"
    timeout  = "2s"
  }
}
EOF

cat > /etc/consul.d/web-3001.hcl <<EOF
service {
  id   = "web-3001"
  name = "web"
  port = 3001
  check {
    http     = "http://localhost:3001/health"
    interval = "10s"
    timeout  = "2s"
  }
}
EOF

# --- 9. Arrancar / recargar todo ---
systemctl daemon-reload
systemctl enable consul webapp-3000 webapp-3001
systemctl restart consul
systemctl restart webapp-3000 webapp-3001
sleep 2
consul reload || true

echo ">> Nodo web (${ROLE}) en ${BIND_IP} configurado"
