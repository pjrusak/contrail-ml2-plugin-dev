# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
USER = "vagrant"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

   config.vm.define :contrail_noc do |contrail_noc_config|
      contrail_noc_config.vm.box = "geerlingguy/centos7"
      contrail_noc_config.vm.box_check_update = false
      contrail_noc_config.vm.hostname = "contrail-noc"
      contrail_noc_config.vm.network "private_network", ip: "192.168.100.6"
      contrail_noc_config.vm.network "forwarded_port", guest: 80, host: 8080
      contrail_noc_config.vm.network "forwarded_port", guest: 8180, host: 8180
      contrail_noc_config.vm.network "forwarded_port", guest: 8143, host: 8143
      contrail_noc_config.vm.synced_folder ".", "/vagrant", disabled: true
      contrail_noc_config.ssh.forward_agent = true
      contrail_noc_config.ssh.insert_key = true
      contrail_noc_config.ssh.username = "#{USER}"
      contrail_noc_config.ssh.password = 'vagrant'

      contrail_noc_config.vm.provider "virtualbox" do |vb|
         vb.memory = 12228
         vb.cpus = 6
      end
      contrail_noc_config.vm.provision "shell" do |s|
        ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip
        s.inline = <<-SHELL
          echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys
        SHELL
      end
   end
end
