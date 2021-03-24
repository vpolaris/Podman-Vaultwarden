#!/bin/bash
ADMTKN="$(tr -cd [:alnum:] < /dev/urandom | fold -w 48 | head -n 1)"
ADMINPASS="$(tr -cd [:alnum:] < /dev/urandom | fold -w 16 | head -n 1)"
DOMAIN="vault.bitwarden.lan"
HTTPS="443"
DATADIR="/home/bitwarden/.persistent_storage/"
SSLSTORE="$HOME/.ssl"
VERSION="1.00"

if [ "${EUID}" -ne 0 ]; then 
	printf "your are not root user. To proceed run\nsudo ./setup.sh\n"
	exit 0
fi

read -e -p "Enter ADMIN TOKEN:" -i "${ADMTKN}" ADMTKN
read -e -p "Enter ADMIN Password:" -i "${ADMINPASS}" ADMINPASS
read -e -p "Enter Domain name for Vault Website:" -i "${DOMAIN}" DOMAIN
read -e -p "Enter https port number:" -i "${HTTPS}" HTTPS
read -e -p "Enter tag version:" -i "${VERSION}" VERSION

read -e -p "Do you have certificates to push ? (y|n) " -i "n" CERTS
case "${CERTS}" in
	"y")
	read -e -p "Enter cerficate location :" -i "${SSLSTORE}" SSLSTORE
	;;
	"n")
	SSLSTORE="unknown"
	;;
	*)
	printf "Invalid choice\n"
	exit 1
	;;
esac


if [[ $(id -u bitwarden) -eq 10500 ]]; then 
	printf "User bitwarden already exists\n";
	usermod -s /bin/bash bitwarden
else
	printf "Creation of bitwarden user\n";
	adduser -u 10500 -G docker --shell /bin/bash --comment "Bitwarden RS User Container" --user-group bitwarden
	loginctl enable-linger 10500
	systemctl start user@10500.service
fi

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
	printf  "${DATADIR} does not exist, please provide a location for vault store\n "; 
	read -e -p "Enter Base DATA directory:" -i "${DATADIR}" DATADIR; 
fi

if ! [ -d  "${DATADIR}/bitwarden" ]; then
	mkdir -p "${DATADIR}/bitwarden/project"
fi

if ! [ -d  "${DATADIR}/bitwarden/certs" ]; then
	mkdir -p "${DATADIR}/bitwarden/certs"
fi	

if ! [ -d  "${DATADIR}/bitwarden/logs" ]; then
	mkdir -p "${DATADIR}/bitwarden/logs/{bitwarden,httpd}"
fi

if ! [ -f  "${DATADIR}/bitwarden/certs/CA-Bitwarden.pem" ]; then
	if [ -f  "${SSLSTORE}/CA-Bitwarden.pem" ]; then
		cp "${SSLSTORE}/CA-Bitwarden.pem" "${DATADIR}/bitwarden/certs/CA-Bitwarden.pem"
	else
		openssl req -new -x509 -nodes -days 7300 -outform PEM -newkey rsa:4096 -sha256 \
		-keyout ${DATADIR}/bitwarden/certs/CA-Bitwarden.key \
		-out ${DATADIR}/bitwarden/certs/CA-Bitwarden.pem \
		-subj "/CN=CA Bitwarden/emailAddress=admin@${DOMAIN}/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder"; 
		openssl req -nodes -newkey rsa:2048 -sha256 \
		-keyout ${DATADIR}/bitwarden/certs/bitwarden.key \
		-out ${DATADIR}/bitwarden/certs/bitwarden.csr \
		-subj "/CN=${DOMAIN}/emailAddress=admin@${DOMAIN}/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder";
	fi
fi

if ! [ -f  "${DATADIR}/bitwarden/certs/bitwarden.pem" ]; then
	if [ -f  "${SSLSTORE}/bitwarden.pem" ]; then
		cp "${SSLSTORE}/bitwarden.pem" "${DATADIR}/bitwarden/certs/bitwarden.pem"
	else
		openssl x509 -req -outform PEM -CAcreateserial \
		-in ${DATADIR}/bitwarden/certs/bitwarden.csr \
		-CA ${DATADIR}/bitwarden/certs/CA-Bitwarden.pem \
		-CAkey ${DATADIR}/bitwarden/certs/CA-Bitwarden.key \
		-out ${DATADIR}/bitwarden/certs/bitwarden.pem
	fi
	if [ -f  "${SSLSTORE}/bitwarden.key" ]; then
		cp "${SSLSTORE}/bitwarden.key" "${DATADIR}/bitwarden/certs/bitwarden.key"
	fi
fi

if ! [ -d  "/home/bitwarden/.config" ]; then
	mkdir -p "/home/bitwarden/.config/containers"
fi

if ! [ -d  "/home/bitwarden/.local/share/containers" ]; then
	mkdir -p "/home/bitwarden/.local/share/containers"
fi

cp -r . "${DATADIR}/bitwarden/project"
chown -R bitwarden: "${DATADIR}" "/home/bitwarden/.config" "/home/bitwarden/.local"; chmod -R 770 "${DATADIR}"

semanage fcontext -a -e "/var/lib/containers" "/home/bitwarden/.local/share/containers"
semanage fcontext -a -e "/etc/containers" "/home/bitwarden/.config/containers"
restorecon -R /home/bitwarden/.local/share/containers "/home/bitwarden/.config/containers"
semanage fcontext -a -f a -t container_file_t "${DATADIR}/bitwarden(/.*)?"
restorecon -R "${DATADIR}/bitwarden"
sudo su - bitwarden -c 'podman info'

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
TAGNAME="$(tr '[:upper:]' '[:lower:]' <<< ${OS})"-bitwarden:"${VERSION}"
printf "Do you want to start build process (y|n)\n"
read -e -p "Enter your answer " -i "y" VALIDATE
case "${VALIDATE}" in
	"y")
	printf "Executed Command :\n"
	printf "sudo su - bitwarden -c podman build --squash-all -t ${TAGNAME} --build-arg admpass=${ADMINPASS} --build-arg OS=${OS} --build-arg HTTPS=${HTTPS} -v ${DATADIR}/bitwarden:/var/lib/bitwarden:Z -f ${DATADIR}bitwarden/project/Dockerfile\n"
	sudo su - bitwarden -c "podman build --squash-all -t ${TAGNAME} --build-arg admpass=${ADMINPASS} --build-arg OS=${OS} --build-arg HTTPS=${HTTPS} -v ${DATADIR}/bitwarden:/var/lib/bitwarden:Z -f ${DATADIR}bitwarden/project/Dockerfile"
	;;
	"n")
	printf "To launch your built run the following command :\n"
	printf "sudo su - bitwarden -c podman build --squash-all -t ${TAGNAME} --build-arg admpass=${ADMINPASS} --build-arg OS=${OS} --build-arg HTTPS=${HTTPS} -v ${DATADIR}/bitwarden:/var/lib/bitwarden:Z -f ${DATADIR}bitwarden/project/Dockerfile\n"
	exit 0
	;;
	*)
	printf "Invalid choice\n"
	exit 1
	;;
esac

if [ -f  "${DATADIR}/bitwarden/build.completed" ]; then
    printf "Succesfully build ${TAGNAME}\n"
	rm -f "${DATADIR}/bitwarden/build.completed"

	FILENAME="$(tr '[:upper:]' '[:lower:]' <<< ${OS})"-bitwarden.${VERSION}.oci
	printf "Saving image file under ${DATADIR}bitwarden/project/${FILENAME}\n"
	sudo su - bitwarden -c "podman image save --format oci-archive -o ${DATADIR}bitwarden/project/${FILENAME} localhost/${TAGNAME}"
	
	printf "Launching image file ${DATADIR}bitwarden/project/${FILENAME}\n"
	if [[ $(sudo su - bitwarden -c "export XDG_RUNTIME_DIR=/run/user/10500 ;systemctl --user list-unit-files -t service|grep 'container'") != "" ]]; then
		printf "Stopping previous container service\n"
		sudo su - bitwarden -c "export XDG_RUNTIME_DIR=/run/user/10500 ;systemctl --user stop container-bitwarden.service"
	fi
	sudo su - bitwarden -c "podman run -d --replace --systemd=always --log-driver=journald --log-opt=tag=bitwarden --sdnotify=conmon --name bitwarden -h bitwarden.lan -v ${DATADIR}/bitwarden:/var/lib/bitwarden:Z -p ${HTTPS}:${HTTPS} localhost/${TAGNAME}"
	
	printf "Generating systemd service file\n"
	if [ -f  "/home/bitwarden/container-bitwarden.service" ]; then
		rm /home/bitwarden/container-bitwarden.service
	fi
	sudo su - bitwarden -c "podman generate systemd -f -n bitwarden --restart-policy=always"
	
	printf "Starting systemd container-bitwarden.service as user bitwarden\n"
	cp  -f /home/bitwarden/container-bitwarden.service /etc/systemd/user/container-bitwarden.service
	sudo su - bitwarden -c "export XDG_RUNTIME_DIR=/run/user/10500 ;systemctl daemon-reload --user"
	sudo su - bitwarden -c "export XDG_RUNTIME_DIR=/run/user/10500 ;systemctl --user enable /etc/systemd/user/container-bitwarden.service"
	sudo su - bitwarden -c "podman container stop bitwarden"
	sudo su - bitwarden -c "export XDG_RUNTIME_DIR=/run/user/10500 ;systemctl --user start container-bitwarden.service"
else
	printf "Something goes wrong during build operation ${TAGNAME}\n"
fi
usermod -s /sbin/nologin bitwarden