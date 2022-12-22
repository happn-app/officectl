#!/bin/bash
set -e

cd "$(dirname "$0")"/..

readonly LDAP_IMAGE="bitnami/openldap:2.6.3"
readonly LDAP_CONTAINER_NAME="officectl_testhelper-ldap"

readonly LDAP_DATA_PATH="$(pwd)/TestsData/live/docker/ldap"
readonly LDAP_INIT_PATH="$(pwd)/TestsData/confs/shared/ldap-docker-init"

echo "*** Stopping and deleting previous LDAP container if applicable..."
docker rm -f "$LDAP_CONTAINER_NAME" || true
echo "*** Removing previous LDAP data..."
rm -frv "$LDAP_DATA_PATH"
echo "*** Creating new live folders for LDAP docker..."
mkdir -p "$LDAP_DATA_PATH"
echo "*** Starting new LDAP container..."
docker network create officectl 2>/dev/null || true
#	-e LDAP_LOGLEVEL="-1"                          \+
docker run --detach                               \
	--name "$LDAP_CONTAINER_NAME"                  \
	--net officectl                                \
	--volume "$LDAP_INIT_PATH":"/ldifs"            \
	--volume "$LDAP_DATA_PATH":"/bitnami/openldap" \
	-e LDAP_ROOT="dc=happn,dc=test"                \
	-e LDAP_USER_DC="people"                       \
	-e LDAP_ADMIN_USERNAME="admin"                 \
	-e LDAP_ADMIN_PASSWORD="toto"                  \
	-e LDAP_SKIP_DEFAULT_TREE="yes"                \
	-e LDAP_ALLOW_ANON_BINDING="false"             \
	-p"8389:1389"                                  \
	"$LDAP_IMAGE"

echo
echo "Done. LDAP should be accessible with:"
echo "   ldapvi -h localhost:8389 -D cn=admin,dc=happn,dc=test -w toto -b dc=happn,dc=test"
echo "   ldapsearch -p 8389 -h localhost -D cn=admin,dc=happn,dc=test -w toto -b dc=happn,dc=test"
echo "You should be able access the LDAP from within a docker container using the “--net officectl” option, with hostname “${LDAP_CONTAINER_NAME}” on port 389."
