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

