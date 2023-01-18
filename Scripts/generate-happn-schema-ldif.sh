#!/bin/bash
set -e

# Move in the folder with the schema(s)
cd "$(dirname "$0")"/../TestsData/confs/shared/ldap-docker-init/schemas

TMP_CONF_FILE="_ldap.conf"

# Verify the conf file does not exist.
test ! -e "$TMP_CONF_FILE"

# Create the temporary conf file that will be used to do the conversion of the .schema files into ldif files.
for schema in *.schema; do
	echo "include $schema" >>"$TMP_CONF_FILE"
done

slaptest -f "$TMP_CONF_FILE" -F .
rm -f "$TMP_CONF_FILE"

# Move the generated ldifs in .
for ldif in "./cn=config/cn=schema"/*.ldif; do
	mv -f "$ldif" "$(basename "$ldif" | sed -E 's/^cn=\{[0-9]+\}//')"
done

# Remove extra files
rm -fr "./cn=config.ldif"
rm -fr "./cn=config"

# Print some info
echo "The ldif have been created. Only the following properties should be kept (not removed automatically):"
echo "  - dn (value should start with “cn={0}”);"
echo "  - objectClass (value should be “olcSchemaConfig”);"
echo "  - cn (value should be the value of the dn minus “cn=”);"
echo "  - olcAttributeTypes"
echo "  - olcObjectClasses"
echo
echo "The dn and cn should be modified: remove “{0}” for both keys, and add “,cn=schema,cn=config” to dn."
echo
echo "Source: https://www.cyrill-gremaud.ch/how-to-add-new-schema-to-openldap-2-4/"
