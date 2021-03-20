#!/bin/bash
ADMTKN="$(tr -cd [:alnum:] < /dev/urandom | fold -w 48 | head -n 1)"
ADMINPASS="$(tr -cd [:alnum:] < /dev/urandom | fold -w 16 | head -n 1)"
DOMAIN="vault.bitwarden.lan"
HTTPS="443"
DATADIR="/data_vol"

read -e -p "Enter ADMIN TOKEN:" -i "${ADMTKN}" ADMTKN
read -e -p "Enter ADMIN Password:" -i "${ADMINPASS}" ADMINPASS
read -e -p "Enter Domain name for Vault Website:" -i "${DOMAIN}" DOMAIN
read -e -p "Enter https port number:" -i "${HTTPS}" HTTPS

if ! [ -d  "${DATADIR}" ]; then
 printf  "${DATADIR} does not exist, please provide a location for vault store\n "
 read -e -p "Enter DATA directory:" -i "${DATADIR}" DATADIR
fi

export ADMTKN="${ADMTKN}" DOMAIN="${DOMAIN}" HTTPS="${HTTPS}" 
envsubst '${ADMTKN} ${DOMAIN}'< .env.txt > .env 
envsubst '${DOMAIN} ${HTTPS}' < vhost.template.txt > vhost.conf
envsubst '${HTTPS}' < ssl.template.txt > ssl.conf
envsubst '${DOMAIN} ${HTTPS}' < Dockerfile.template.txt > Dockerfile
