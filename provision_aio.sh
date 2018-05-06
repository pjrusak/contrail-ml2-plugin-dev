#!/usr/bin/env bash
set -x

USER='vagrant'
TARGET='192.168.100.6'
SSH_KEY='~/.ssh/id_rsa'

TOP_DIR=$(cd $(dirname "$0") && pwd)

cmd_on_remote_vm() {
  local cmd=$1
  local extra_opts=${2:-}

  ssh -i ${SSH_KEY} ${USER}@${TARGET} ${extra_opts} ${cmd}
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

if [[ ! -d "${TOP_DIR}/logs" ]]
then
   mkdir -p "${TOP_DIR}/logs"
fi

copy_to_remote_vm "${TOP_DIR}/config"
copy_to_remote_vm "${TOP_DIR}/patch"

cmd_on_remote_vm "sudo yum install -y epel-release git ack tree wget vim jq patch ansible-2.4.*"

kernel_version=$(cmd_on_remote_vm "uname -r")
cmd_on_remote_vm "sudo yum update -y"
updated_kernel_version=$(cmd_on_remote_vm "rpm -q kernel --last | head -1 | cut -d' ' -f1 | sed -e 's/kernel-//'")

if [[ $kernel_version != $updated_kernel_version ]]
then
  cmd_on_remote_vm 'sudo reboot'
  wait_for_ssh || true
fi

cmd_on_remote_vm 'ssh-keygen -b 4096 -f ~/.ssh/id_rsa -N ""'
cmd_on_remote_vm 'sudo ssh-keygen -b 4096 -f /root/.ssh/id_rsa -N ""'
cmd_on_remote_vm 'sudo cat /root/.ssh/id_rsa.pub | sudo tee --append /root/.ssh/authorized_keys'

cmd_on_remote_vm 'git clone https://github.com/Juniper/contrail-ansible-deployer'
cmd_on_remote_vm 'git clone https://git.openstack.org/openstack-dev/devstack -b stable/ocata'
cmd_on_remote_vm 'cp ~/config/contrail-ansible-deployer/instances-noc.yaml ~/contrail-ansible-deployer/config/instances.yaml'
cmd_on_remote_vm 'cp ~/config/devstack/local-noc.conf ~/devstack/local.conf'

cmd_on_remote_vm 'cd ~/contrail-ansible-deployer && sudo ansible-playbook -i inventory/ -e "{\"contrail_configuration\": {\"CLOUD_ORCHESTRATOR\": \"none\"}}" playbooks/configure_instances.yml' -t

cmd_on_remote_vm "sudo usermod -aG docker ${USER}"

cmd_on_remote_vm 'patch -p0 --verbose ~/devstack/stack.sh < ~/patch/devstack/stack.sh.diff'
cmd_on_remote_vm 'cd ~/devstack && ./stack.sh' -t

cmd_on_remote_vm 'patch -p0 --verbose /opt/stack/networking-opencontrail/networking_opencontrail/ml2/opencontrail_sg_callback.py < ~/patch/networking-opencontrail/opencontrail_sg_callback.py.diff'
cmd_on_remote_vm 'cd ~/contrail-ansible-deployer && sudo ansible-playbook -i inventory/ -e orchestrator=openstack -e skip_openstack=true playbooks/install_contrail.yml' -t
cmd_on_remote_vm 'contrail-status'

cmd_on_remote_vm "sudo docker cp vrouter_vrouter-agent_1:/usr/bin/vrouter-port-control /usr/bin"

