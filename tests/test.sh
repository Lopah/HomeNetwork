# Exit on any individual command failure.
set -e

# Pretty colors.
red="\033[0;31m"
green="\033[0;32m"
neutral="\033[0m"

timestamp=$(date +%s)

# Allow environment variables to override defaults.
distro=${distro:-"ubuntu2204"}
docker_owner=${docker_owner:-"geerlingguy"}
playbook=${playbook:-"run.yaml"}
cleanup=${cleanup:-"true"}
container_id=${container_id:-$timestamp}
test_syntax=${test_syntax:-"true"}
test_playbook=${test_playbook:-"true"}
test_idempotence=${test_idempotence:-"true"}
init="/lib/systemd/systemd"
opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:rw"
directory="$PWD/src"

# Run the container using the supplied OS.
printf ${green}"Starting Docker container: $docker_owner/docker-$distro-ansible."${neutral}"\n"
docker pull $docker_owner/docker-$distro-ansible:latest
docker run --detach --cgroupns=host --volume=$directory:/etc/ansible/playbooks/playbook_under_test:rw --env ANSIBLE_VAULT_PASSWORD_FILE=/etc/ansible/playbooks/playbook_under_test/passwordfile --name $container_id $opts $docker_owner/docker-$distro-ansible:latest $init

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
  tail $idempotence |
    grep -q 'changed=0.*failed=0' &&
    (printf ${green}'Idempotence test: pass'${neutral}"\n") ||
    (printf ${red}'Idempotence test: fail'${neutral}"\n" && exit 1)
fi

# Remove the Docker container (if configured).
if [ "$cleanup" = true ]; then
  printf "Removing Docker container...\n"
  docker rm -f $container_id
fi
