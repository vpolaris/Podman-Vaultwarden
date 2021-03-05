# Create a Podman image from scratch for Bitwarden RS and the Web Vault

The image is based on Fedora Container Base 33.1 with systemd enabled

The Bitwaren RS API and the Vault are automaticaly compiled  froms sources
We use httpd to proxified the service

The image size is about 330MB and contains all needed features to run the Bitwarden Password Manager

Pre requisites

You need to setup a DNS record called 

vault.bitwarden.lan

You need to setup Podman 3.0 on host machine.
Your firewall is configured to accept connection on port 80,443

Si SELinux is active consider apply this settings

#SELinux
semanage fcontext -a -t fusefs_t '/data(/.*)?'

setsebool -P virt_sandbox_use_netlink 1

setsebool -P httpd_can_network_connect on

setsebool -P container_manage_cgroup true

Build Command.

podman build -t bitwarden:1.00 .

Run Command

podman run -d --log-driver=journald --systemd=true --name bitwarden -h bitwarden.lan  -v /data/:/var/lib/bitwarden/data/:rw -p 443:443 bitwarden:1.00

the /data must exist on the host machine to preserve customer's vaultd during container recycling

Go to container shell

podman exec -ti bitwarden /bin/bash

Access to bitwarden via the link
https://vault.bitwarden.lan


Sources:
https://fiat-tux.fr/2019/01/14/installer-un-serveur-bitwarden_rs/
https://illuad.fr/2020/06/11/install-a-bitwarden-rs-server.html

