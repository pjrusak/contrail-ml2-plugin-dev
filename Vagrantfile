# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
USER = "vagrant"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

   config.vm.define :contrail_noc do |contrail_noc_config|
      contrail_noc_config.vm.box = "centos/7"
      contrail_noc_config.vm.box_check_update = false
      contrail_noc_config.vm.hostname = "contrail-noc"
      contrail_noc_config.vm.network "private_network", ip: "192.168.100.6"
      contrail_noc_config.vm.synced_folder ".", "/vagrant", disabled: true
      contrail_noc_config.ssh.forward_agent = true
      contrail_noc_config.ssh.insert_key = true
      contrail_noc_config.ssh.username = "#{USER}"

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
