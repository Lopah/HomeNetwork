#!/bin/bash
#
# Ansible playbook tester.
#
# Usage: [OPTIONS] .tests/test.sh
#   - distro: a supported Docker distro version (default = "ubuntu2004")
#   - playbook: a playbook in the tests directory (default = "run.yaml")
#   - cleanup: whether to remove the Docker container (default = true)
#   - container_id: the --name to set for the container (default = timestamp)
#   - test_idempotence: whether to test playbook's idempotence (default = true)
#

# Exit on any individual command failure.
set -e

# Pretty colors.
red='\033[0;31m'
green='\033[0;32m'
neutral='\033[0m'

timestamp=$(date +%s)

# Allow environment variables to override defaults.
distro=${distro:-"ubuntu2004"}
docker_owner=${docker_owner:-"geerlingguy"}
playbook=${playbook:-"run.yaml"}
cleanup=${cleanup:-"true"}
container_id=${container_id:-$timestamp}
test_syntax=${test_syntax:-"true"}
test_playbook=${test_playbook:-"true"}
test_idempotence=${test_idempotence:-"true"}
init="/lib/systemd/systemd"
opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
directory="$PWD/src"
create_mac_vlan=${create_mac_vlan:-"true"}
# reserved_ip_addresses=${reserved_ip_addresses:-("r1 192.168.0.2" "r2 192.168.0.3" "r3 192.168.0.4" "r4 192.168.0.5")}

# Create MacVLAN network that bridges our container to the rest of the local network.
if [ "$create_mac_vlan" = true ]; then
  printf ${green}"Creating MacVLAN for the container to work locally.\n"
  # excluded_addresses = ""
  # for excluded_address in $reserved_ip_addresses
  # do
  # excluded_addresses += excluded_address
  # done
  docker network create -d macvlan \
  --subnet=192.168.0.0/24 \
  --gateway=192.168.0.1 \
  -o parent=eth0.50 pub_net
fi

# Run the container using the supplied OS.
printf ${green}"Starting Docker container: $docker_owner/docker-$distro-ansible."${neutral}"\n"
docker pull $docker_owner/docker-$distro-ansible:latest
docker run --detach --network=pub_net --dns="192.168.0.20" --volume=$directory:/etc/ansible/playbooks/playbook_under_test:rw --env ANSIBLE_VAULT_PASSWORD_FILE=/etc/ansible/playbooks/playbook_under_test/passwordfile --name $container_id $opts $docker_owner/docker-$distro-ansible:latest $init

printf "\n"

# Install requirements if `requirements.yaml` is present.
if [ -f "$directory/requirements.yaml" ]; then
  printf ${green}"Requirements file detected; installing dependencies."${neutral}"\n"
  docker exec --tty $container_id env TERM=xterm ansible-galaxy install -r /etc/ansible/playbooks/playbook_under_test/requirements.yaml
fi

printf "\n"

# Output Ansible version
printf ${green}"Checking Ansible version."${neutral}"\n"
docker exec --tty $container_id env TERM=xterm ansible-playbook --version

printf "\n"

if [ "$test_syntax" = true ]; then
  # Test Ansible syntax.
  printf ${green}"Checking Ansible playbook syntax."${neutral}"\n"
  docker exec --tty $container_id env TERM=xterm ansible-playbook /etc/ansible/playbooks/playbook_under_test/$playbook --syntax-check
fi

printf "\n"

if [ "$test_playbook" = true ]; then
  # Run Ansible playbook.
  printf ${green}"Running command: docker exec $container_id env TERM=xterm ansible-playbook /etc/ansible/playbooks/playbook_under_test/$playbook"${neutral}"\n"
  docker exec $container_id env TERM=xterm env ANSIBLE_FORCE_COLOR=1 ansible-playbook /etc/ansible/playbooks/playbook_under_test/$playbook 
fi

printf "\n"

if [ "$test_idempotence" = true ]; then
  # Run Ansible playbook again (idempotence test).
  printf ${green}"Running playbook again: idempotence test"${neutral}
  idempotence=$(mktemp)
  docker exec $container_id ansible-playbook /etc/ansible/playbooks/playbook_under_test/$playbook | tee -a $idempotence
  tail $idempotence \
    | grep -q 'changed=0.*failed=0' \
    && (printf ${green}'Idempotence test: pass'${neutral}"\n") \
    || (printf ${red}'Idempotence test: fail'${neutral}"\n" && exit 1)
fi

# Remove the Docker container (if configured).
if [ "$cleanup" = true ]; then
  printf "Removing Docker container...\n"
  docker rm -f $container_id
fi