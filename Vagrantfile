# -*- mode: ruby -*-
# vi: set ft=ruby :
# Microproyecto 1 - Cluster Consul + HAProxy (consul-template) + Artillery

Vagrant.configure("2") do |config|
  config.vm.define :clienteUbuntu do |clienteUbuntu|
    clienteUbuntu.vm.box = "bento/ubuntu-22.04"
    clienteUbuntu.vm.network :private_network, ip: "192.168.100.2"
    clienteUbuntu.vm.hostname = "clienteUbuntu"
    clienteUbuntu.vm.provision "setup", type: "shell", path: "provision-web2.sh"
    clienteUbuntu.vm.provider "vmware_desktop" do |v|
      v.cpus = 2
      v.memory = 4096
    end
  end

  config.vm.define :servidorUbuntu do |servidorUbuntu|
    servidorUbuntu.vm.box = "bento/ubuntu-22.04"
    servidorUbuntu.vm.network :private_network, ip: "192.168.100.3"
    servidorUbuntu.vm.hostname = "servidorUbuntu"
    servidorUbuntu.vm.provision "setup", type: "shell", path: "provision-web1.sh"
    servidorUbuntu.vm.provider "vmware_desktop" do |v|
      v.cpus = 2
      v.memory = 4096
    end
  end

  config.vm.define :balancer do |balancer|
    balancer.vm.box = "bento/ubuntu-22.04"
    balancer.vm.network :private_network, ip: "192.168.100.10"
    balancer.vm.hostname = "balancer"
    balancer.vm.provision "setup", type: "shell", path: "provision-balancer.sh"
    balancer.vm.provider "virtualbox" do |v|
      v.cpus   = 1
      v.memory = 1024
    end
  end
end
