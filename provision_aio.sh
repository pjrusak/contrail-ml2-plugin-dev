#!/usr/bin/env bash
set -x

USER='centos'
TARGET='10.100.0.88'
SSH_KEY='~/.ssh/kube_aws_rsa'

cmd_on_remote_vm() {
  local cmd=$1

  ssh -i ${SSH_KEY} ${USER}@${TARGET} -t ${cmd}
}

copy_to_remote_vm() {
  local src=$1

  scp -i ${SSH_KEY} -r ${src} ${USER}@${TARGET}:~/
}

wait_for_ssh(){
   cmd_on_remote_vm 'exit'
   while test $? -gt 0
   do
     sleep 15 
     echo "Waiting for ${TARGET} to boot up..."
     cmd_on_remote_vm 'exit'
   done
}

copy_to_remote_vm ./config
copy_to_remote_vm ./patch

cmd_on_remote_vm 'sudo yum install -y epel-release'
cmd_on_remote_vm 'sudo yum install -y git ack tree wget vim jq patch ansible-2.4.*'
cmd_on_remote_vm 'sudo yum update -y'
cmd_on_remote_vm 'sudo reboot'

wait_for_ssh || true

cmd_on_remote_vm 'ssh-keygen -b 4096 -f ~/.ssh/id_rsa -N ""'
cmd_on_remote_vm 'sudo ssh-keygen -b 4096 -f /root/.ssh/id_rsa -N ""'
cmd_on_remote_vm 'sudo cat /root/.ssh/id_rsa.pub | sudo tee --append /root/.ssh/authorized_keys'

cmd_on_remote_vm 'git clone https://github.com/Juniper/contrail-ansible-deployer'
cmd_on_remote_vm 'git clone https://git.openstack.org/openstack-dev/devstack -b stable/ocata'
cmd_on_remote_vm 'cp ~/config/contrail-ansible-deployer/instances-noc.yaml ~/contrail-ansible-deployer/config/instances.yaml'
cmd_on_remote_vm 'cp ~/config/devstack/local-noc.conf ~/devstack/local.conf'

cmd_on_remote_vm 'cd ~/contrail-ansible-deployer && sudo ansible-playbook -i inventory/ -e "{\"contrail_configuration\": {\"CLOUD_ORCHESTRATOR\": \"none\"}}" playbooks/configure_instances.yml'

cmd_on_remote_vm 'sudo usermod -aG docker centos'

cmd_on_remote_vm 'patch -p0 --verbose ~/devstack/stack.sh < ~/patch/devstack/stack.sh.diff'
cmd_on_remote_vm 'cd ~/devstack && ./stack.sh'

cmd_on_remote_vm 'patch -p0 --verbose /etc/neutron/neutron.conf < ~/patch/devstack/neutron.conf.diff'
cmd_on_remote_vm 'patch -p0 --verbose /opt/stack/networking-opencontrail/networking_opencontrail/drivers/drv_opencontrail.py < ~/patch/networking-opencontrail/neutron.conf.diff'
cmd_on_remote_vm 'patch -p0 --verbose /opt/stack/networking-opencontrail/networking_opencontrail/ml2/opencontrail_sg_callback.py < ~/patch/networking-opencontrail/opencontrail_sg_callback.py.diff'
cmd_on_remote_vm 'cd ~/contrail-ansible-deployer && sudo ansible-playbook -i inventory/ -e orchestrator=openstack -e skip_openstack=true playbooks/install_contrail.yml'
cmd_on_remote_vm 'contrail-status'

#vrouter_agent_container=$(cmd_on_remote_vm "docker ps | grep vrouter-agent | tr -s' ' | cut -d' ' -f1")
cmd_on_remote_vm "sudo docker cp config_api_1:/usr/bin/vrouter-port-control /usr/bin"

#config_api_container=$(cmd_on_remote_vm "docker ps | grep confi_api | tr -s' ' | cut -d' ' -f1")
#cmd_on_remote_vm "docker cp ${config_api_container}:/usr/lib/python2.7/site-packages/vnc_openstack/neutron_plugin_db.py ."

#source devstack/openrc admin admin
#openstack keypair create --public-key ~/.ssh/id_rsa.pub centos-key
#openstack project list
#openstack security group create contrail-demo --project d53dc00fc9a04808bd227ef785c40afe
#openstack security group rule create --ingress --protocol icmp --remote-ip 0.0.0.0/0 contrail-demo
#openstack security group rule create --egress --protocol icmp --remote-ip 0.0.0.0/0 contrail-demo
#openstack security group rule create --ingress --protocol tcp --remote-ip 0.0.0.0/0 --dst-port 22 contrail-demo
#openstack security group rule create --egress --protocol tcp --remote-ip 0.0.0.0/0 --dst-port 22 contrail-demo
##openstack security group rule create --ingress --protocol udp --remote-ip 0.0.0.0/0 --dst-port 22 contrail-demo
##openstack security group rule create --egress --protocol udp --remote-ip 0.0.0.0/0 --dst-port 22 contrail-demo
#NET_ID=$(openstack network list | grep network | tr -d ' ' | awk -F '|' '{print $2}')
#openstack server create --flavor m1.tiny --image cirros-0.3.4-x86_64-uec --nic net-id=${NET_ID} --key-name centos-home  --security-group contrail-demo --wait vm1

## not use with devstack ##

#wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
#openstack image create cirros2 --disk-format qcow2 --public --container-format bare --file cirros-0.4.0-#x86_64-disk.img                              
#openstack network create contrail-test
#openstack subnet create --subnet-range 192.168.100.0/24 --network contrail-test subnet
#openstack flavor create --ram 64 --disk 1 --vcpus 1 m1.nano
#NET_ID=`openstack network list | grep contrail-test | awk -F '|' '{print $2}' | tr -d ' '` 
#openstack server create --flavor m1.nano --image cirros2 --nic net-id=${NET_ID} --key-name centos-home #test_vm1
#openstack server create --flavor m1.nano --image cirros2 --nic net-id=${NET_ID} --key-name centos-home #test_vm2 
