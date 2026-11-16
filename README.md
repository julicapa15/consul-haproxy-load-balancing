# Load Balancing with Service Discovery: Consul + HAProxy + Artillery

*[Leer en español](README.es.md)*

Infrastructure project that provisions a three-VM cluster with Vagrant, in which a HashiCorp Consul cluster keeps track of the running Node.js web services while an HAProxy load balancer regenerates its own configuration from Consul's service catalog through consul-template. The setup covers round-robin balancing, health checks that take failed instances out of rotation, a custom 503 page when no backend is available and scaling without manual changes, and it was validated with Artillery load tests.

**My role:** I developed this individual project for the Cloud Computing course of my AI Specialization, designing the architecture, writing the provisioning scripts and running the availability and load tests.

## Architecture

| Machine | Private IP | Role |
|---|---|---|
| `servidorUbuntu` | 192.168.100.3 | Consul **server** + 2 Node.js apps (ports 3000 and 3001) |
| `clienteUbuntu` | 192.168.100.2 | Consul **client** + 2 Node.js apps (ports 3000 and 3001) |
| `balancer` | 192.168.100.10 | Consul **client** + **HAProxy** + **consul-template** |

```
   Client/Host
        |
        v
   [ HAProxy ]  <-- consul-template rebuilds its config from the "web" service in Consul
   192.168.100.10
     /       \
 web (3000/3001)   web (3000/3001)
 servidorUbuntu     clienteUbuntu
     \       /
   [ Consul cluster: 1 server + 2 clients ]
```

## Requirements

- VirtualBox
- Vagrant

## Running it

```bash
vagrant up
```

This brings up the three VMs and configures them automatically: it installs Consul, Node.js, HAProxy and consul-template, deploys the apps, registers the `web` service and generates the HAProxy configuration.

To re-run only the provisioning without recreating the VMs:

```bash
vagrant provision --provision-with setup
```

## Access from the host

- Load-balanced application: http://192.168.100.10
- HAProxy statistics dashboard: http://192.168.100.10:8404
- Consul web UI: http://192.168.100.3:8500/ui

## How to test each requirement

**Round-robin balancing**

```bash
vagrant ssh balancer -c "for i in 1 2 3 4; do curl -s localhost; done"
```

Responses alternate between `servidorUbuntu` and `clienteUbuntu`.

**Availability through health checks.** Stop one instance and watch it turn red (DOWN) in the dashboard while HAProxy stops sending it traffic:

```bash
vagrant ssh servidorUbuntu -c "sudo systemctl stop webapp-3000 webapp-3001"
```

**Custom 503 page when no server is available.** Stop every instance:

```bash
vagrant ssh servidorUbuntu -c "sudo systemctl stop webapp-3000 webapp-3001"
vagrant ssh clienteUbuntu  -c "sudo systemctl stop webapp-3000 webapp-3001"
```

Opening http://192.168.100.10 now shows the custom page. Bring the instances back with `start`.

**Scalability.** Each node already runs two instances on ports 3000 and 3001, which consul-template detects and HAProxy balances without any manual edits, so the dashboard shows four servers (`Backend 4/4`).

**Load testing with Artillery.** The test runs in three phases: a 20-second warm-up at 5 requests per second, 40 seconds of sustained load at 20 and a 20-second traffic peak at 50.

```bash
sudo npm install -g artillery      # on a node with Node 18+
artillery run artillery-tests/carga.yml
```

## Note

The network uses the `192.168.100.0/24` range. If VirtualBox rejects the host-only network during `vagrant up`, add the range to VirtualBox's `networks.conf` file (`* 192.168.100.0/24`).
