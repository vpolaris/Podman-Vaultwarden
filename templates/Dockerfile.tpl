FROM scratch
LABEL maintainer="szfd9g <szfd9g@live.fr>"                    
ENV DISTTAG=f34container FGC=f34 FBR=f34 container=podman
ENV DNFOPTION="--setopt=install_weak_deps=False --nodocs"
ARG admpass
ARG OS
ARG HTTPS
#Add Fedora image Container from Fedora-Container-Base-33-1.2.x86_64.tar.xz
ADD layer.tar / 

#System update
RUN dnf makecache; \
dnf -y upgrade dnf rpm yum libmodulemd $DNFOPTION; \
dnf -y upgrade $DNFOPTION


#Install apache

RUN dnf -y install httpd mod_ssl openssl $DNFOPTION

#Install Dev tools
RUN dnf -y install git gcc openssl-devel python2 $DNFOPTION
RUN echo "Selected OS is ${OS}";if [ "${OS}" == "CentOS" ]; then dnf -y install gcc-c++ make $DNFOPTION; \
else dnf -y install g++ $DNFOPTION; fi

#Install Rust
RUN curl  -Lo /tmp/sh.rustup.rs -sSf https://sh.rustup.rs; \
bash -E /tmp/sh.rustup.rs -y --default-host "$(uname -m)"-unknown-linux-gnu --default-toolchain nightly --profile minimal
ENV PATH="~/.cargo/bin:${PATH}"

#Install Node.JS and npm
RUN curl -Lo /tmp/setup_14.x -sSf https://rpm.nodesource.com/setup_14.x; \
bash -E /tmp/setup_14.x; \
sed -i 's/failovermethod=priority/#failovermethod=priority/g' /etc/yum.repos.d/nodesource-fc33.repo; \
dnf -y install nodejs $DNFOPTION

#Compile the back-end
RUN git clone https://github.com/dani-garcia/vaultwarden.git /tmp/vaultwarden; \
~/.cargo/bin/cargo build --features sqlite --release --manifest-path=/tmp/vaultwarden/Cargo.toml

#Compile the front-end

RUN git clone https://github.com/bitwarden/web.git /tmp/vault; \
cd /tmp/vault; \
tag="$(git tag -l "v2.24.0" | tail -n1)"; export tag; echo "Selected tag version is ${tag}"; \
git checkout ${tag}
RUN cd /tmp/vault; git submodule update --recursive --init
RUN curl -Lo /tmp/vault/v2.24.0.patch -sSf https://raw.githubusercontent.com/dani-garcia/bw_web_builds/master/patches/v2.24.0.patch; \
git -C /tmp/vault apply /tmp/vault/v2.24.0.patch
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts; \
npm run sub:init --prefix /tmp/vault; \
npm install npm@7 --prefix /tmp/vault

RUN npm ci --legacy-peer-deps --prefix /tmp/vault; \
npm audit fix --legacy-peer-deps --prefix /tmp/vault || true; \
npm run dist:oss:selfhost --prefix /tmp/vault


#Create Vaultwarden user and admin container manager
RUN adduser -u 10502 --shell /bin/false --comment "Vaultwarden RS User Service" --user-group -M vaultwarden

RUN if [[ -z "$admpass" ]] ; then \
user_password="$(tr -cd [:alnum:] < /dev/urandom | fold -w 16 | head -n 1)";export user_password; adduser --shell /bin/bash --comment "Admin RS server" --user-group -G wheel -m --password $(mkpasswd -H md5 ${user_password}) admin;echo "Admin RS Password is ${user_password}"; \
else adduser --shell /bin/bash --comment "Admin RS server" --user-group -G wheel -m --password $(openssl passwd -1 ${admpass}) admin;echo "Admin RS Password is ${admpass}";fi


#Create Directory Structure
RUN if ! [ -d  "var/lib/vaultwarden/data" ]; then	mkdir -p /var/lib/vaultwarden/{data,certs,logs};mkdir -p /var/lib/vaultwarden/logs/{vaultwarden,httpd}; fi
RUN mkdir -p /etc/vaultwarden /home/admin/.ssl; \
chown -R vaultwarden:vaultwarden /var/lib/vaultwarden/; \
chown -R admin:vaultwarden /home/admin/.ssl

#Move files and set permissions

#vaultwarden RS server
RUN mv /tmp/vaultwarden/target/release/vaultwarden /usr/local/bin/vaultwarden
COPY ./configurations/.env /etc/vaultwarden/.env
RUN chmod -R 750 /usr/local/bin/vaultwarden /var/lib/vaultwarden/; \
chmod -R 770 /etc/vaultwarden/; \
chown -R root:vaultwarden /usr/local/bin/vaultwarden /etc/vaultwarden/

#Apache
COPY ./configurations/ssl.conf /etc/httpd/conf.d/ssl.conf
COPY ./configurations/serveur-status.conf /etc/httpd/conf.d/serveur-status.conf
COPY ./configurations/vhost.conf /etc/httpd/conf.d/vhost.conf
RUN chmod 644 /etc/httpd/conf.d/{ssl.conf,vhost.conf,serveur-status.conf}
RUN cp -a /tmp/vault/build/ /var/www/vault/; \
chown -R apache:apache /var/www/vault/ /var/lib/vaultwarden/logs/httpd

#Create certificates and keys for Vault if are not provided
RUN if ! [ -f  "/var/lib/vaultwarden/certs/CA-Vaultwarden.pem" ]; then \
openssl req -new -x509 -nodes -days 7300 -outform PEM -newkey rsa:4096 -sha256 \
-keyout /home/admin/.ssl/CA-Vaultwarden.key \
-out /home/admin/.ssl/CA-Vaultwarden.pem \
-subj "/CN=CA Vaultwarden/emailAddress=admin@${DOMAIN}/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder"; \
cp /home/admin/.ssl/CA-Vaultwarden.* /var/lib/vaultwarden/certs; \
else cp /var/lib/vaultwarden/certs/CA-Vaultwarden.pem /home/admin/.ssl/CA-Vaultwarden.pem; fi

RUN if [ -f  "/var/lib/valtwarden/certs/CA-Vaultwarden.key" ]; then \
cp /var/lib/vaultwarden/certs/CA-vaultwarden.key /home/admin/.ssl/CA-Vaultwarden.key;fi

RUN if ! [ -f  "/var/lib/vaultwarden/certs/vaultwarden.pem" ]; then \
openssl req -nodes -newkey rsa:2048 -sha256 \
-keyout /etc/pki/tls/private/vaultwarden.key \
-out /home/admin/.ssl/vaultwarden.csr \
-subj "/CN=${DOMAIN}/emailAddress=admin@${DOMAIN}/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder"; \
cp /home/admin/.ssl/vaultwarden.csr /var/lib/vaultwarden/certs; \
cp /etc/pki/tls/private/vaultwarden.key /var/lib/vaultwarden/certs; \
else cp /var/lib/vaultwarden/certs/vaultwarden.csr /home/admin/.ssl/vaultwarden.csr; \
cp /var/lib/vaultwarden/certs/vaultwarden.key /etc/pki/tls/private/vaultwarden.key; fi

RUN if ! [ -f  "/var/lib/vaultwarden/certs/vaultwarden.pem" ]; then \
openssl x509 -req -outform PEM -CAcreateserial \
-in /home/admin/.ssl/vaultwarden.csr \
-CA /home/admin/.ssl/CA-Vaultwarden.pem \
-CAkey /home/admin/.ssl/CA-Vaultwarden.key \
-out /etc/pki/tls/certs/vaultwarden.pem; \
cp /etc/pki/tls/certs/vaultwarden.pem /var/lib/vaultwarden/certs; \
else cp /var/lib/vaultwarden/certs/vaultwarden.pem /etc/pki/tls/certs/vaultwarden.pem; fi

#Set file permissions and add CA to SSL store
RUN chmod 440 /etc/pki/tls/private/vaultwarden.key; \
chmod 644 /etc/pki/tls/certs/vaultwarden.pem ; \
chmod 644 /home/admin/.ssl/CA-Vaultwarden.pem; \
cp /home/admin/.ssl/CA-Vaultwarden.pem /etc/pki/ca-trust/source/anchors/; \
update-ca-trust

RUN if [ -f  "/home/admin/.ssl/CA-Vaultwarden.key" ]; then \
chmod 440 /home/admin/.ssl/CA-Vaultwarden.key;fi

RUN dnf -y install dnf-automatic; \
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf; \
mkdir /etc/systemd/system/dnf-automatic-install.timer.d
COPY ./services/timer.conf etc/systemd/system/dnf-automatic-install.timer.d

#Systemd configuration
RUN mkdir /etc/systemd/system/{httpd.service.d,system.slice.d}
COPY ./services/vaultwarden.service /etc/systemd/system/vaultwarden.service
COPY ./services/vaultwarden-httpd.slice /etc/systemd/system/vaultwarden-httpd.slice
COPY ./services/healthcheck.timer /etc/systemd/system/healthcheck.timer
COPY ./services/slice.conf /etc/systemd/system/httpd.service.d/slice.conf
COPY ./services/memorymax.conf /etc/systemd/system/system.slice.d/memorymax.conf
RUN chmod 644 /etc/systemd/system/{vaultwarden.service,healthcheck.timer,vaultwarden-httpd.slice} /etc/systemd/system/httpd.service.d/slice.conf
RUN systemctl enable vaultwarden.service httpd.service dnf-automatic-install.timer
CMD ["/usr/sbin/init"]
RUN if ! [ -s /etc/pki/tls/certs/localhost.crt ]; then \
rm -f /etc/pki/tls/certs/localhost.crt /etc/pki/tls/private/localhost.key; \
/usr/libexec/httpd-ssl-gencerts;fi

#Used only if Dockerfile is not set by setup
RUN if [ -z ${HTTPS} ]; then export HTTPS="443";fi
EXPOSE ${HTTPS}

#Clean up
RUN if [ "${OS}" == "CentOS" ]; then dnf -y remove gcc-c++ make xz tar squashfs-tools snappy --setopt=clean_requirements_on_remove=1; \
else dnf -y remove g++ --setopt=clean_requirements_on_remove=1; fi


RUN rm -f /tmp/sh.rustup.rs /tmp/setup_14.x; \
rm -rf /tmp/vaultwarden/ /tmp/vault; \
yes | ~/.cargo/bin/rustup self uninstall; \
rm -rf ~/.config/ ~/.node-gyp/ ~/.npm ~/anaconda-* ~/original-ks.cfg; \
dnf -y remove nodejs git gcc openssl-devel python2 --setopt=clean_requirements_on_remove=1; \
dnf -y autoremove; \
dnf clean all

RUN touch /var/lib/vaultwarden/build.completed

