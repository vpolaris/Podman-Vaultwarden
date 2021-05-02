# Podman Vaultwarden Project
## _Vaultwarden Powered by Podman_

[![N|Solid](https://raw.githubusercontent.com/containers/podman/master/logo/podman-logo.png)](https://podman.io/getting-started/)

This project want to build a podman container to host a complete solution of [Vaultwarden API][bitwarden-rs] and a [Web vault][Web-vault]: interface. Which is proxified by an Apache web server and initialized by Systemd in a rootless environment.

- Podman don't need a daemon to run a container 
- Vaultwarden API don't need to be register
- Web vault can be accessed by mobile client or browser

Make sure you can do the difference between the official clients and the Web Vault powered by Bitwarden Inc and the unofficial Vaultwarden API a fork written in Rust by his author Dani Garcia.

+ Note :
Due to new denomination of Vaultwarden, I 'll change progessively named object accordingly.

## Features

- Support Fedora 33 and CentOS 8 as image containers
- Vaultwarden and the Web vault are built from sources
- You can import your own certificates or create a self-signed set
- Token and password are automatically generated
- Full automation process

Podman can be used in almost all modern Linux distribution even in [WSL2]. Fedora like (CentOS, Red Hat) or Debian like (Ubuntu, Raspian) are well supported. Running Vaultwarden with its own web server make this solution highly portable and secure because you can run the container without root privileges. System administrators will appreciate the fact that the two services will be handled by systemd with all the capabilities associate to this init manager

> the main goal is to build from scratch all the stuff under you eyes.
> we pull image container directly from well known repositories
> https://fr2.rpmfind.net/linux/fedora/linux/releases/33/Container for Fedora
> https://cloud.centos.org/centos/8/ for CentOS8
> clone sources from there git repositories
> All tools are fresh installed
> the system is upgraded to the last version.

When all your passwords are stored in a vault you have to be sure than no one can put things over your control.

## Tech

We use a number of open-source projects to work properly:

- [AngularJS] - HTML enhanced for web apps!
- [gcc] - GCC, the GNU Compiler Collection
- [Rust] - A language empowering everyone to build reliable and efficient software. 
- [Apache] - The Apache HTTP Server Project is a collaborative software development effort aimed at creating a robust, commercial-grade, featureful, and freely-available source code implementation of an HTTP (Web) server
- [node.js] - Node.js is a JavaScript runtime built on Chrome's V8 JavaScript engine.
- [Sass] - Sass is the most mature, stable, and powerful professional grade CSS extension language in the world. 
- [npm] - npm is the world's largest software registry.
- [Gulp] A toolkit to automate & enhance your workflow

And of course, This project itself is open source and located on GitHub.

## Installation

#### Prerequisites:

You need to install at least **Podman version 3.0** and **git** (or download the last release from github)
Your firewall should accept connection on port **443** by default or the port where the web server is listening
The name of web server must be resolvable, preferrably via a DNS registration
you will need **4 GB** of disk space and **3 GB** of RAM, during the built process, even if the final result turn around 290 to 340 MB 
If SELinux is active you need to check if **policycoreutils-python** package is installed

#### Built Process:
```sh
git clone https://github.com/vpolaris/Podman-Bitwarden.git
cd Podman-Bitwarden
chmod u+x setup.sh; sudo ./setup.sh
```

What the setup does? It creates a dedicated user named bitwarden on the host machine, this user will be responsible to build the image, store persistent data and run the container with the less privileges possible. A systemd service will be created and the container will be launched every time the host server is restarted. The service will be owned by the bitwarden user

+ No login or sudo available
+ Only the rights to manage containers

Answer the questions

+ TOKEN and Admin password are generated randomly, you can modify their values when asked
+ Domain name, by default will be vault.bitwarden.lan, this name has to be resolvable by all machines accessing the vault. You can use the hosts file but for a broader usage it's preferable to use a DNS record
+ Port number, 443 by default (https)
+ The tag version, this number will be append to the image name
+ Certificate, if you have a set of PEM certificates (CA and web server) and you want to use it to setup the apache server, answer yes and indicate their locations. Only useful to the first run as these certificates will be conserved between each build

At the end of questions, you can start the process immediately or copy the information for a later usage

## Acces
you can access by default to the vault via
https://vault.bitwarden.lan
or the domain name you provided

## Manage the container

Even if the user is locked, you can run commands if you use the correct syntax.

##### To visualize the user journal
```sh
sudo su -s /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/10500 ;journalctl --user -xe" bitwarden
```
##### To visualize container service status
```sh
sudo su -s /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/10500 ; systemctl --user status container-bitwarden.service" bitwarden
```
As you understood all commands need to be prefixed with
sudo su -s /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/10500  
and will be finished by the user name

As the container is managed by systemd do not use podman command to stop/start the container. Prefer this way:

##### Stop the container

```sh
sudo su -s /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/10500 ; systemctl --user stop container-bitwarden.service" bitwarden
```

##### Start the container
```sh
sudo su -s /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/10500 ; systemctl --user start container-bitwarden.service" bitwarden
```
## Log Files
You can monitor service's activities through two dedicated directories exported outside the container

#### Bitwarden log file 
Accessible by default to this location
```sh
tail /home/bitwarden/.persistent_storage/bitwarden/logs/bitwarden/bitwarden.log
```
#### Apache log files
you can monitor the httpd service through 4 log files located under the directory /home/bitwarden/.persistent_storage/bitwarden/logs/bitwarden/httpd

+ access_log record all access activities
+ error_log record all httpd service error
+ ssl_access_log record all ssl/tls attempts
+ ssl_error_log record all ssl failures

## Ressource Control
The maximum amount of memory usage for the container was fixed at 300MB, 150MB for the application and 150MB for system, allocated CPU has been set to 25% for application.
That's suit well a familly needs. for groups of 10 or more users you may tune this values.
For application the file to adjust is services/bitwarden-httpd.slice and for system you can set the value in services/memorymax.conf. Normally the memory used is arround 130MB on the host in normal operation mode

##Testing
Working on :
+ VMWare - Fedora 33 Server edition
+ Raspberry Pi4 - Fedora CoreOS 33
+ WSL2 - Ubuntu 20.04 (see wiki for hack)

## Sources: 
I found my inspiration from these web sites

**For Vaultwarden and the vault combined**
+ https://fiat-tux.fr/2019/01/14/installer-un-serveur-bitwarden_rs/ 
+ https://illuad.fr/2020/06/11/install-a-bitwarden-rs-server.html

**Ressource Control Group and Timer**
+ https://medium.com/horrible-hacks/using-systemd-as-a-better-cron-a4023eea996d

## License

AGPL-3.0 License 

**Free Software, Hell Yeah!**

[//]: # (These are reference links used in the body of this note and get stripped out when the markdown processor does its job. There is no need to format nicely because it shouldn't be seen. Thanks SO - http://stackoverflow.com/questions/4823468/store-comments-in-markdown-syntax)

   [Web-vault]: https://bitwarden.com/
   [bitwarden-rs]: <https://github.com/dani-garcia/vaultwarden/wiki>
   [gcc]: <https://gcc.gnu.org/>
   [npm]: <https://docs.npmjs.com/about-npm>
   [Rust]: <https://www.rust-lang.org/>
   [Apache]: <https://httpd.apache.org/>
   [Sass]: <https://sass-lang.com/>
   [WSL2]: <https://www.redhat.com/sysadmin/podman-windows-wsl2>
   [node.js]: <http://nodejs.org>
   [Twitter Bootstrap]: <http://twitter.github.com/bootstrap/>
   [jQuery]: <http://jquery.com>
   [@tjholowaychuk]: <http://twitter.com/tjholowaychuk>
   [express]: <http://expressjs.com>
   [AngularJS]: <http://angularjs.org>
   [Gulp]: <http://gulpjs.com>

