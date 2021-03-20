#!/bin/bash
ADMTKN="$(tr -cd [:alnum:] < /dev/urandom | fold -w 48 | head -n 1)"
ADMINPASS="$(tr -cd [:alnum:] < /dev/urandom | fold -w 16 | head -n 1)"
DOMAIN="vault.bitwarden.lan"
HTTPS="443"
DATADIR="${HOME}/.persitent_storage/"
VERSION="1.00"

read -e -p "Enter ADMIN TOKEN:" -i "${ADMTKN}" ADMTKN
read -e -p "Enter ADMIN Password:" -i "${ADMINPASS}" ADMINPASS
read -e -p "Enter Domain name for Vault Website:" -i "${DOMAIN}" DOMAIN
read -e -p "Enter https port number:" -i "${HTTPS}" HTTPS
read -e -p "Enter tag version:" -i "${VERSION}" VERSION

if ! [ -f  "./layer.tar" ]; then
  proc="$(uname -m)"
  printf "Select Base Image\n"
  printf "1 - Fedora 33\n" 
  printf "2 - Centos 8\n"
  read -e -p "Enter nummber: " -i "1" RELEASE
  case "${RELEASE}" in
	"1")
		page="https://fr2.rpmfind.net/linux/fedora/linux/releases/33/Container/${proc}/images/"
		image="$(curl -s $page | grep -e "Fedora-Container-Base-.*.tar.xz"|sed -e 's!^.*\(Fedora-Container-Base.*.tar.xz\).*$!\1!m')"
		OS="Fedora"
		;;
	"2")
		page="https://cloud.centos.org/centos/8/${proc}/images/"
		image="$(curl -s $page | grep -e "CentOS-8-Container-.*.tar.xz"|sed -e 's!^.*\(CentOS-8-Container.*.tar.xz\).*$!\1!m'|tail -1)"
		OS="CentOS"
		;;
	*)
		printf "Invalid choice\n"
		exit 1
		;;
  esac
  printf "Downloading ${image}\n"
  curl -sSl ${page}${image} -o/tmp/${image}
  tar -Jxv -f /tmp/${image} --strip-components=1 */layer.tar
  printf "${OS}" > os.version
  
fi

if ! [ -d  "${DATADIR}" ]; then
	printf  "${DATADIR} does not exist, please provide a location for vault store\n "
	read -e -p "Enter Base DATA directory:" -i "${DATADIR}" DATADIR
fi

if ! [ -d  "${DATADIR}/bitwarden" ]; then
	mkdir "${DATADIR}/bitwarden"
fi

if ! [ -d  "${DATADIR}/bitwarden/certs" ]; then
	mkdir "${DATADIR}/bitwarden/certs"
else
	if ! [ -f  "${DATADIR}/bitwarden/certs/CA-Bitwarden.pem" ]; then
		openssl req -new -x509 -nodes -days 7300 -outform PEM -newkey rsa:4096 -sha256 \
		-keyout ${DATADIR}/bitwarden/certs/CA-Bitwarden.key \
		-out ${DATADIR}/bitwarden/certs/CA-Bitwarden.pem \
		-subj "/CN=CA Bitwarden/emailAddress=admin@${DOMAIN}/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder"; 
		openssl req -nodes -newkey rsa:2048 -sha256 \
		-keyout ${DATADIR}/bitwarden/certs/bitwarden.key \
		-out ${DATADIR}/bitwarden/certs/bitwarden.csr \
		-subj "/CN=vault.bitwarden.lan/emailAddress=admin@${DOMAIN}/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder";
	fi
	
	if ! [ -f  "${DATADIR}/bitwarden/certs/bitwarden.pem" ]; then
		openssl x509 -req -outform PEM -CAcreateserial \
		-in ${DATADIR}/bitwarden/certs/bitwarden.csr \
		-CA ${DATADIR}/bitwarden/certs/CA-Bitwarden.pem \
		-CAkey ${DATADIR}/bitwarden/certs/CA-Bitwarden.key \
		-out ${DATADIR}/bitwarden/certs/bitwarden.pem
	fi
fi	

if ! [ -d  "${DATADIR}/bitwarden/logs" ]; then
	mkdir -p "${DATADIR}/bitwarden/logs/{bitwarden,httpd}}"
fi



export ADMTKN="${ADMTKN}" DOMAIN="${DOMAIN}" HTTPS="${HTTPS}"
envsubst '${ADMTKN} ${DOMAIN}'< .env.txt > .env
envsubst '${DOMAIN} ${HTTPS}' < vhost.template.txt > vhost.conf
envsubst '${HTTPS}' < ssl.template.txt > ssl.conf
envsubst '${DOMAIN} ${HTTPS}' < Dockerfile.template.txt > Dockerfile


if [[ ${OS}=="" ]]; then
  if [ -f os.version ];then
    OS="$(cat os.version)"
  else	
    OS="$(cat /etc/redhat-release | cut -d" " -f1)"
    printf "${OS}" > os.version
  fi
fi
printf "Executed Command :\n"
printf "podman build --squash-all -t "$(tr '[:upper:]' '[:lower:]' <<< ${OS})"-bitwarden:${VERSION} --build-arg admpass=${ADMINPASS} --build-arg OS=${OS} -v ${DATADIR}/bitwarden:/var/lib/bitwarden:Z -f Dockerfile"
sudo podman build --squash-all -t "$(tr '[:upper:]' '[:lower:]' <<< ${OS})"-bitwarden:${VERSION} --build-arg admpass=${ADMINPASS} --build-arg OS=${OS} -v ${DATADIR}/bitwarden:/var/lib/bitwarden:Z -f Dockerfile