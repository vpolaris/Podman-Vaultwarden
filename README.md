# Create a Podman image from scratch for Bitwarden RS and the Web Vault

The image is based on Fedora Container Base 33.1 with systemd enabled

The Bitwaren RS API and the Vault are automaticaly compiled  froms sources
We use httpd to proxified the service

The image size is about 330MB and contains all needed features to run the Bitwarden Password Manager

Pre requisites

You need to setup a DNS record called 

vault.bitwarden.lan

You need to setup Podman 3.0 on host machine 
your firewall is configured to accept connection on port 80,443












