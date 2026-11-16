<div align="center">

# Microproyecto 1 — Cluster Consul + Balanceo HAProxy + Artillery

[![Vagrant](https://img.shields.io/badge/Vagrant-provisioning-1868F2?logo=vagrant&logoColor=white)](https://www.vagrantup.com/)
[![VirtualBox](https://img.shields.io/badge/VirtualBox-VMs-183A61?logo=virtualbox&logoColor=white)](https://www.virtualbox.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Consul](https://img.shields.io/badge/Consul-service_discovery-F24C53?logo=consul&logoColor=white)](https://www.consul.io/)
[![HAProxy](https://img.shields.io/badge/HAProxy-load_balancer-106DA9)](https://www.haproxy.org/)
[![Node.js](https://img.shields.io/badge/Node.js-20-5FA04E?logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![Artillery](https://img.shields.io/badge/Artillery-load_testing-CC0033)](https://www.artillery.io/)

*[Read in English](README.md)*

</div>

Service mesh con **HashiCorp Consul**, balanceo de carga con **HAProxy** integrado a Consul
mediante **consul-template** (service discovery), y pruebas de carga con **Artillery**.
Todo aprovisionado automáticamente con **Vagrant** (provisionador shell).

## Arquitectura

| Máquina         | IP privada       | Rol                                                        |
|-----------------|------------------|------------------------------------------------------------|
| `servidorUbuntu`| 192.168.100.3    | Consul **server** + 2 apps Node.js (puertos 3000 y 3001)   |
| `clienteUbuntu` | 192.168.100.2    | Consul **client** + 2 apps Node.js (puertos 3000 y 3001)   |
| `balancer`      | 192.168.100.10   | Consul **client** + **HAProxy** + **consul-template**      |

```
   Cliente/Host
        |
        v
   [ HAProxy ]  <-- consul-template regenera su config leyendo el servicio "web" de Consul
   192.168.100.10
     /       \
 web (3000/3001)   web (3000/3001)
 servidorUbuntu     clienteUbuntu
     \       /
   [ Cluster Consul: 1 server + 2 clients ]
```

## Requisitos

- VirtualBox
- Vagrant

## Ejecución

```bash
vagrant up
```

Levanta las 3 VMs y las configura solas (instala Consul, Node.js, HAProxy y consul-template,
despliega las apps, registra el servicio `web` y genera la config de HAProxy).

Para re-aplicar solo el aprovisionamiento sin recrear las VMs:

```bash
vagrant provision --provision-with setup
```

## Accesos (desde el host)

- Aplicación balanceada: http://192.168.100.10
- GUI de estadísticas HAProxy: http://192.168.100.10:8404
- Interfaz web de Consul: http://192.168.100.3:8500/ui

## Cómo probar cada requisito

**Balanceo (round-robin):**
```bash
vagrant ssh balancer -c "for i in 1 2 3 4; do curl -s localhost; done"
```
Alterna entre `servidorUbuntu` y `clienteUbuntu`.

**Manejo de disponibilidad (health check):** apaga una instancia y observa en la GUI cómo pasa a rojo (DOWN) y HAProxy deja de enviarle tráfico:
```bash
vagrant ssh servidorUbuntu -c "sudo systemctl stop webapp-3000 webapp-3001"
```

**Página 503 personalizada (ningún servidor disponible):** apaga todas las instancias:
```bash
vagrant ssh servidorUbuntu -c "sudo systemctl stop webapp-3000 webapp-3001"
vagrant ssh clienteUbuntu  -c "sudo systemctl stop webapp-3000 webapp-3001"
```
Abre http://192.168.100.10 → muestra la página personalizada. Vuelve a iniciarlas con `start`.

**Escalabilidad:** cada nodo ya corre 2 instancias (3000 y 3001). consul-template las detecta
y HAProxy las balancea sin edición manual. En la GUI se ven 4 servidores (`Backend 4/4`).

**Pruebas de carga (Artillery):**
```bash
sudo npm install -g artillery      # en un nodo con Node 18+
artillery run artillery-tests/carga.yml
```

## Nota

La red usa el rango `192.168.100.0/24`. Si al hacer `vagrant up` VirtualBox rechaza la red
host-only, agrega el rango en el archivo `networks.conf` de VirtualBox
(`* 192.168.100.0/24`).
