#!/usr/bin/env bash

source devstack/openrc admin admin
openstack keypair create --public-key ~/.ssh/id_rsa.pub centos-key
openstack project list
openstack security group create contrail-demo --project d53dc00fc9a04808bd227ef785c40afe
openstack security group rule create --ingress --protocol icmp --remote-ip 0.0.0.0/0 contrail-demo
openstack security group rule create --egress --protocol icmp --remote-ip 0.0.0.0/0 contrail-demo
openstack security group rule create --ingress --protocol tcp --remote-ip 0.0.0.0/0 --dst-port 22 contrail-demo
openstack security group rule create --egress --protocol tcp --remote-ip 0.0.0.0/0 --dst-port 22 contrail-demo
NET_ID=$(openstack network list | grep network | tr -d ' ' | awk -F '|' '{print $2}')
openstack server create --flavor cirros256 --image cirros-0.3.4-x86_64-uec --nic net-id=${NET_ID} --key-name centos-home  --security-group contrail-demo --wait vm1

