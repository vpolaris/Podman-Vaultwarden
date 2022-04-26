#!/bin/bash
ADMTKN="$(tr -cd [:alnum:] < /dev/urandom | fold -w 48 | head -n 1)"
ADMINPASS="$(tr -cd [:alnum:] < /dev/urandom | fold -w 16 | head -n 1)"
DOMAIN="vault.vaultwarden.lan"
HTTPS="443"
DB_BACKUP="enabled"
SSLSTORE="$HOME/.ssl"
VERSION="latest"

if [ "${EUID}" -ne 0 ]; then 
	printf "your are not root user. To proceed run\nsudo ./setup.sh\n"
	exit 0
fi

if [ -f  "./.settings" ]; then
    read -e -p "Do you want to load your settting ? (y|n) " -i "n" LOAD
    if [ "${LOAD}" == "y" ]; then 
        source ./.settings
        ADMTKN=$(echo "${ADMTKN}"|openssl enc -d -base64)
        ADMINPASS=$(echo "${ADMINPASS}"|openssl enc -d -base64)      
    fi
fi

read -e -p "Enter ADMIN TOKEN:" -i "${ADMTKN}" ADMTKN
read -e -p "Enter ADMIN Password:" -i "${ADMINPASS}" ADMINPASS
read -e -p "Enter Domain name for Vault Website:" -i "${DOMAIN}" DOMAIN
read -e -p "Enter https port number:" -i "${HTTPS}" HTTPS
read -e -p "Enter tag version:" -i "${VERSION}" VERSION
read -e -p "DB Backup (enabled/disabled):" -i "${DB_BACKUP}" DB_BACKUP
read -e -p "Do you have certificates to push ? (y|n) " -i "n" CERTS

case "${CERTS}" in
	"y")
	  read -e -p "Enter certificate location :" -i "${SSLSTORE}" SSLSTORE
	  ;;
	"n")
	  SSLSTORE="unknown"
	  ;;
	*)
	  printf "Invalid choice\n"
	  exit 1
	;;
esac


if [[ $(id -u vaultwarden) -eq 10502 ]]; then 
	printf "User vaultwarden already exists\n";
	usermod -s /bin/bash vaultwarden
else
	printf "Creation of vaultwarden user\n";
    if [[ "$(getent group docker)"!="" ]];then 
        printf "group docker exists\n"
    else
        groupadd docker
    fi
	useradd -m -u 10502 -G docker --shell /bin/bash --comment "Vaultwarden RS User Container" --user-group vaultwarden
	loginctl enable-linger 10502
	systemctl start user@10502.service
fi


if ! [ -f  "./layer.tar" ]; then
  proc="$(uname -m)"
  printf "Select Base Image\n"
  printf "1 - Fedora 35\n" 
  printf "2 - Centos 8\n"
  read -e -p "Enter nummber: " -i "1" RELEASE
  case "${RELEASE}" in
	"1")
		page="https://fr2.rpmfind.net/linux/fedora/linux/releases/35/Container/${proc}/images/"
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
  tar -Jxv -f /tmp/${image} --wildcards --strip-components=1 */layer.tar
  printf "${OS}" > os.version
  
fi

HOMEDIR=$( getent passwd "vaultwarden" | cut -d: -f6 )
DATADIR="${HOMEDIR}/.persistent_storage"

if ! [ -d  "${DATADIR}" ]; then 
	printf  "${DATADIR} does not exist, please provide a location for vault store\n "; 
	read -e -p "Enter Base DATA directory:" -i "${DATADIR}" DATADIR; 
fi


if ! [ -d  "${DATADIR}/vaultwarden/certs" ]; then
	mkdir -p "${DATADIR}/vaultwarden/certs"
fi	

if ! [ -d  "${DATADIR}/vaultwarden//data" ]; then
	mkdir -p "${DATADIR}/vaultwarden/data"
fi

if ! [ -d  "${DATADIR}/vaultwarden/logs" ]; then
	mkdir -p "${DATADIR}/vaultwarden/logs/{vaultwarden,httpd}"
fi

if ! [ -d  "${DATADIR}/vaultwarden//project" ]; then
	mkdir -p "${DATADIR}/vaultwarden/project"
fi

if ! [ -f  "${DATADIR}/vaultwarden/certs/CA-Vaultwarden.pem" ]; then
	if [ -f  "${SSLSTORE}/CA-Vaultwarden.pem" ]; then
		cp "${SSLSTORE}/CA-Vaultwarden" "${DATADIR}/vaultwarden/certs/CA-Vaultwarden.pem"
	else
		openssl req -new -x509 -nodes -days 7300 -outform PEM -newkey rsa:4096 -sha256 \
		-keyout ${DATADIR}/vaultwarden/certs/CA-Vaultwarden.key \
		-out ${DATADIR}/vaultwarden/certs/CA-Vaultwarden.pem \
		-subj "/CN=CA Vaultwarden/emailAddress=admin@${DOMAIN}/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder"; 
		openssl req -nodes -newkey rsa:4096 -sha256 \
		-keyout ${DATADIR}/vaultwarden/certs/vaultwarden.key \
		-out ${DATADIR}/vaultwarden/certs/vaultwarden.csr \
		-subj "/CN=${DOMAIN}/emailAddress=admin@${DOMAIN}/C=FR/ST=IDF/L=Paris/O=Podman Inc/OU=Podman builder";
	fi
fi

if ! [ -f  "${DATADIR}/vaultwarden/certs/vaultwarden.pem" ]; then
	if [ -f  "${SSLSTORE}/vaultwarden.pem" ]; then
		cp "${SSLSTORE}/vaultwarden.pem" "${DATADIR}/vaultwarden/certs/vaultwarden.pem"
	else
		openssl x509 -req -days 730 -outform PEM -CAcreateserial \
		-in ${DATADIR}/vaultwarden/certs/vaultwarden.csr \
		-CA ${DATADIR}/vaultwarden/certs/CA-Vaultwarden.pem \
		-CAkey ${DATADIR}/vaultwarden/certs/CA-Vaultwarden.key \
		-out ${DATADIR}/vaultwarden/certs/vaultwarden.pem
	fi
	if [ -f  "${SSLSTORE}/vaultwarden.key" ]; then
		cp "${SSLSTORE}/vaultwarden.key" "${DATADIR}/vaultwarden/certs/vaultwarden.key"
	fi
fi

if ! [ -d  "${HOMEDIR}/.config" ]; then
	mkdir -p "${HOMEDIR}/.config/containers"
fi

if ! [ -d  "${HOMEDIR}/.local/share/containers" ]; then
	mkdir -p "${HOMEDIR}/.local/share/containers"
fi

if ! [ -d  "./configurations" ]; then
	mkdir "./configurations"
fi

if [ -d  "${DATADIR}/project" ]; then
	rm -rf "${DATADIR}/project"
fi


chown -R vaultwarden: "${DATADIR}" "${HOMEDIR}/.config" "${HOMEDIR}/.local"; chmod -R 770 "${DATADIR}"

if [ "$(getenforce)" == "Enforcing" ]; then
	printf  "selinux is active\n"
	if [ -f  "/home/vaultwarden/.config/selinux.was.setup" ]; then
		printf  "selinux is already configured \n"
	else    
		setsebool -P virt_sandbox_use_netlink 1
		setsebool -P httpd_can_network_connect on
		setsebool -P container_manage_cgroup true
		semanage fcontext -a -e "/var/lib/containers" "${HOMEDIR}/.local/share/containers"
		semanage fcontext -a -e "/etc/containers" "${HOMEDIR}/.config/containers"
		restorecon -R "${HOMEDIR}/.local/share/containers" "${HOMEDIR}/.config/containers"
		semanage fcontext -a -t container_file_t "${DATADIR}/vaultwarden(/.*)?"
		restorecon -R "${DATADIR}/vaultwarden"
		touch "${HOMEDIR}/.config/selinux.was.setup"
	fi
fi

export ADMTKN="${ADMTKN}" DOMAIN="${DOMAIN}" HTTPS="${HTTPS}" DB_BACKUP="${DB_BACKUP}"
envsubst '${ADMTKN} ${DOMAIN}'< ./templates/env.tpl > ./configurations/.env
envsubst '${DOMAIN} ${HTTPS}' < ./templates/vhost.tpl > ./configurations/vhost.conf
envsubst '${HTTPS}' < ./templates/ssl.tpl > ./configurations/ssl.conf
envsubst '${DB_BACKUP} ${DOMAIN} ${HTTPS}' < ./templates/Dockerfile.tpl > Dockerfile
cp -rf . "${DATADIR}/project"

cat /usr/share/containers/containers.conf | sed -e '/# dns_servers = \[\]/a dns_servers = \["1.1.1.1"\]' -e '/# tz = ""/a tz = "local"' -e '/# runtime = "crun"/a runtime = "crun"' -e '/# cgroup_manager = "systemd"/a cgroup_manager = "systemd"' -e'/# events_logger = "journald"/a events_logger = "journald"' -e '/# cgroups = "enabled"/a cgroups = "enabled"' -e'/# cgroupns = "private"/a cgroupns = "private"' -e 's/log_driver = "k8s-file"/#log_driver = "k8s-file"/' -e '/#log_driver = "k8s-file/a log_driver = "journald"' -e'/# log_tag = ""/a log_tag = "vaultwarden"' > /home/vaultwarden/.config/containers/containers.conf

if [[ ${OS}=="" ]]; then
  if [ -f os.version ];then
    OS="$(cat os.version)"
  else	
    OS="$(cat /etc/redhat-release | cut -d" " -f1)"
    printf "${OS}" > os.version
  fi
fi
TAGNAME="$(tr '[:upper:]' '[:lower:]' <<< ${OS})"-vaultwarden:"${VERSION}"
printf "Do you want to start build process (y|n)\n"
read -e -p "Enter your answer " -i "y" VALIDATE
case "${VALIDATE}" in
	"y")
	printf "Executed Command :\n"
	printf "sudo su - vaultwarden -c podman build -t ${TAGNAME} --build-arg admpass=${ADMINPASS} --build-arg OS=${OS} --build-arg HTTPS=${HTTPS} -v ${DATADIR}/vaultwarden:/var/lib/vaultwarden:Z -f ${DATADIR}/project/Dockerfile\n"
	sudo su - vaultwarden -c "podman build --squash-all -t ${TAGNAME} \
        --build-arg admpass=${ADMINPASS} --build-arg OS=${OS} --build-arg HTTPS=${HTTPS} \
        -v ${DATADIR}/vaultwarden:/var/lib/vaultwarden:Z \
        -f ${DATADIR}/project/Dockerfile"
	;;
	"n")
	printf "To launch your built run the following command :\n"
	printf "sudo su - vaultwarden -c podman build --squash-all -t ${TAGNAME} --build-arg admpass=${ADMINPASS} --build-arg OS=${OS} --build-arg HTTPS=${HTTPS} -v ${DATADIR}/vaultwarden:/var/lib/vaultwarden:Z -f ${DATADIR}/project/Dockerfile\n"
	exit 0
	;;
	*)
	printf "Invalid choice\n"
	exit 1
	;;
esac

if [ -f  "${DATADIR}/vaultwarden/build.completed" ]; then
    printf "Succesfully build ${TAGNAME}\n"
	rm -f "${DATADIR}/vaultwarden/build.completed"

	FILENAME="$(tr '[:upper:]' '[:lower:]' <<< ${OS})"-vaultwarden.${VERSION}.oci
	printf "Saving image file under ${DATADIR}/vaultwarden/project/${FILENAME}\n"
	sudo su - vaultwarden -c "podman image save --format oci-archive -o ${DATADIR}/vaultwarden/project/${FILENAME} localhost/${TAGNAME}"
	
	printf "Launching image file ${DATADIR}/vaultwarden/project/${FILENAME}\n"
	if [[ $(sudo su - vaultwarden -c "export XDG_RUNTIME_DIR=/run/user/10502 ;systemctl --user list-unit-files -t service|grep 'container'") != "" ]]; then
		printf "Stopping previous container service\n"
		sudo su - vaultwarden -c "export XDG_RUNTIME_DIR=/run/user/10502 ;systemctl --user stop container-vaultwarden.service"
		sudo su - vaultwarden -c "export XDG_RUNTIME_DIR=/run/user/10502 ;systemctl --user disable container-vaultwarden.service" 
		rm -rf ${HOMEDIR}/.config/systemd/user/container-vaultwarden.service
		pkill conmon
		#sudo rm -rf /run/user/10502/containers/ 
	fi
	
	if [ ${HTTPS} -le 1024 ]; then
	  printf "Port ${HTTPS} belong to reserved port <=1024 .\n "
	  read -e -p "Do you want add net.ipv4.ip_unprivileged_port_start=${HTTPS} to kernel config (y)? or enter another port (n): " -i "n" RESPONSE
      case "${RESPONSE}" in
	    "y")
	      printf "net.ipv4.ip_unprivileged_port_start=${HTTPS}" > "/etc/sysctl.d/75-unpriviliged-port-start-at-${HTTPS}.conf";
		  sysctl -p "/etc/sysctl.d/75-unpriviliged-port-start-at-${HTTPS}.conf";
		  MPORT="${HTTPS}";
	      ;;
		"n")
		  read -e -p "Enter new port to map : " -i "2${HTTPS}" MPORT;
	      ;;
	    *)
	      printf "Invalid choice\n";
	      exit 1;
	      ;;
      esac
	else
	  MPORT="${HTTPS}"
	fi
	
	sudo su - vaultwarden -c "podman run -d --replace --name vaultwarden -h vaultwarden.lan \
         -v ${DATADIR}/vaultwarden:/var/lib/vaultwarden:Z -p 0.0.0.0:${MPORT}:${HTTPS}/tcp \
        --health-cmd \"CMD-SHELL curl -LIk https://${DOMAIN}:${MPORT}/alive -o /dev/null -w '%{http_code}\n' -s | grep 200 || exit 1\" \
        --health-interval 15m \
        --health-start-period 2m \
        localhost/${TAGNAME}"
	
	printf "Generating systemd service file\n"
	if [ -f  "${HOMEDIR}/container-vaultwarden.service" ]; then
		rm -f ${HOMEDIR}/container-vaultwarden.service
		rm -f /etc/systemd/user/container-vaultwarden.service
	fi
	sudo su - vaultwarden -c "podman generate systemd -f -n vaultwarden --restart-policy=always"
	
	printf "Starting systemd container-vaultwarden.service as user vaultwarden\n"
	cp  -f ${HOMEDIR}/container-vaultwarden.service /etc/systemd/user/container-vaultwarden.service
	sudo su - vaultwarden -c "export XDG_RUNTIME_DIR=/run/user/10502 ;systemctl daemon-reload --user"
	sudo su - vaultwarden -c "export XDG_RUNTIME_DIR=/run/user/10502 ;systemctl --user enable /etc/systemd/user/container-vaultwarden.service"
	sudo su - vaultwarden -c "podman container stop vaultwarden"
	sudo su - vaultwarden -c "export XDG_RUNTIME_DIR=/run/user/10502 ;systemctl --user start container-vaultwarden.service"
else
	printf "Something goes wrong during build operation ${TAGNAME}\n"
fi
usermod -s /sbin/nologin vaultwarden

read -e -p "Do you want to save your settting ? (y|n) " -i "n" SAVE
if [ "${SAVE}" == "y" ]; then 
cat <<EOF > ./.settings
ADMTKN=$(echo -n "${ADMTKN}"|openssl enc -base64)
ADMINPASS=$(echo -n "${ADMINPASS}"|openssl enc -base64)
DOMAIN="${DOMAIN}"
HTTPS="${HTTPS}"
DB_BACKUP="${DB_BACKUP}"
SSLSTORE="${SSLSTORE}"
VERSION="${VERSION}"
EOF
fi