# Installation of prereqs.

## To install Choco (cmd)
`@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command " [System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"`

### Verify Choco
`choco`

## WSUS

Server Manager -> Add Roles And Features -> Next -> Role-based or feature-based-installation -> Next -> Destination Server -> Next -> Check "Windows Service Update Services" -> Add Features -> Next -> Next -> Select Role Services -> Next -> Content Location -> Set or Uncheck -> Next -> Next -> Next -> Reboot


WSUS Icon -> Configuration requires..-> More -> Launch Post-installation

## Ansible AWX

```bash
sudo dnf -y install epel-release
sudo dnf -y install dnf-plugins-core
sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
sudo dnf config-manager --set-enabled PowerTools
```

AWX Dependencies:
`sudo dnf install -y git python3-pip curl ansible gcc nodejs gcc-c++ gettext lvm2 device-mapper-persistent-data pwgen bzip2`

### Docker and Docker Compose

```bash
$ sudo curl https://download.docker.com/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
$ sudo yum makecache
$ sudo dnf -y install docker-ce --nobest
```


#### Confirm docker

```bash
$ sudo systemctl enable --now docker
$ systemctl status docker
```

#### Add docker user to group

```bash
$ sudo usermod -aG docker $USER
```

#### Python to docker

```bash
sudo pip3 install -U docker docker-compose
```

#### Clone AWX

```bash
$ cd ~
$ git clone --depth 50 https://github.com/ansible/awx.git
```

#### install directory + encryption

1. `$ cd ~/awx/installer/`
2. `sh pwgen -N 1 -s 30`
3. 
```sh
$ vim inventory
[all:vars]
dockerhub_base=ansible
awx_task_hostname=awx
awx_web_hostname=awxweb
postgres_data_dir="~/.awx/pgdocker"
host_port=80
host_port_ssl=443
docker_compose_dir="~/.awx/awxcompose"
pg_username=awx
pg_password=awxpass
pg_database=awx
pg_port=5432
admin_user=admin
admin_password=SuperSecret
create_preload_data=True
project_data_dir=/var/lib/awx/projects ##Directory For playbooks inside the server
awx_alternate_dns_servers="8.8.8.8,8.8.4.4"
secret_key=yBs76VurxRiBwtDHrrF2JJlLgVrcv3
awx_official=true
```
4. Check firewall rules

    `$ sudo firewall-cmd --zone=public --add-masquerade --permanent`
    <br/>
    `$ sudo firewall-cmd --permanent --add-service={http,https}`
    <br/>
    `$ sudo firewall-cmd --reload`

#### Adding AWX project data folder

`$ sudo mkdir -p /var/lib/awx/projects`

Now we run playbook

`sudo ansible-playbook -i inventory install.yml`

And check the container statuses

`docker ps`

## Prepare Ansible Remote

```ps
PS > Invoke-WebRequest -Uri https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1 -OutFile ConfigureRemotingForAnsible.ps1
PS > powershell -ExecutionPolicy RemoteSigned .\ConfigureRemotingForAnsible.ps1
...
Ok.
```

Check for winrm listeners

`winrm enumerate winrm/config/Listener`

### Execute Ansible playbook in Windows

*Has to have 'windows' defined in /etc/ansible/hosts(or something else)*
```sh
ansible -i windows -m win_ping -e ansible_connection=winrm \
-e ansible_user=<Our-Windows-User> -e ansible_password=<Our-Windows-Password> \
-e ansible_winrm_transport=basic \
-e ansible_winrm_server_cert_validation=ignore
```



# If all else fails, look into
[CodePre](https://codepre.com/use-ansible-to-automate-windows-server-2019-and-windows-10-management.html) - simple with screenshots <br/>
[BobCares](https://bobcares.com/blog/windows-server-2019-administration-with-ansible/) - rather compicated and verbose <br/>
[AwsBlogLink](https://awsbloglink.wordpress.com/2018/10/06/how-to-use-ansible-to-manage-windows-server-2019/) - Most basic