/* From https://github.com/vapor/crypto/blob/master/Sources/CCryptoOpenSSL/shim.h */
#ifndef __SWIFT_COPENSSL__
# define __SWIFT_COPENSSL__

/* This symbol poses an issue with an incompatible declaration with the same
 * name in another module.
 * This hack is unacceptable though… */
# define ASN1_ENCODING_st HPN_ASN1_ENCODING_st

# include <openssl/bio.h>
# include <openssl/pem.h>

# undef ASN1_ENCODING_st

#endif /* __SWIFT_COPENSSL__ */
