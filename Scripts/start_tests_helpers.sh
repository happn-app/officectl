#!/bin/bash

set -e

cd "$(dirname "$0")"/..

readonly LDAP_NAME=officectl_testhelper_ldap
readonly LDAP_DATA_PATH="$(pwd)/TestsData/Docker/LDAP"

echo "Stopping and deleting previous LDAP container if applicable"
docker rm -f "$LDAP_NAME" || true
echo "Removing previous LDAP data"
rm -frv "$LDAP_DATA_PATH"
echo "Starting new LDAP container"
docker run -d --name "$LDAP_NAME" --volume "$LDAP_DATA_PATH"/config:/etc/ldap --volume "$LDAP_DATA_PATH"/data:/var/lib/ldap -e SLAPD_PASSWORD=toto -e SLAPD_DOMAIN=happn.test -p8389:389 dinkel/openldap

echo
echo "Done. LDAP should be accessible with:"
echo "   ldapsearch -p 8389 -h localhost -D cn=admin,dc=happn,dc=test -w toto -b dc=happn,dc=test"
