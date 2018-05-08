#!/usr/bin/env bash
set -xe

USER="vagrant"
TARGET="192.168.100.6"
SSH_KEY="~/.ssh/id_rsa"

ANSIBLE_DEPLOYER_REPO="https://github.com/Juniper/contrail-ansible-deployer"
ANSIBLE_DEPLOYER_BRANCH=${ANSIBLE_DEPLOYER_BRANCH:-master}
 
DEVSTACK_REPO="https://git.openstack.org/openstack-dev/devstack"
DEVSTACK_BRANCH="stable/ocata"
DEVSTACK_BRANCH=${DEVSTACK_BRANCH:-master}

TOP_DIR=$(cd $(dirname "$0") && pwd)
SSH_WRAPPER="ssh -i ${SSH_KEY} ${USER}@${TARGET}"

source ${TOP_DIR}/lib/common.sh

if [[ ! -d "${TOP_DIR}/logs" ]]
then
   mkdir -p "${TOP_DIR}/logs"
fi

copy_to_remote_vm "${TOP_DIR}/config"
copy_to_remote_vm "${TOP_DIR}/patch"

${SSH_WRAPPER} -T "sudo yum install -y epel-release git ack tree wget vim jq patch ansible-2.4.*"

kernel_version=$(${SSH_WRAPPER} -T "uname -r")
${SSH_WRAPPER} -T "sudo yum update -y"
updated_kernel_version=$(${SSH_WRAPPER} -T "rpm -q kernel --last | head -1 | cut -d' ' -f1 | sed -e 's/kernel-//'")

if [[ $kernel_version != $updated_kernel_version ]]
then
  ${SSH_WRAPPER} -T "sudo reboot" || true
  wait_for_ssh || true
fi

${SSH_WRAPPER} -T bash -c "'
    yes | ssh-keygen -b 4096 -f ~/.ssh/centos_rsa -N \"\"
    yes | sudo ssh-keygen -b 4096 -f /root/.ssh/root_rsa -N \"\"
'"

${SSH_WRAPPER} -T bash -c "'
    sudo cat /root/.ssh/root_rsa.pub | sudo tee --append /root/.ssh/authorized_keys
    if [[ ! -d \"~/${ANSIBLE_DEPLOYER_REPO}\" ]]
    then
        git clone ${ANSIBLE_DEPLOYER_REPO} -b ${ANSIBLE_DEPLOYER_BRANCH}
        cp ~/config/contrail-ansible-deployer/instances-noc.yaml ~/contrail-ansible-deployer/config/instances.yaml
    fi
    if [[ ! -d \"~/${ANSIBLE_DEPLOYER_REPO}\" ]]
    then
        git clone ${DEVSTACK_REPO} -b ${DEVSTACK_BRANCH}
        cp ~/config/devstack/local-noc.conf ~/devstack/local.conf
    fi
'"


${SSH_WRAPPER} -t bash -c "'
    cd ~/contrail-ansible-deployer && \
    sudo ansible-playbook -i inventory/ \
         -e \"{\"contrail_configuration\": {\"CLOUD_ORCHESTRATOR\": \"none\"}}\" \
	 playbooks/configure_instances.yml
'"

${SSH_WRAPPER} -T bash -c "'
    sudo usermod -aG docker ${USER}
    patch -p0 --verbose ~/devstack/stack.sh < ~/patch/devstack/stack.sh.diff
'"


${SSH_WRAPPER} -t bash -c "'
    cd ~/devstack && ./stack.sh
'"

${SSH_WRAPPER} -t bash -c "'
    cd ~/contrail-ansible-deployer && \
    sudo ansible-playbook -i inventory/ \
         -e orchestrator=openstack \
         -e skip_openstack=true \
	 playbooks/install_contrail.yml
'"


${SSH_WRAPPER} -T bash -c "'
    contrail-status
    sudo docker cp vrouter_vrouter-agent_1:/usr/bin/vrouter-port-control /usr/bin
'"

