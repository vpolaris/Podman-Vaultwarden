FROM scratch
LABEL maintainer="szfd9g <szfd9g@live.fr>"                    
ENV DISTTAG=f35container FGC=f35 FBR=f35 container=podman
ENV DNFOPTION="--setopt=install_weak_deps=False --nodocs"
ENV DB_BACKUP enabled
ENV LANG C.UTF8
ENV TERM=xterm
ARG admpass
ARG OS
ARG HTTPS

#Add Image container
ADD layer.tar / 

#Create Vaultwarden user and admin container manager
RUN printf "Create Vaultwarden user \n" \
    && adduser -u 10502 --shell /bin/bash --comment "Vaultwarden RS User Service" --user-group -m vaultwarden

#System update
RUN printf "System update \n" \
    && dnf makecache \
    && dnf -y upgrade \
        dnf \
        rpm \
        yum \
        libmodulemd $DNFOPTION \
    && dnf -y upgrade $DNFOPTION


#Install apache
RUN printf "Install apache \n" \
    && dnf -y install \
        httpd \
        mod_ssl \
        openssl $DNFOPTION

#Install Dev tools
RUN printf "Install development tools \n" \
    && dnf -y install \
         git \
         gcc \
         openssl-devel \
         python2 $DNFOPTION

RUN clear \
    && printf  "Selected OS is ${OS}\n" \
    && if [ "${OS}" == "CentOS" ]; then \
        dnf -y install gcc-c++ make $DNFOPTION; \
    else \
        dnf -y install g++ $DNFOPTION \
    ;fi

#Install Rust
RUN clear \
    && printf  "Rust Installation \n" \
    &&curl  -Lo /tmp/sh.rustup.rs -sSf https://sh.rustup.rs \
    && bash -E /tmp/sh.rustup.rs -y --default-host "$(uname -m)"-unknown-linux-gnu --default-toolchain nightly --profile minimal
ENV PATH="~/.cargo/bin:${PATH}"

#Install Node.JS and npm
RUN clear \
    && printf  "Install node.js and npm\n" \
    # && curl -Lo /tmp/setup_14.x -sSf https://rpm.nodesource.com/setup_14.x \
    # && bash -E /tmp/setup_14.x \
    # && sed -i 's/failovermethod=priority/#failovermethod=priority/g' /etc/yum.repos.d/nodesource-fc34.repo \
    && dnf -y module install nodejs:16/development $DNFOPTION \
    && npm -g install npm@8

# Compile the back-end
RUN clear \
    && printf  "Compile the back-end \n" \
    && git clone https://github.com/dani-garcia/vaultwarden.git /tmp/vaultwarden \
    && ~/.cargo/bin/cargo build --features sqlite --release --manifest-path=/tmp/vaultwarden/Cargo.toml

#Compile the front-end

RUN mkdir /tmp/vault

RUN clear \
    && printf "Clone Web vault\n" \
    && git clone https://github.com/bitwarden/web.git /tmp/vault \
    && chown -R vaultwarden:vaultwarden /tmp/vault

USER vaultwarden
WORKDIR /tmp/vault

RUN clear \
    && printf "Select Branch\n" \
    && git pull origin master \
    && printf "Select Version\n" \
    && git checkout v2.28.0 \
    && printf "Update Web vault\n" \
    && git submodule update --recursive --init

RUN printf "Apply patch\n" \
    && curl -Lo v2.28.0.patch -sSf https://raw.githubusercontent.com/dani-garcia/bw_web_builds/master/patches/v2.28.0.patch \
    && chown vaultwarden:vaultwarden v2.28.0.patch \
    && git apply v2.28.0.patch --reject

RUN printf "NPM Compile\n" \
    && npm ci --legacy-peer-deps \
    && npm run dist:oss:selfhost

USER root
WORKDIR /

RUN clear \
    && printf  "Create admin user\n" \
    && if [[ -z "$admpass" ]] ; then \
        user_password="$(tr -cd [:alnum:] < /dev/urandom | fold -w 16 | head -n 1)";export user_password; adduser --shell /bin/bash --comment "Admin RS server" --user-group -G wheel -m --password $(mkpasswd -H md5 ${user_password}) admin;echo "Admin RS Password is ${user_password}"; \
    else \ 
        adduser --shell /bin/bash --comment "Admin RS server" --user-group -G wheel -m --password $(openssl passwd -1 ${admpass}) admin;echo "Admin RS Password is ${admpass}" \
    ;fi

RUN printf  "Create Directory Structure\n" \
    && if ! [ -d  "var/lib/vaultwarden/data" ]; then \
        mkdir -p /var/lib/vaultwarden/{data,certs,logs,backup} \
        && mkdir -p /var/lib/vaultwarden/logs/{vaultwarden,httpd} \
      ;fi

RUN if ! [ -d  "var/lib/vaultwarden/logs/vaultwarden" ]; then \
        mkdir -p /var/lib/vaultwarden/logs/{vaultwarden,httpd} \
    ;fi

RUN mkdir -p /etc/vaultwarden /home/admin/.ssl \
    && chown -R vaultwarden:vaultwarden /var/lib/vaultwarden/ \
    && chown -R admin:vaultwarden /home/admin/.ssl

#Move files and set permissions

#vaultwarden RS server
RUN printf  "Move files and set permissions\n" \
    && mv /tmp/vaultwarden/target/release/vaultwarden /usr/local/bin/vaultwarden
COPY ./configurations/.env /etc/vaultwarden/.env
RUN chmod -R 750 /usr/local/bin/vaultwarden /var/lib/vaultwarden/ \
    && chmod -R 770 /etc/vaultwarden/ \
    && chown -R root:vaultwarden /usr/local/bin/vaultwarden /etc/vaultwarden/

#Apache
RUN clear \
    && printf  "Configure Appache\n" \
COPY ./configurations/ssl.conf /etc/httpd/conf.d/ssl.conf
COPY ./configurations/server-status.conf /etc/httpd/conf.d/server-status.conf
COPY ./configurations/vhost.conf /etc/httpd/conf.d/vhost.conf
RUN chmod 644 /etc/httpd/conf.d/{ssl.conf,vhost.conf,server-status.conf} \ 
    && cp -a /tmp/vault/build/ /var/www/vault/ \
    && chown -R apache:apache /var/www/vault/ /var/lib/vaultwarden/logs/httpd

#Create certificates and keys for Vault if are not provided
RUN clear \
    && printf  "Configure Certificates\n" \
    && if ! [ -f  "/var/lib/vaultwarden/certs/CA-Vaultwarden.pem" ]; then \
            openssl req -new -x509 -nodes -days 7300 -outform PEM -newkey rsa:4096 -sha256 \
            -keyout /home/admin/.ssl/CA-Vaultwarden.key \
            -out /home/admin/.ssl/CA-Vaultwarden.pem \
            -subj "/CN=CA Vaultwarden/emailAddress=admin@vault.vaultwarden.lan/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder" \
            && cp /home/admin/.ssl/CA-Vaultwarden.* /var/lib/vaultwarden/certs; \
       else \
            cp /var/lib/vaultwarden/certs/CA-Vaultwarden.pem /home/admin/.ssl/CA-Vaultwarden.pem \
       ;fi

RUN if [ -f  "/var/lib/valtwarden/certs/CA-Vaultwarden.key" ]; then \
        cp /var/lib/vaultwarden/certs/CA-vaultwarden.key /home/admin/.ssl/CA-Vaultwarden.key \
    ;fi

RUN if ! [ -f  "/var/lib/vaultwarden/certs/vaultwarden.pem" ]; then \
        openssl req -nodes -newkey rsa:2048 -sha256 \
        -keyout /etc/pki/tls/private/vaultwarden.key \
        -out /home/admin/.ssl/vaultwarden.csr \
        -subj "/CN=vault.vaultwarden.lan/emailAddress=admin@vault.vaultwarden.lan/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder" \
        && cp /home/admin/.ssl/vaultwarden.csr /var/lib/vaultwarden/certs \
        && cp /etc/pki/tls/private/vaultwarden.key /var/lib/vaultwarden/certs \
    ;else \
        cp /var/lib/vaultwarden/certs/vaultwarden.csr /home/admin/.ssl/vaultwarden.csr \
        && cp /var/lib/vaultwarden/certs/vaultwarden.key /etc/pki/tls/private/vaultwarden.key \
    ;fi

RUN if ! [ -f  "/var/lib/vaultwarden/certs/vaultwarden.pem" ]; then \
        openssl x509 -req -outform PEM -CAcreateserial \
        -in /home/admin/.ssl/vaultwarden.csr \
        -CA /home/admin/.ssl/CA-Vaultwarden.pem \
        -CAkey /home/admin/.ssl/CA-Vaultwarden.key \
        -out /etc/pki/tls/certs/vaultwarden.pem; \
        cp /etc/pki/tls/certs/vaultwarden.pem /var/lib/vaultwarden/certs; \
    else \
        cp /var/lib/vaultwarden/certs/vaultwarden.pem /etc/pki/tls/certs/vaultwarden.pem \
    ;fi

#Set file permissions and add CA to SSL store
RUN chmod 440 /etc/pki/tls/private/vaultwarden.key \
    && chmod 644 /etc/pki/tls/certs/vaultwarden.pem \
    && chmod 644 /home/admin/.ssl/CA-Vaultwarden.pem \
    && cp /home/admin/.ssl/CA-Vaultwarden.pem /etc/pki/ca-trust/source/anchors/ \
    && update-ca-trust

RUN if [ -f  "/home/admin/.ssl/CA-Vaultwarden.key" ]; then \
        chmod 440 /home/admin/.ssl/CA-Vaultwarden.key \
    ;fi

RUN clear \
    && printf  "Install automatic update \n" \
    && dnf -y install dnf-automatic \
    && sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf \
    && mkdir /etc/systemd/system/dnf-automatic-install.timer.d

COPY ./services/timer.conf /etc/systemd/system/dnf-automatic-install.timer.d

#install scripts
RUN printf  "Install scripts\n" \
    && mkdir -m 700 -p /opt/scripts
COPY ./scripts/sql.backup.py /opt/scripts/sql.backup.py
RUN printf "DB_BACKUP=enabled\n" > /opt/scripts/.env \
    && chown -R vaultwarden: /opt/scripts \
    && chmod u+x /opt/scripts/sql.backup.py

#Systemd configuration
RUN clear \
    && printf  "Systemd configuration\n" \
    && mkdir /etc/systemd/system/{httpd.service.d,system.slice.d}
COPY ./services/vaultwarden.service /etc/systemd/system/vaultwarden.service
COPY ./services/vaultwarden-httpd.slice /etc/systemd/system/vaultwarden-httpd.slice
COPY ./services/healthcheck.timer /etc/systemd/system/healthcheck.timer
COPY ./services/slice.conf /etc/systemd/system/httpd.service.d/slice.conf
COPY ./services/db-backup.timer /etc/systemd/system/db-backup.timer
COPY ./services/db-backup.service /etc/systemd/system/db-backup.service
COPY ./services/memorymax.conf /etc/systemd/system/system.slice.d/memorymax.conf
RUN chmod 644 /etc/systemd/system/{vaultwarden.service,healthcheck.timer,vaultwarden-httpd.slice,db-backup.timer,db-backup.service} \
    /etc/systemd/system/httpd.service.d/slice.conf
RUN systemctl enable vaultwarden.service httpd.service dnf-automatic-install.timer db-backup.timer
CMD ["/usr/sbin/init"]
RUN if ! [ -s /etc/pki/tls/certs/localhost.crt ]; then \
        rm -f /etc/pki/tls/certs/localhost.crt /etc/pki/tls/private/localhost.key \
        && /usr/libexec/httpd-ssl-gencerts \
    ;fi

#Used only if Dockerfile is not set by setup
RUN if [ -z 443 ]; then export HTTPS="443";fi
EXPOSE 443

#Clean up
RUN clear \
    && printf "Clean up\n" \
    && if [ "${OS}" == "CentOS" ]; then \
            dnf -y remove gcc-c++ make xz tar squashfs-tools snappy --setopt=clean_requirements_on_remove=1; \
       else \ 
            dnf -y remove g++ --setopt=clean_requirements_on_remove=1 \
       ;fi


RUN rm -f /tmp/sh.rustup.rs /tmp/setup_14.x \
    && rm -rf /tmp/vaultwarden/ /tmp/vault \
    && yes | ~/.cargo/bin/rustup self uninstall \
    && rm -rf ~/.config/ ~/.node-gyp/ ~/.npm ~/anaconda-* ~/original-ks.cfg /home/vaultwarden/.npm \
    && dnf -y remove nodejs git gcc openssl-devel python2 --setopt=clean_requirements_on_remove=1 \
    && dnf -y autoremove \
    && dnf clean all \
    && rm -rf /usr/{share/locale,{lib,lib64}/gconv,bin/localedef,sbin/build-locale-archive} \
    && rm -rf /usr/share/{man,doc,info,gnome/help,httpd} \
    && rm -rf \
        /tmp/* \
        /sbin/sln \
        /var/tmp/* \
        /usr/share/fonts/* \
        /usr/share/i18n/* \
        /usr/share/cracklib/* \
        /usr/include/* \
        /usr/local/include/* \
        /usr/share/sgml/docbook/xsl-stylesheets* \
        /usr/share/adobe/resources/* \
    && rm -rf /etc/ld.so.cache /var/cache/ldconfig \
    && mkdir -p --mode=0755 /var/cache/ldconfig \
    && rm -rf /var/cache/yum \
    && mkdir -p --mode=0755 /var/cache/yum

RUN touch /var/lib/vaultwarden/build.completed

