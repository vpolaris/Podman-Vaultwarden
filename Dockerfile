FROM scratch
LABEL maintainer="szfd9g <szfd9g@live.fr>"                    
ENV DISTTAG=f33container FGC=f33 FBR=f33 container=podman
#Add Fedora image Container from Fedora-Container-Base-33-1.2.x86_64.tar.xz
ADD layer.tar / 

#System update
RUN dnf -y upgrade dnf libmodulemd; dnf -y upgrade-minimal --security --bugfix --nodocs 
#Install apache
RUN dnf -y install httpd mod_ssl openssl mkpasswd

#Install Dev tools
RUN dnf -y install git gcc g++ openssl-devel python2

#Install Rust
RUN curl  -Lo /tmp/sh.rustup.rs -sSf https://sh.rustup.rs; \
bash -E /tmp/sh.rustup.rs -y --default-host x86_64-unknown-linux-gnu --default-toolchain nightly --profile minimal
ENV PATH="~/.cargo/bin:${PATH}"

#Install Node.JS and npm
RUN curl -Lo /tmp/setup_14.x -sSf https://rpm.nodesource.com/setup_14.x; \
bash -E /tmp/setup_14.x; \
dnf -y install nodejs

#Compile the back-end
RUN git clone https://github.com/dani-garcia/bitwarden_rs.git /tmp/bitwarden; \
~/.cargo/bin/cargo build --features sqlite --release --manifest-path=/tmp/bitwarden/Cargo.toml

#Compile the front-end

RUN git clone https://github.com/bitwarden/web.git /tmp/vault; \
cd /tmp/vault; \
tag="$(git tag -l "v2.18*" | tail -n1)"; export tag; echo "Selected tag version is ${tag}"; \
git checkout ${tag}
RUN curl -Lo /tmp/vault/v2.18.0.patch -sSf https://raw.githubusercontent.com/dani-garcia/bw_web_builds/master/patches/v2.18.0.patch; \
git -C /tmp/vault apply /tmp/vault/v2.18.0.patch
RUN npm run sub:init --prefix /tmp/vault;npm install --prefix /tmp/vault
RUN npm audit fix --prefix /tmp/vault;npm run dist --prefix /tmp/vault


#Create bitwarden user and admin container manager
RUN adduser --system --shell /bin/false --comment "Bitwarden RS server" --user-group -M bitwarden
RUN user_password="$(tr -cd [:alnum:] < /dev/urandom | fold -w 16 | head -n 1)";export user_password; adduser --shell /bin/bash --comment "Admin RS server" --user-group -G wheel -m --password $(mkpasswd -H md5 ${user_password}) admin;echo "Admin RS Password is ${user_password}"

#Create Directory Structure
RUN mkdir -p {/var/lib/bitwarden/{data,log},/var/log/bitwarden,/etc/bitwarden,/home/admin/.ssl}; \
chown -R bitwarden:bitwarden /var/lib/bitwarden/; \ 
chown -R admin:bitwarden /home/admin/.ssl

#Move files and set permissions

#Bitwarden RS server
RUN mv /tmp/bitwarden/target/release/bitwarden_rs /usr/local/bin/bitwarden
COPY .env.txt /etc/bitwarden/.env
RUN chmod -R 750 /usr/local/bin/bitwarden /var/lib/bitwarden/; \
chmod -R 770 /etc/bitwarden/; \
chown -R root:bitwarden /usr/local/bin/bitwarden /etc/bitwarden/

#Web Vault
RUN cp -a /tmp/vault/build/ /var/www/vault/;chown -R apache:apache /var/www/vault/

#Create Certificates and keys for Vault
RUN openssl req -new -x509 -nodes -days 7300 -outform PEM -newkey rsa:4096 -sha256 \
-keyout /home/admin/.ssl/CA-Bitwarden.key \
-out /home/admin/.ssl/CA-Bitwarden.pem \
-subj "/CN=CA Bitwarden/emailAddress=admin@vault.bitwarden.lan/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder"; \
openssl req -nodes -newkey rsa:2048 -sha256 \
-keyout /etc/pki/tls/private/bitwarden.key \
-out /home/admin/.ssl/bitwarden.csr \
-subj "/CN=vault.bitwarden.lan/emailAddress=admin@vault.bitwarden.lan/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder"; \
openssl x509 -req -outform PEM -CAcreateserial \
-in /home/admin/.ssl/bitwarden.csr \
-CA /home/admin/.ssl/CA-Bitwarden.pem \
-CAkey /home/admin/.ssl/CA-Bitwarden.key \
-out /etc/pki/tls/certs/bitwarden.pem

#Set fFile permissions and add CA to SSL store
RUN chmod 440 /etc/pki/tls/private/bitwarden.key; \
chmod 644 /etc/pki/tls/certs/bitwarden.pem ; \
chmod 440 /home/admin/.ssl/CA-Bitwarden.key; \
chmod 644 /home/admin/.ssl/CA-Bitwarden.pem; \
cp /home/admin/.ssl/CA-Bitwarden.pem /etc/pki/ca-trust/source/anchors/; \
update-ca-trust

#Apache configuration

COPY ssl.conf /etc/httpd/conf.d/ssl.conf
COPY vhost.conf /etc/httpd/conf.d/vhost.conf
RUN chmod 644 /etc/httpd/conf.d/ssl.conf; \
chmod 644 /etc/httpd/conf.d/vhost.conf; \
systemctl enable httpd.service

COPY bitwarden.service /etc/systemd/system/bitwarden.service
RUN systemctl enable bitwarden.service
CMD ["/usr/sbin/init"]


VOLUME /var/lib/bitwarden/data
EXPOSE 80
EXPOSE 443

#Clean up
RUN rm -f /tmp/sh.rustup.rs /tmp/setup_14.x; \
rm -rf /tmp/bitwarden/ /tmp/vault; \
yes | ~/.cargo/bin/rustup self uninstall; \
rm -rf ~/.config/ ~/.node-gyp/ ~/.npm ~/anaconda-* ~/original-ks.cfg; \
dnf -y remove nodejs git gcc g++ openssl-devel python2 --setopt=clean_requirements_on_remove=1; \
dnf -y autoremove; \
dnf clean all

