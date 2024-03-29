# Podman Vaultwarden Project
## _Vaultwarden Powered by Podman_

[![N|Solid](https://raw.githubusercontent.com/containers/podman/master/logo/podman-logo.png)](https://podman.io/getting-started/)

This project want to build a podman container to host a complete solution of [Vaultwarden API][vaultwarden-rs] and a [Web vault][Web-vault]: interface. Which is proxified by an Apache web server and initialized by Systemd in a rootless environment.

- Podman don't need a daemon to run a container 
- Podman don'need root privileges run a container 
- Vaultwarden API don't need to be register
- Web vault can be accessed by mobile client or browser

Make sure you can do the difference between the official clients and the Web Vault powered by Bitwarden Inc and the unofficial Vaultwarden API a fork written in Rust by his author Dani Garcia.

## Features

- Support Fedora 35 and CentOS 8 as image containers
- Vaultwarden and the Web vault are built from sources
- You can import your own certificates or create a self-signed set
- Token and password are automatically generated
- Full automation process
- Automatic backup of database
- Settings are preserved between each build

Podman can be used in almost all modern Linux distribution even in [WSL2]. Fedora like (CentOS, Red Hat) or Debian like (Ubuntu, Raspian) are well supported. Running Vaultwarden with its own web server make this solution highly portable and secure because you can run the container without root privileges. System administrators will appreciate the fact that the two services will be handled by systemd with all the capabilities associate to this init manager

> the main goal is to build from scratch all the stuff under you eyes.
> we pull image container directly from well known repositories
> https://fr2.rpmfind.net/linux/fedora/linux/releases/35/Container for Fedora
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
git clone https://github.com/vpolaris/Podman-Vaultwarden.git
cd Podman-Vaultwarden
chmod u+x setup.sh; sudo ./setup.sh
```

What the setup does? It creates a dedicated user named vaultwarden on the host machine, this user will be responsible to build the image, store persistent data and run the container with the less privileges possible. A systemd service will be created and the container will be launched every time the host server is restarted. The service will be owned by the vaultwarden user

+ No login or sudo available
+ Only the rights to manage containers

Answer the questions

+ TOKEN and Admin password are generated randomly, you can modify their values when asked
+ Domain name, by default will be vault.vaultwarden.lan, this name has to be resolvable by all machines accessing the vault. You can use the hosts file but for a broader usage it's preferable to use a DNS record
+ Port number, 443 by default (https)
+ The tag version, this number will be append to the image name
+ Certificate, if you have a set of PEM certificates (CA and web server) and you want to use it to setup the apache server, answer yes and indicate their locations. Only useful to the first run as these certificates will be conserved between each build
+ Enable or disable database backup

At the end of questions, you can start the process immediately or copy the information for a later usage

## Acces
you can access by default to the vault via
https://vault.vaultwarden.lan
or the domain name you provided

![image](https://user-images.githubusercontent.com/73080749/165287141-b1853ad7-7c95-43b5-bae5-74641607dc3f.png)


## Manage the container

Even if the user is locked, you can run commands if you use the correct syntax.

##### To visualize the user journal
```sh
sudo su -s /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/10502 ;journalctl --user -xe" vaultwarden
```
##### To visualize container service status
```sh
sudo su -s /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/10502 ; systemctl --user status container-vaultwarden.service" vaultwarden
```
As you understood all commands need to be prefixed with
sudo su -s /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/10502  
and will be finished by the user name

As the container is managed by systemd do not use podman command to stop/start the container. Prefer this way:

##### Stop the container

```sh
sudo su -s /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/10502 ; systemctl --user stop container-vaultwarden.service" vaultwarden
```

##### Start the container
```sh
sudo su -s /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/10502 ; systemctl --user start container-vaultwarden.service" vaultwarden
```
## Log Files
You can monitor service's activities through two dedicated directories exported outside the container

#### Vaultwarden log file 
Accessible by default to this location
```sh
tail /home/vaultwarden/.persistent_storage/vaultwarden/logs/vaultwarden/vaultwarden.log
```
#### Apache log files
you can monitor the httpd service through 4 log files located under the directory /home/vaultwarden/.persistent_storage/vaultwarden/logs/vaultwarden/httpd

+ access_log record all access activities
+ error_log record all httpd service error
+ ssl_access_log record all ssl/tls attempts
+ ssl_error_log record all ssl failures

## Ressource Control
The maximum amount of memory usage for the container was fixed at 300MB, 150MB for the application and 150MB for system, allocated CPU has been set to 25% for application.
That's suit well a familly needs. for groups of 10 or more users you may tune this values.
For application the file to adjust is services/vaultwarden-httpd.slice and for system you can set the value in services/memorymax.conf. Normally the memory used is arround 130MB on the host in normal operation mode

## Testing
Working on :
+ VMWare - Fedora 33 Server edition
+ Raspberry Pi4 - Fedora CoreOS 33
+ WSL2 - Ubuntu 20.04 (see wiki for hack)

## Troubleshooting

We consider this two options

hostname is vault.vaultwarden.lan and we forward communication through port 2443 TCP

on the podman host, check if both httpd and vaultwarden service are running inside the container

```
usermod -s /bin/bash vaultwarden (or vaultwarden for most recent release)
sudo su podman exec -ti vaultwarden /bin/bash
systemctl status vaultwarden httpd
```
A good result should be:
```
systemctl status vaultwarden httpd
● vaultwarden.service - Bitwarden RS server
     Loaded: loaded (/etc/systemd/system/vaultwarden.service; enabled; vendor preset: disabled)
     Active: active (running) since Wed 2021-08-18 14:36:09 CEST; 25min ago
       Docs: https://github.com/dani-garcia/vaultwarden_rs
   Main PID: 17 (vaultwarden)
      Tasks: 16 (limit: 307)
     Memory: 6.2M
        CPU: 148ms
     CGroup: /vaultwarden.slice/vaultwarden-httpd.slice/vaultwarden.service
             └─17 /usr/local/bin/vaultwarden

Aug 18 14:36:09 vaultwarden.lan vaultwarden[17]: Configured for production.
Aug 18 14:36:09 vaultwarden.lan vaultwarden[17]:     => address: 127.0.0.1
Aug 18 14:36:09 vaultwarden.lan vaultwarden[17]:     => port: 8000
Aug 18 14:36:09 vaultwarden.lan vaultwarden[17]:     => log: critical
Aug 18 14:36:09 vaultwarden.lan vaultwarden[17]:     => workers: 8
Aug 18 14:36:09 vaultwarden.lan vaultwarden[17]:     => secret key: private-cookies disabled
Aug 18 14:36:09 vaultwarden.lan vaultwarden[17]:     => limits: forms = 32KiB
Aug 18 14:36:09 vaultwarden.lan vaultwarden[17]:     => keep-alive: 5s
Aug 18 14:36:09 vaultwarden.lan vaultwarden[17]:     => tls: disabled
Aug 18 14:36:09 vaultwarden.lan vaultwarden[17]: Rocket has launched from http://127.0.0.1:8000

● httpd.service - The Apache HTTP Server
     Loaded: loaded (/usr/lib/systemd/system/httpd.service; enabled; vendor preset: disabled)
    Drop-In: /etc/systemd/system/httpd.service.d
             └─slice.conf
     Active: active (running) since Wed 2021-08-18 14:36:10 CEST; 25min ago
       Docs: man:httpd.service(8)
   Main PID: 38 (httpd)
     Status: "Total requests: 9; Idle/Busy workers 98/2;Requests/sec: 0.00583; Bytes served/sec: 3.8KB/sec"
      Tasks: 130 (limit: 307)
     Memory: 14.7M
        CPU: 1.365s
     CGroup: /vaultwarden.slice/vaultwarden-httpd.slice/httpd.service
             ├─ 38 /usr/sbin/httpd -DFOREGROUND
             ├─ 39 /usr/sbin/httpd -DFOREGROUND
             ├─ 40 /usr/sbin/httpd -DFOREGROUND
             ├─ 42 /usr/sbin/httpd -DFOREGROUND
             ├─ 43 /usr/sbin/httpd -DFOREGROUND
             └─144 /usr/sbin/httpd -DFOREGROUND

Aug 18 14:36:10 vaultwarden.lan systemd[1]: Starting The Apache HTTP Server...
Aug 18 14:36:10 vaultwarden.lan httpd[38]: Server configured, listening on: port 443, port 8800, ...
Aug 18 14:36:10 vaultwarden.lan systemd[1]: Started The Apache HTTP Server.
```

If you see some errros, you can try to restart both service 
```
systemctl restart vaultwarden httpd
```
Run the status command again, if the problem still persist, please open a bug request

Lock the user again
```
usermod -s /sbin/nologin vaultwarden
```

If services are running fines, try to troubleshoot network communication

first we use nslookup to resolve our hostname, be aware that the virtual host configured with appache need to be resolved  accordingly  with defined name given during setup
the host of the podman container needs to be different of given virtual host. from a client machine try:

```
nslookup vault.vaultwarden.lan
 nslookup vault.vaultwarden.lan
Server:         127.0.0.53
Address:        127.0.0.53#53

Name:   vault.vaultwarden.lan
Address: 192.168.xxx.xxx

```
This is what a good answer looks like

If you failed to resolve your hostname, you can add an entry in /etc/hosts for Linux or C:\Windows\System32\drivers\etc\hosts for Windows (you need admin rights in both case
this entry shoube this format
+ 192.168.xxx.xxx vault.vaultwarden.lan

The most reliable solution is to add a DNS entry in you DNS server configuration

If you continue to experiment connection failure, you can test port access in this way
On Linux Platform
A valid response should be
```
Ncat: Version 7.80 ( https://nmap.org/ncat )
Ncat: Connected to 192.168.xxx.xxx:2443.
Ncat: 0 bytes sent, 0 bytes received in 0.01 seconds.
```
In case of  failure
```
nc -zv vault.vaultwarden.lan 2443
Ncat: Version 7.80 ( https://nmap.org/ncat )
Ncat: Connection refused.
```
On Windows Platform
```
test-netconnection -ComputerName vault.vaultwarden.lan -Port 2443                                                                                                                                                             
ComputerName     : vault.vaultwarden.lan
RemoteAddress    : 192.168.xxx.xxx
RemotePort       : 2443
InterfaceAlias   : Ethernet0
SourceAddress    : 192.168.xxx.xxx
TcpTestSucceeded : True
```
In case of failure
```
test-netconnection -ComputerName vault.vaultwarden.lan -Port 2443
WARNING : TCP connect to (192.168.xxx.xxx : 2443) failed


ComputerName           : vault.vaultwarden.lan
RemoteAddress          : 192.168.xxx.xxx
RemotePort             : 2443
InterfaceAlias         : Ethernet0
SourceAddress          : 192.168.xxx.xxx
PingSucceeded          : True
PingReplyDetails (RTT) : 1 ms
TcpTestSucceeded       : False
```
In case of failure we need to ensure that the host firewall dont block the communication
#### Example on Fedora Like we shutdown the firewall, for other firewalls (ufw or netfilter consult appropriate documentation)
```
systemctl stop firewalld.service
```

Reinitiate a test connection if the test succeed add a firewall rule to accept incoming connection on TCP port 2443
```
firewall-cmd --add-port=2443/tcp --permanent
firewall-cmd --reload
```
...and start the service
```
systemctl start firewalld.service
```

If the problem persist try to check port forwarding in case you are in NAT environnment; on you ISP box or Virtualizer as kvm or VMWare

#### Example on VMWare
I use NAT connection, to access  the port 2443 on my podman host i need to setup port forwarding

Open Virtual Network Editor as administrator, select your NAT interface and click on NAT settings. Add a port forwarding rule

+ 2443 TCP 192.168.xxx.xxx:2443

If something continue to goes wrong check also routing table and third party device as router or repeater

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
   [vaultwarden-rs]: <https://github.com/dani-garcia/vaultwarden/wiki>
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

