#!/bin/bash

set -e

cd "$(dirname "$0")"/..

readonly LDAP_NAME=officectl_testhelper_ldap
readonly LDAP_DATA_PATH="$(pwd)/TestsData/Docker/LDAP"
readonly LDAP_INIT_PATH="$(pwd)/Scripts/zz_assets/test_helpers/ldap"

echo "Stopping and deleting previous LDAP container if applicable"
docker rm -f "$LDAP_NAME" || true
echo "Removing previous LDAP data"
rm -frv "$LDAP_DATA_PATH"
echo "Starting new LDAP container"
docker network create officectl 2>/dev/null || true
docker run -d --net officectl --name "$LDAP_NAME" --volume "$LDAP_INIT_PATH":/etc/ldap.dist/prepopulate --volume "$LDAP_DATA_PATH"/config:/etc/ldap --volume "$LDAP_DATA_PATH"/data:/var/lib/ldap -e SLAPD_PASSWORD=toto -e SLAPD_DOMAIN=happn.test -p8389:389 dinkel/openldap

echo
echo "Done. LDAP should be accessible with:"
echo "   ldapvi -h localhost:8389 -D cn=admin,dc=happn,dc=test -w toto -b dc=happn,dc=test"
echo "   ldapsearch -p 8389 -h localhost -D cn=admin,dc=happn,dc=test -w toto -b dc=happn,dc=test"
echo "You should be able access the LDAP from within a docker container using the “--net officectl” option, with hostname “${LDAP_NAME}” on port 389."
