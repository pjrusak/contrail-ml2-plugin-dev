#!/usr/bin/env bash
set -x

copy_to_remote_vm() {
  local src=$1

  scp -i ${SSH_KEY} -r ${src} ${USER}@${TARGET}:~/
}

wait_for_ssh(){
   local check_ssh_connectivity="${SSH_WRAPPER} -T exit"

   $check_ssh_connectivity
   while test $? -gt 0
   do
     sleep 15 
     echo "Waiting for ${TARGET} to boot up..."
     $check_ssh_connectivity
   done
}

