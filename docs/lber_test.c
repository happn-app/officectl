/* Make with “LDFLAGS=-llber make lber_test” */

#include <lber.h>
#include <ldap.h>
#include <stdio.h>
#include <assert.h>



int main(void) {
	struct berval oldpw = {0, NULL};
	struct berval newpw = {0, NULL};
	void *ber = ber_alloc_t(LBER_USE_DER);
	assert(ber != NULL);

	oldpw.bv_val = strdup("toto");   oldpw.bv_len = strlen(oldpw.bv_val);
	newpw.bv_val = strdup("hello!"); newpw.bv_len = strlen(newpw.bv_val);
	ber_printf(ber, "{" "ts" /* "tO" */ "tO" "N}",
		LDAP_TAG_EXOP_MODIFY_PASSWD_ID, "uid=ldap.test,ou=people,dc=happn,dc=com",
//		LDAP_TAG_EXOP_MODIFY_PASSWD_OLD, &oldpw,
		LDAP_TAG_EXOP_MODIFY_PASSWD_NEW, &newpw);
	free(oldpw.bv_val); oldpw.bv_val = NULL; oldpw.bv_len = 0;
	free(newpw.bv_val); newpw.bv_val = NULL; newpw.bv_len = 0;

	struct berval bv = {0, NULL};
	ber_flatten2(ber, &bv, 0);

	FILE *fp = fopen("/Users/frizlab/Desktop/lber_test.data", "w");
	fwrite(bv.bv_val, sizeof(char), bv.bv_len, fp);
	fclose(fp);
	fp = NULL;

	ber_free(ber, 1);

	return 0;
}
