/*
 * Email+Validation.swift
 * OfficeKit
 *
 * From https://github.com/dominicsayers/isemail/tree/cfeefc3f2f88cb195053f6a309fa4f640cd369b5
 * The original source code is in PHP. This file is a straight conversion from
 * PHP. The tests have also been “stolen” from the repo.
 *
 * Created by François Lamboley on 22/03/2019.
 */

/**
To validate an email address according to RFCs 5321, 5322 and others

Copyright © 2008-2016, Dominic Sayers
Test schema documentation Copyright © 2011, Daniel Marschall
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    - Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    - Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    - Neither the name of Dominic Sayers nor the names of its contributors may be
      used to endorse or promote products derived from this software without
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

@package	is_email
@author	Dominic Sayers <dominic@sayers.cc>
@copyright	2008-2016 Dominic Sayers
@license	https://www.opensource.org/licenses/bsd-license.php BSD License
@link	https://www.dominicsayers.com/isemail
@version	3.0.7 - Changed my link to https://isemail.info throughout
*/

import Foundation



extension Email {
	
	/** Check that an email address conforms to RFCs 5321, 5322 and others.
	
	As of Version 3.0, we are now distinguishing clearly between a Mailbox as
	defined by RFC 5321 and an addr-spec as defined by RFC 5322. Depending on the
	context, either can be regarded as a valid email address. The RFC 5321
	Mailbox specification is more restrictive (comments, white space and obsolete
	forms are not allowed).
	
	- parameter email: The email address to check.
	- parameter checkDNS: If true a DNS check for MX records will be made.
	- parameter errorLevel: At which point an error is considered an error? */
	public static func evaluateEmail(_ email: String, checkDNS: Bool) -> ValidationDiagnosis {
		/* Relevant RFCs:
		 *    - https://tools.ietf.org/html/rfc5321
		 *    - https://tools.ietf.org/html/rfc5322
		 *    - https://tools.ietf.org/html/rfc4291#section-2.2
		 *    - https://tools.ietf.org/html/rfc1123#section-2.1
		 *    - https://tools.ietf.org/html/rfc3696 (guidance only) */
		
		var returnStatus = [ValidationDiagnosis.valid]
		
		/* Parse the address into components, character by character. */
		let rawLength = email.count
		var context = componentLocalpart /* Where we are */
		var contextStack = [context] /* Where we have been */
		var contextPrior = componentLocalpart /* Where we just came from */
		var token = "" /* The current character */
		var tokenPrior = "" /* The previous character */
		var parseData = [ /* The components of the address */
			componentLocalpart: "",
			componentDomain: ""
		]
		var atomList = [ /* For the dot-atom elements of the address */
			componentLocalpart: [Int: String](),
			componentDomain: [Int: String]()
		]
		var elementCount = 0
		var elementLen = 0
		var crlfCount: Int?
		var hyphenFlag = false /* Hyphen cannot occur at the end of a subdomain */
		var endOrDie = false /* CFWS can only appear at the end of the element */
		var i = email.startIndex
		while i < email.endIndex {
			token = String(email[i])
			defer {if i < email.endIndex {i = email.index(after: i)}}
			
			switch context {
			/* **********
			   Local Part
			   ********** */
			case componentLocalpart:
				/* https://tools.ietf.org/html/rfc5322#section-3.4.1
				 *   local-part      =   dot-atom / quoted-string / obs-local-part
				 *
				 *   dot-atom        =   [CFWS] dot-atom-text [CFWS]
				 *
				 *   dot-atom-text   =   1*atext *("." 1*atext)
				 *
				 *   quoted-string   =   [CFWS]
				 *                       DQUOTE *([FWS] qcontent) [FWS] DQUOTE
				 *                       [CFWS]
				 *
				 *   obs-local-part  =   word *("." word)
				 *
				 *   word            =   atom / quoted-string
				 *
				 *   atom            =   [CFWS] 1*atext [CFWS] */
				switch token {
				/* Comment */
				case stringOpenParenthesis:
					if elementLen == 0 {
						/* Comments are OK at the beginning of an element */
						returnStatus.append(elementCount == 0 ? .cfwsComment : .deprecComment)
					} else {
						returnStatus.append(.cfwsComment)
						endOrDie = true /* We can't start a comment in the middle of an element, so this better be the end */
					}
					
					contextStack.append(context)
					context = contextComment
					
				/* Next dot-atom element */
				case stringDot:
					if elementLen == 0 {
						/* Another dot, already? */
						returnStatus.append(elementCount == 0 ? .errDotStart : .errConsecutivedots) /* Fatal error */
					} else {
						/* The entire local-part can be a quoted string for RFC 5321
						 * If it's just one atom that is quoted then it's an RFC 5322
						 * obsolete form */
						if endOrDie {
							returnStatus.append(.deprecLocalpart)
						}
					}
					
					/* FLFL: Note, the code below was outside the else above, but
					 * indented as though it was in it. */
					endOrDie = false /* CFWS & quoted strings are OK again now we're at the beginning of an element (although they are obsolete forms) */
					elementLen = 0
					elementCount += 1
					parseData[componentLocalpart, default: ""] += token
					atomList[componentLocalpart, default: [:]][elementCount] = ""
					
				/* Quoted string */
				case stringDQuote:
					if elementLen == 0 {
						/* The entire local-part can be a quoted string for RFC 5321
						 * If it's just one atom that is quoted then it's an RFC 5322
						 * obsolete form */
						returnStatus.append(elementCount == 0 ? .rfc5321Quotedstring : .deprecLocalpart)
						
						parseData[componentLocalpart, default: ""] += token
						atomList[componentLocalpart, default: [:]][elementCount, default: ""] += token
						elementLen += 1
						endOrDie = true /* Quoted string must be the entire element */
						contextStack.append(context)
						context = contextQuotedstring
					} else {
						returnStatus.append(.errExpectingAtext) /* Fatal error */
					}
					
				/* Folding White Space */
				case stringCR:
					i = email.index(after: i)
					guard i < email.endIndex && String(email[i]) == stringLF else {
						returnStatus.append(.errCrNoLf) /* Fatal error */
						break
					}
					fallthrough
					
				case stringCRLF: fallthrough /* This case is not possible in PHP, but in Swift, because grapheme clusters, it is. */
				case stringSpace: fallthrough
				case stringHTab:
					if elementLen == 0 {
						returnStatus.append(elementCount == 0 ? .cfwsFws : .deprecFws)
					} else {
						endOrDie = true /* We can't start FWS in the middle of an element, so this better be the end */
					}
					
					contextStack.append(context)
					context = contextFws
					tokenPrior = token
					
				/* @ */
				case stringAt:
					/* At this point we should have a valid local-part */
					assert(contextStack.count == 1, "Unexpected item on context stack")
					
					if parseData[componentLocalpart, default: ""].isEmpty {
						returnStatus.append(.errNolocalpart) /* Fatal error */
					} else if elementLen == 0 {
						returnStatus.append(.errDotEnd) /* Fatal error */
					} else if parseData[componentLocalpart, default: ""].count > 64 {
						/* https://tools.ietf.org/html/rfc5321#section-4.5.3.1.1
						 *   The maximum total length of a user name or other local-part is 64
						 *   octets. */
						returnStatus.append(.rfc5322LocalToolong)
					} else if (contextPrior == contextComment) || (contextPrior == contextFws) {
						/* https://tools.ietf.org/html/rfc5322#section-3.4.1
						 *   Comments and folding white space
						 *   SHOULD NOT be used around the "@" in the addr-spec.
						 *
						 * https://tools.ietf.org/html/rfc2119
						 * 4. SHOULD NOT   This phrase, or the phrase "NOT RECOMMENDED" mean that
						 *    there may exist valid reasons in particular circumstances when the
						 *    particular behavior is acceptable or even useful, but the full
						 *    implications should be understood and the case carefully weighed
						 *    before implementing any behavior described with this label. */
						returnStatus.append(.deprecCfwsNearAt)
					}
					
					/* Clear everything down for the domain parsing */
					context = componentDomain /* Where we are */
					contextStack = [context]  /* Where we have been */
					elementCount = 0
					elementLen = 0
					endOrDie = false /* CFWS can only appear at the end of the element */
					
				/* AText */
				default:
					/* https://tools.ietf.org/html/rfc5322#section-3.2.3
					 *    atext           =   ALPHA / DIGIT /    ; Printable US-ASCII
					 *                        "!" / "#" /        ;  characters not including
					 *                        "$" / "%" /        ;  specials.  Used for atoms.
					 *                        "&" / "'" /
					 *                        "*" / "+" /
					 *                        "-" / "/" /
					 *                        "=" / "?" /
					 *                        "^" / "_" /
					 *                        "`" / "{" /
					 *                        "|" / "}" /
					 *                        "~" */
					if endOrDie {
						/* We have encountered atext where it is no longer valid */
						switch contextPrior {
						case contextComment:      fallthrough
						case contextFws:          returnStatus.append(.errAtextAfterCfws)
						case contextQuotedstring: returnStatus.append(.errAtextAfterQs)
						default:                  fatalError("More atext found where none is allowed, but unrecognised prior context: \(contextPrior)")
						}
					} else {
						contextPrior = context
						let scalar = token.first!.unicodeScalars.first!
						let ord = scalar.value
						
						if ord < 33 || ord > 126 || ord == 10 || stringSpecials.contains(scalar) {
							returnStatus.append(.errExpectingAtext) /* Fatal error */
						}
						
						parseData[componentLocalpart, default: ""] += token
						atomList[componentLocalpart, default: [:]][elementCount, default: ""] += token
						elementLen += 1
					}
				}
				
			/* ******
			   Domain
			   ****** */
			case componentDomain:
				/* https://tools.ietf.org/html/rfc5322#section-3.4.1
				 *   domain          =   dot-atom / domain-literal / obs-domain
				 *
				 *   dot-atom        =   [CFWS] dot-atom-text [CFWS]
				 *
				 *   dot-atom-text   =   1*atext *("." 1*atext)
				 *
				 *   domain-literal  =   [CFWS] "[" *([FWS] dtext) [FWS] "]" [CFWS]
				 *
				 *   dtext           =   %d33-90 /          ; Printable US-ASCII
				 *                       %d94-126 /         ;  characters not including
				 *                       obs-dtext          ;  "[", "]", or "\"
				 *
				 *   obs-domain      =   atom *("." atom)
				 *
				 *   atom            =   [CFWS] 1*atext [CFWS] */
				
				
				/* https://tools.ietf.org/html/rfc5321#section-4.1.2
				 *   Mailbox        = Local-part "@" ( Domain / address-literal )
				 *
				 *   Domain         = sub-domain *("." sub-domain)
				 *
				 *   address-literal  = "[" ( IPv4-address-literal /
				 *                    IPv6-address-literal /
				 *                    General-address-literal ) "]"
				 *                    ; See Section 4.1.3 */
				
				/* https://tools.ietf.org/html/rfc5322#section-3.4.1
				 *      Note: A liberal syntax for the domain portion of addr-spec is
				 *      given here.  However, the domain portion contains addressing
				 *      information specified by and used in other protocols (e.g.,
				 *      [RFC1034], [RFC1035], [RFC1123], [RFC5321]).  It is therefore
				 *      incumbent upon implementations to conform to the syntax of
				 *      addresses for the context in which they are used.
				 * is_email() author's note: it's not clear how to interpret this in
				 * the context of a general email address validator. The conclusion I
				 * have reached is this: "addressing information" must comply with
				 * RFC 5321 (and in turn RFC 1035), anything that is "semantically
				 * invisible" must comply only with RFC 5322. */
				switch token {
				/* Comment */
				case stringOpenParenthesis:
					if elementLen == 0 {
						/* Comments at the start of the domain are deprecated in the text
						 * Comments at the start of a subdomain are obs-domain
						 * (https://tools.ietf.org/html/rfc5322#section-3.4.1) */
						returnStatus.append(elementCount == 0 ? .deprecCfwsNearAt : .deprecComment)
					} else {
						returnStatus.append(.cfwsComment)
						endOrDie = true /* We can't start a comment in the middle of an element, so this better be the end */
					}
					
					contextStack.append(context)
					context = contextComment
					
				/* Next dot-atom element */
				case stringDot:
					if elementLen == 0 {
						/* Another dot, already? */
						returnStatus.append(elementCount == 0 ? .errDotStart : .errConsecutivedots) /* Fatal error */
					} else if hyphenFlag {
						/* Previous subdomain ended in a hyphen */
						returnStatus.append(.errDomainhyphenend) /* Fatal error */
					} else {
						/* Nowhere in RFC 5321 does it say explicitly that the domain
						 * part of a Mailbox must be a valid domain according to the
						 * DNS standards set out in RFC 1035, but this *is* implied in
						 * several places. For instance, wherever the idea of host
						 * routing is discussed the RFC says that the domain must be
						 * looked up in the DNS. This would be nonsense unless the
						 * domain was designed to be a valid DNS domain. Hence we must
						 * conclude that the RFC 1035 restriction on label length also
						 * applies to RFC 5321 domains.
						 *
						 * https://tools.ietf.org/html/rfc1035#section-2.3.4
						 * labels          63 octets or less */
						if elementLen > 63 {
							returnStatus.append(.rfc5322LabelToolong)
						}
					}
					
					/* FLFL: Note, the code below was outside the else above, but
					 * indented as though it was in it. */
					endOrDie = false /* CFWS is OK again now we're at the beginning of an element (although it may be obsolete CFWS) */
					elementLen = 0
					elementCount += 1
					atomList[componentDomain, default: [:]][elementCount] = ""
					parseData[componentDomain, default: ""] += token
					
				/* Domain literal */
				case stringOpenSquareBracket:
					if parseData[componentDomain, default: ""] == "" {
						endOrDie = true /* Domain literal must be the only component */
						elementLen += 1
						contextStack.append(context)
						context = componentLiteral
						parseData[componentDomain, default: ""] += token
						atomList[componentDomain, default: [:]][elementCount, default: ""] += token
						parseData[componentLiteral] = ""
					} else {
						returnStatus.append(.errExpectingAtext) /* Fatal error */
					}
					
				/* Folding White Space */
				case stringCR:
					i = email.index(after: i)
					guard i < email.endIndex && String(email[i]) == stringLF else {
						returnStatus.append(.errCrNoLf) /* Fatal error */
						break
					}
					fallthrough
					
				case stringCRLF: fallthrough /* This case is not possible in PHP, but in Swift, because grapheme clusters, it is. */
				case stringSpace: fallthrough
				case stringHTab:
					if elementLen == 0 {
						returnStatus.append(elementCount == 0 ? .deprecCfwsNearAt : .deprecFws)
					} else {
						returnStatus.append(.cfwsFws)
						endOrDie = true /* We can't start FWS in the middle of an element, so this better be the end */
					}
					
					contextStack.append(context)
					context = contextFws
					tokenPrior = token
					
				/* AText */
				default:
					/* RFC 5322 allows any atext...
					 * https://tools.ietf.org/html/rfc5322#section-3.2.3
					 *    atext           =   ALPHA / DIGIT /    ; Printable US-ASCII
					 *                        "!" / "#" /        ;  characters not including
					 *                        "$" / "%" /        ;  specials.  Used for atoms.
					 *                        "&" / "'" /
					 *                        "*" / "+" /
					 *                        "-" / "/" /
					 *                        "=" / "?" /
					 *                        "^" / "_" /
					 *                        "`" / "{" /
					 *                        "|" / "}" /
					 *                        "~" */
					
					/* But RFC 5321 only allows letter-digit-hyphen to comply with DNS rules (RFCs 1034 & 1123)
					 * https://tools.ietf.org/html/rfc5321#section-4.1.2
					 *   sub-domain     = Let-dig [Ldh-str]
					 *
					 *   Let-dig        = ALPHA / DIGIT
					 *
					 *   Ldh-str        = *( ALPHA / DIGIT / "-" ) Let-dig
					 */
					if endOrDie {
						/* We have encountered atext where it is no longer valid */
						switch contextPrior {
						case contextComment:   fallthrough
						case contextFws:       returnStatus.append(.errAtextAfterCfws)
						case componentLiteral: returnStatus.append(.errAtextAfterDomlit)
						default:               fatalError("More atext found where none is allowed, but unrecognised prior context: \(contextPrior)")
						}
					}
					
					let scalar = token.first!.unicodeScalars.first!
					let ord = scalar.value
					hyphenFlag = false /* Assume this token isn't a hyphen unless we discover it is */

					if ord < 33 || ord > 126 || stringSpecials.contains(scalar) {
						returnStatus.append(.errExpectingAtext) /* Fatal error */
					} else if token == stringHyphen {
						if elementLen == 0 {
							/* Hyphens can't be at the beginning of a subdomain */
							returnStatus.append(.errDomainhyphenstart) /* Fatal error */
						}
						
						hyphenFlag = true
					} else if !((ord > 47 && ord < 58) || (ord > 64 && ord < 91) || (ord > 96 && ord < 123)) {
						/* Not an RFC 5321 subdomain, but still OK by RFC 5322 */
						returnStatus.append(.rfc5322Domain)
					}
					
					parseData[componentDomain, default: ""] += token
					atomList[componentDomain, default: [:]][elementCount, default: ""] += token
					elementLen += 1
				}
				
			/* **************
			   Domain Literal
			   ************** */
			case componentLiteral:
				/* https://tools.ietf.org/html/rfc5322#section-3.4.1
				 *   domain-literal  =   [CFWS] "[" *([FWS] dtext) [FWS] "]" [CFWS]
				 *
				 *   dtext           =   %d33-90 /          ; Printable US-ASCII
				 *                       %d94-126 /         ;  characters not including
				 *                       obs-dtext          ;  "[", "]", or "\"
				 *
				 *   obs-dtext       =   obs-NO-WS-CTL / quoted-pair */
				switch token {
				/* End of domain literal */
				case stringCloseSquareBracket:
					/* FLFL: Is the bang on the line below valid? */
					if returnStatus.max(by: { $0.value < $1.value })!.value < ValidationCategory.deprec.value {
						/* Could be a valid RFC 5321 address literal, so let's check */
						
						/* https://tools.ietf.org/html/rfc5321#section-4.1.2
						 *   address-literal  = "[" ( IPv4-address-literal /
						 *                    IPv6-address-literal /
						 *                    General-address-literal ) "]"
						 *                    ; See Section 4.1.3
						 *
						 * https://tools.ietf.org/html/rfc5321#section-4.1.3
						 *   IPv4-address-literal  = Snum 3("."  Snum)
						 *
						 *   IPv6-address-literal  = "IPv6:" IPv6-addr
						 *
						 *   General-address-literal  = Standardized-tag ":" 1*dcontent
						 *
						 *   Standardized-tag  = Ldh-str
						 *                     ; Standardized-tag MUST be specified in a
						 *                     ; Standards-Track RFC and registered with IANA
						 *
						 *   dcontent       = %d33-90 / ; Printable US-ASCII
						 *                  %d94-126 ; excl. "[", "\", "]"
						 *
						 *   Snum           = 1*3DIGIT
						 *                  ; representing a decimal integer
						 *                  ; value in the range 0 through 255
						 *
						 *   IPv6-addr      = IPv6-full / IPv6-comp / IPv6v4-full / IPv6v4-comp
						 *
						 *   IPv6-hex       = 1*4HEXDIG
						 *
						 *   IPv6-full      = IPv6-hex 7(":" IPv6-hex)
						 *
						 *   IPv6-comp      = [IPv6-hex *5(":" IPv6-hex)] "::"
						 *                  [IPv6-hex *5(":" IPv6-hex)]
						 *                  ; The "::" represents at least 2 16-bit groups of
						 *                  ; zeros.  No more than 6 groups in addition to the
						 *                  ; "::" may be present.
						 *
						 *   IPv6v4-full    = IPv6-hex 5(":" IPv6-hex) ":" IPv4-address-literal
						 *
						 *   IPv6v4-comp    = [IPv6-hex *3(":" IPv6-hex)] "::"
						 *                  [IPv6-hex *3(":" IPv6-hex) ":"]
						 *                  IPv4-address-literal
						 *                  ; The "::" represents at least 2 16-bit groups of
						 *                  ; zeros.  No more than 4 groups in addition to the
						 *                  ; "::" and IPv4-address-literal may be present.
						 *
						 * is_email() author's note: We can't use ip2long() to validate
						 * IPv4 addresses because it accepts abbreviated addresses
						 * (xxx.xxx.xxx), expanding the last group to complete the address.
						 * filter_var() validates IPv6 address inconsistently (up to PHP 5.3.3
						 * at least) -- see https://bugs.php.net/bug.php?id=53236 for example
						 *
						 * FLFL: Note, maybe there are tools to validate IPv4 and IPv6
						 *       addresses in Foundation, but I don’t know them, so
						 *       let’s do what the original author did. */
						var maxGroups = 8
						var index: String.Index?
						var addressLiteral = parseData[componentLiteral]!
						
						/* FLFL: I’m not so sure about the validity of the algorithm
						 *       to parse the IPs. Nevertheless, I copied it from the
						 *       original implementation (which seems to work; it is
						 *       much tested) and tried doing exactly the same thing.
						 *       It will always be time to change things later if we
						 *       have issues. */
						/* Extract IPv4 part from the end of the address-literal (if there is one) */
						let regex = try! NSRegularExpression(pattern: #"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#, options: [])
						let matchesIP = regex.matches(in: addressLiteral, options: [], range: NSRange(location: 0, length: (addressLiteral as NSString).length))
						if let matchIP = matchesIP.first {
							let matched = (addressLiteral as NSString).substring(with: matchIP.range)
							let i = addressLiteral.range(of: matched, options: String.CompareOptions.backwards)!.lowerBound
							if i != addressLiteral.startIndex {
								addressLiteral = addressLiteral[..<i] + "0:0" /* Convert IPv4 part to IPv6 format for further testing */
							}
							index = i
						}
						
						if index == addressLiteral.startIndex {
							/* Nothing there except a valid IPv4 address, so... */
							returnStatus.append(.rfc5321Addressliteral)
						} else if !addressLiteral.hasPrefix(stringIPv6Tag) {
							returnStatus.append(.rfc5322Domainliteral)
						} else {
							let ipv6 = addressLiteral[addressLiteral.index(addressLiteral.startIndex, offsetBy: 5)...]
							let matchesIP = ipv6.split(separator: charColon, omittingEmptySubsequences: false).map(String.init) /* Revision 2.7: Daniel Marschall's new IPv6 testing strategy */
							let groupCount = matchesIP.count
							index = ipv6.range(of: stringDoubleColon)?.lowerBound
							
							if let index = index {
								if index != ipv6.range(of: stringDoubleColon, options: String.CompareOptions.backwards)?.lowerBound {
									returnStatus.append(.rfc5322Ipv62X2Xcolon)
								} else {
									if index == ipv6.startIndex || index == ipv6.index(ipv6.endIndex, offsetBy: -2) {
										maxGroups += 1 /* RFC 4291 allows :: at the start or end of an address with 7 other groups in addition */
									}
									
									if groupCount > maxGroups {
										returnStatus.append(.rfc5322Ipv6Maxgrps)
									} else if groupCount == maxGroups {
										returnStatus.append(.rfc5321Ipv6Deprecated) /* Eliding a single "::" */
									}
								}
							} else {
								/* We need exactly the right number of groups */
								if groupCount != maxGroups {
									returnStatus.append(.rfc5322Ipv6Grpcount)
								}
							}
							
							/* Revision 2.7: Daniel Marschall's new IPv6 testing strategy */
							let index0 = ipv6.startIndex
							let index1 = ipv6.index(index0, offsetBy: 1, limitedBy: ipv6.endIndex) ?? ipv6.endIndex
							let index2 = ipv6.index(index0, offsetBy: 2, limitedBy: ipv6.endIndex) ?? ipv6.endIndex
							let indexN0 = ipv6.endIndex
							let indexN1 = ipv6.index(indexN0, offsetBy: -1, limitedBy: ipv6.startIndex) ?? ipv6.startIndex
							let indexN2 = ipv6.index(indexN0, offsetBy: -2, limitedBy: ipv6.startIndex) ?? ipv6.startIndex
							let regex = try! NSRegularExpression(pattern: "^[0-9A-Fa-f]{0,4}$", options: [])
							if ipv6[index0..<index1] == String(charColon) && ipv6[index1..<index2] != String(charColon) {
								returnStatus.append(.rfc5322Ipv6Colonstrt) /* Address starts with a single colon */
							} else if ipv6[indexN1..<indexN0] == String(charColon) && ipv6[indexN2..<indexN1] != String(charColon) {
								returnStatus.append(.rfc5322Ipv6Colonend) /* Address ends with a single colon */
							} else if matchesIP.first(where: { regex.numberOfMatches(in: $0, options: [], range: NSRange(location: 0, length: ($0 as NSString).length)) == 0 }) != nil {
								/* FLFL: We have one element in returnStatus that do **not** match the regex. */
								returnStatus.append(.rfc5322Ipv6Badchar) /* Check for unmatched characters */
							} else {
								returnStatus.append(.rfc5321Addressliteral)
							}
						}
					} else {
						returnStatus.append(.rfc5322Domainliteral)
					}
					
					parseData[componentDomain, default: ""] += token
					atomList[componentDomain, default: [:]][elementCount, default: ""] += token
					elementLen += 1
					contextPrior = context
					context = contextStack.removeLast()
					
				case stringBackslash:
					returnStatus.append(.rfc5322DomlitObsdtext)
					contextStack.append(context)
					context = contextQuotedpair
					
				/* Folding White Space */
				case stringCR:
					i = email.index(after: i)
					guard i < email.endIndex && String(email[i]) == stringLF else {
						returnStatus.append(.errCrNoLf) /* Fatal error */
						break
					}
					fallthrough

				case stringCRLF: fallthrough /* This case is not possible in PHP, but in Swift, because grapheme clusters, it is. */
				case stringSpace: fallthrough
				case stringHTab:
					returnStatus.append(.cfwsFws)
					
					contextStack.append(context)
					context = contextFws
					tokenPrior = token
					
				/* DText */
				default:
					/* https://tools.ietf.org/html/rfc5322#section-3.4.1
					 *   dtext           =   %d33-90 /          ; Printable US-ASCII
					 *                       %d94-126 /         ;  characters not including
					 *                       obs-dtext          ;  "[", "]", or "\"
					 *
					 *   obs-dtext       =   obs-NO-WS-CTL / quoted-pair
					 *
					 *   obs-NO-WS-CTL   =   %d1-8 /            ; US-ASCII control
					 *                       %d11 /             ;  characters that do not
					 *                       %d12 /             ;  include the carriage
					 *                       %d14-31 /          ;  return, line feed, and
					 *                       %d127              ;  white space characters */
					let scalar = token.first!.unicodeScalars.first!
					let ord = scalar.value
					
					/* CR, LF, SP & HTAB have already been parsed above */
					if ord > 127 || ord == 0 || token == stringOpenSquareBracket {
						returnStatus.append(.errExpectingDtext) /* Fatal error */
						break
					} else if ord < 33 || ord == 127 {
						returnStatus.append(.rfc5322DomlitObsdtext)
					}
					
					parseData[componentLiteral, default: ""] += token
					parseData[componentDomain, default: ""] += token
					atomList[componentDomain, default: [:]][elementCount, default: ""] += token
					elementLen += 1
				}
				
			/* *************
			   Quoted String
			   ************* */
			case contextQuotedstring:
				/* https://tools.ietf.org/html/rfc5322#section-3.2.4
				 *   quoted-string   =   [CFWS]
				 *                       DQUOTE *([FWS] qcontent) [FWS] DQUOTE
				 *                       [CFWS]
				 *
				 *   qcontent        =   qtext / quoted-pair */
				switch token {
				/* Quoted pair */
				case stringBackslash:
					contextStack.append(context)
					context = contextQuotedpair
					
				/* Folding White Space
				 * Inside a quoted string, spaces are allowed as regular characters.
				 * It's only FWS if we include HTAB or CRLF */
				case stringCR:
					i = email.index(after: i)
					guard i < email.endIndex && String(email[i]) == stringLF else {
						returnStatus.append(.errCrNoLf) /* Fatal error */
						break
					}
					fallthrough
					
				case stringCRLF: fallthrough /* This case is not possible in PHP, but in Swift, because grapheme clusters, it is. */
				case stringHTab:
					/* https://tools.ietf.org/html/rfc5322#section-3.2.2
					 *   Runs of FWS, comment, or CFWS that occur between lexical tokens in a
					 *   structured header field are semantically interpreted as a single
					 *   space character. */
					
					/* https://tools.ietf.org/html/rfc5322#section-3.2.4
					 *   the CRLF in any FWS/CFWS that appears within the quoted-string [is]
					 *   semantically "invisible" and therefore not part of the quoted-string */
					parseData[componentLocalpart, default: ""] += stringSpace
					atomList[componentLocalpart, default: [:]][elementCount, default: ""] += stringSpace
					elementLen += 1
					
					returnStatus.append(.cfwsFws)
					contextStack.append(context)
					context = contextFws
					tokenPrior = token
					
				/* End of quoted string */
				case stringDQuote:
					parseData[componentLocalpart, default: ""] += token
					atomList[componentLocalpart, default: [:]][elementCount, default: ""] += token
					elementLen += 1
					contextPrior = context
					context = contextStack.removeLast()
					
				/* QText */
				default:
					/* https://tools.ietf.org/html/rfc5322#section-3.2.4
					 *   qtext           =   %d33 /             ; Printable US-ASCII
					 *                       %d35-91 /          ;  characters not including
					 *                       %d93-126 /         ;  "\" or the quote character
					 *                       obs-qtext
					 *
					 *   obs-qtext       =   obs-NO-WS-CTL
					 *
					 *   obs-NO-WS-CTL   =   %d1-8 /            ; US-ASCII control
					 *                       %d11 /             ;  characters that do not
					 *                       %d12 /             ;  include the carriage
					 *                       %d14-31 /          ;  return, line feed, and
					 *                       %d127              ;  white space characters */
					let scalar = token.first!.unicodeScalars.first!
					let ord = scalar.value
					
					if ord > 127 || ord == 0 || ord == 10 {
						returnStatus.append(.errExpectingQtext) /* Fatal error */
					} else if ord < 32 || ord == 127 {
						returnStatus.append(.deprecQtext)
					}
					
					parseData[componentLocalpart, default: ""] += token
					atomList[componentLocalpart, default: [:]][elementCount, default: ""] += token
					elementLen += 1
				}
				
				/* https://tools.ietf.org/html/rfc5322#section-3.4.1
				 *   If the
				 *   string can be represented as a dot-atom (that is, it contains no
				 *   characters other than atext characters or "." surrounded by atext
				 *   characters), then the dot-atom form SHOULD be used and the quoted-
				 *   string form SHOULD NOT be used. */
				/* TODO: The case described in the comment above… */
				
			/* ***********
			   Quoted Pair
			   *********** */
			case contextQuotedpair:
				/* https://tools.ietf.org/html/rfc5322#section-3.2.1
				 *   quoted-pair     =   ("\" (VCHAR / WSP)) / obs-qp
				 *
				 *   VCHAR           =  %d33-126            ; visible (printing) characters
				 *   WSP             =  SP / HTAB           ; white space
				 *
				 *   obs-qp          =   "\" (%d0 / obs-NO-WS-CTL / LF / CR)
				 *
				 *   obs-NO-WS-CTL   =   %d1-8 /            ; US-ASCII control
				 *                       %d11 /             ;  characters that do not
				 *                       %d12 /             ;  include the carriage
				 *                       %d14-31 /          ;  return, line feed, and
				 *                       %d127              ;  white space characters
				 *
				 * i.e. obs-qp       =  "\" (%d0-8, %d10-31 / %d127) */
				let scalar = token.first!.unicodeScalars.first!
				let ord = scalar.value

				if	ord > 127 {
					returnStatus.append(.errExpectingQpair) /* Fatal error */
				} else if (ord < 31 && ord != 9) || (ord == 127) /* SP & HTAB are allowed */ {
					returnStatus.append(.deprecQp)
				}
				
				/* At this point we know where this qpair occurred so
				 * we could check to see if the character actually
				 * needed to be quoted at all.
				 * https://tools.ietf.org/html/rfc5321#section-4.1.2
				 *   the sending system SHOULD transmit the
				 *   form that uses the minimum quoting possible.
				 * To do: check whether the character needs to be quoted (escaped) in this context */
				contextPrior = context
				context = contextStack.removeLast() /* End of qpair */
				token = stringBackslash + token
				
				switch context {
				case contextComment: (/*nop*/)
				case contextQuotedstring:
					parseData[componentLocalpart, default: ""] += token
					atomList[componentLocalpart, default: [:]][elementCount, default: ""] += token
					elementLen += 2 /* The maximum sizes specified by RFC 5321 are octet counts, so we must include the backslash */
				case componentLiteral:
					parseData[componentDomain, default: ""] += token
					atomList[componentDomain, default: [:]][elementCount, default: ""] += token
					elementLen += 2 /* The maximum sizes specified by RFC 5321 are octet counts, so we must include the backslash */
				default:
					fatalError("Quoted pair logic invoked in an invalid context: \(context)")
				}
				
			/* *******
			   Comment
			   ******* */
			case contextComment:
				/* https://tools.ietf.org/html/rfc5322#section-3.2.2
				 *   comment         =   "(" *([FWS] ccontent) [FWS] ")"
				 *
				 *   ccontent        =   ctext / quoted-pair / comment */
				switch token {
				/* Nested comment */
				case stringOpenParenthesis:
					/* Nested comments are OK */
					contextStack.append(context)
					context = contextComment
					
				/* End of comment */
				case stringCloseParenthesis:
					contextPrior = context
					context = contextStack.removeLast()
					
					/* https://tools.ietf.org/html/rfc5322#section-3.2.2
					 *   Runs of FWS, comment, or CFWS that occur between lexical tokens in a
					 *   structured header field are semantically interpreted as a single
					 *   space character.
					 *
					 * is_email() author's note: This *cannot* mean that we must add a
					 * space to the address wherever CFWS appears. This would result in
					 * any addr-spec that had CFWS outside a quoted string being invalid
					 * for RFC 5321.
					 * 			if context == componentLocalpart || context == componentDomain {
					 * 				parseData[context, default: ""] += stringSpace
					 * 				atomList[context, default: [:]][elementCount, default: ""] += stringSpace
					 * 				elementLen += 1
					 * 			} */
					
				/* Quoted pair */
				case stringBackslash:
					contextStack.append(context)
					context = contextQuotedpair
					
				/* Folding White Space */
				case stringCR:
					i = email.index(after: i)
					guard i < email.endIndex && String(email[i]) == stringLF else {
						returnStatus.append(.errCrNoLf) /* Fatal error */
						break
					}
					fallthrough
					
				case stringCRLF: fallthrough /* This case is not possible in PHP, but in Swift, because grapheme clusters, it is. */
				case stringSpace: fallthrough
				case stringHTab:
					returnStatus.append(.cfwsFws)
					
					contextStack.append(context)
					context = contextFws
					tokenPrior = token
					
				/* CText */
				default:
					/* https://tools.ietf.org/html/rfc5322#section-3.2.3
					 *   ctext           =   %d33-39 /          ; Printable US-ASCII
					 *                       %d42-91 /          ;  characters not including
					 *                       %d93-126 /         ;  "(", ")", or "\"
					 *                       obs-ctext
					 *
					 *   obs-ctext       =   obs-NO-WS-CTL
					 *
					 *   obs-NO-WS-CTL   =   %d1-8 /            ; US-ASCII control
					 *                       %d11 /             ;  characters that do not
					 *                       %d12 /             ;  include the carriage
					 *                       %d14-31 /          ;  return, line feed, and
					 *                       %d127              ;  white space characters */
					let scalar = token.first!.unicodeScalars.first!
					let ord = scalar.value
					
					if ord > 127 || ord == 0 || ord == 10 {
						returnStatus.append(.errExpectingCtext) /* Fatal error */
						break
					} else if ord < 32 || ord == 127 {
						returnStatus.append(.deprecCtext)
					}
				}
				
			/* *******************
			   Folding White Space
			   ******************* */
			case contextFws:
				/* https://tools.ietf.org/html/rfc5322#section-3.2.2
				 *   FWS             =   ([*WSP CRLF] 1*WSP) /  obs-FWS
				 *                                          ; Folding white space */
				
				/* But note the erratum:
				 * https://www.rfc-editor.org/errata_search.php?rfc=5322&eid=1908:
				 *   In the obsolete syntax, any amount of folding white space MAY be
				 *   inserted where the obs-FWS rule is allowed.  This creates the
				 *   possibility of having two consecutive "folds" in a line, and
				 *   therefore the possibility that a line which makes up a folded header
				 *   field could be composed entirely of white space.
				 *
				 *   obs-FWS         =   1*([CRLF] WSP) */
				if tokenPrior == stringCR || tokenPrior == stringCRLF {
					if token == stringCR || token == stringCRLF {
						returnStatus.append(.errFwsCrlfX2) /* Fatal error */
						break
					}
					
					if let c = crlfCount {
						if c > 0 {
							returnStatus.append(.deprecFws) /* Multiple folds = obsolete FWS */
						}
						crlfCount = c + 1
					} else {
						crlfCount = 1
					}
				}
				
				switch token {
				case stringCR:
					i = email.index(after: i)
					guard i < email.endIndex && String(email[i]) == stringLF else {
						returnStatus.append(.errCrNoLf) /* Fatal error */
						break
					}
					fallthrough
					
				case stringCRLF: fallthrough /* This case is not possible in PHP, but in Swift, because grapheme clusters, it is. */
				case stringSpace: fallthrough
				case stringHTab: (/*nop*/)
				default:
					guard tokenPrior != stringCR && tokenPrior != stringCRLF else {
						returnStatus.append(.errFwsCrlfEnd) /* Fatal error */
						break
					}
					
					crlfCount = nil
					
					contextPrior = context
					context = contextStack.removeLast() /* End of FWS */
					
					/* https://tools.ietf.org/html/rfc5322#section-3.2.2
					 *   Runs of FWS, comment, or CFWS that occur between lexical tokens in a
					 *   structured header field are semantically interpreted as a single
					 *   space character.
					 *
					 * is_email() author's note: This *cannot* mean that we must add a
					 * space to the address wherever CFWS appears. This would result in
					 * any addr-spec that had CFWS outside a quoted string being invalid
					 * for RFC 5321.
					 * 			if context == componentLocalpart || context == componentDomain {
					 * 				parseData[context, default: ""] += stringSpace
					 * 				atomList[context, default: [:]][elementCount, default: ""] += stringSpace
					 * 				elementLen += 1
					 * 			} */
					
					i = email.index(before: i) /* Look at this token again in the parent context */
				}
				
				tokenPrior = token
				
			/* *****************************
			   A context we aren't expecting
			   ***************************** */
			default:
				fatalError("Unknown context: \(context)")
			}
			
			/* FLFL: Is the bang on the line below valid? */
			guard returnStatus.max(by: { $0.value < $1.value })!.value <= ValidationCategory.rfc5322.value else {
				break /* No point going on if we've got a fatal error */
			}
		}
		
		/* FLFL: Is the bang on the line below valid? */
		if returnStatus.max(by: { $0.value < $1.value })!.value < ValidationCategory.rfc5322.value {
			if      context == contextQuotedstring                  {returnStatus.append(.errUnclosedquotedstr) /* Fatal error */}
			else if context == contextQuotedpair                    {returnStatus.append(.errBackslashend) /* Fatal error */}
			else if context == contextComment                       {returnStatus.append(.errUnclosedcomment) /* Fatal error */}
			else if context == componentLiteral                     {returnStatus.append(.errUncloseddomlit) /* Fatal error */}
			else if token   == stringCR || token == stringCRLF      {returnStatus.append(.errFwsCrlfEnd) /* Fatal error */}
			else if parseData[componentDomain, default: ""].isEmpty {returnStatus.append(.errNodomain) /* Fatal error */}
			else if elementLen == 0                                 {returnStatus.append(.errDotEnd) /* Fatal error */}
			else if hyphenFlag                                      {returnStatus.append(.errDomainhyphenend) /* Fatal error */}
			/* https://tools.ietf.org/html/rfc5321#section-4.5.3.1.2
			 *   The maximum total length of a domain name or number is 255 octets. */
			else if parseData[componentDomain, default: ""].count > 255 {returnStatus.append(.rfc5322DomainToolong)}
			/* https://tools.ietf.org/html/rfc5321#section-4.1.2
			 *   Forward-path   = Path
			 *
			 *   Path           = "<" [ A-d-l ":" ] Mailbox ">"
			 *
			 * https://tools.ietf.org/html/rfc5321#section-4.5.3.1.3
			 *   The maximum total length of a reverse-path or forward-path is 256
			 *   octets (including the punctuation and element separators).
			 *
			 * Thus, even without (obsolete) routing information, the Mailbox can
			 * only be 254 characters long. This is confirmed by this verified
			 * erratum to RFC 3696:
			 *
			 * https://www.rfc-editor.org/errata_search.php?rfc=3696&eid=1690
			 *   However, there is a restriction in RFC 2821 on the length of an
			 *   address in MAIL and RCPT commands of 254 characters.  Since addresses
			 *   that do not fit in those fields are not normally useful, the upper
			 *   limit on address lengths should normally be considered to be 254. */
			else if (parseData[componentLocalpart, default: ""] + stringAt + parseData[componentDomain, default: ""]).count > 254 {returnStatus.append(.rfc5322Toolong)}
			/* https://tools.ietf.org/html/rfc1035#section-2.3.4
			 * labels          63 octets or less */
			else if elementLen > 63 {returnStatus.append(.rfc5322LabelToolong)}
		}
		
		let dnsChecked = false
		/* FLFL: Is the bang on the line below valid? */
		if checkDNS && returnStatus.max(by: { $0.value < $1.value })!.value < ValidationCategory.dnswarn.value/* && function_exists('dns_get_record'))*/ {
			/* https://tools.ietf.org/html/rfc5321#section-2.3.5
			 *   Names that can
			 *   be resolved to MX RRs or address (i.e., A or AAAA) RRs (as discussed
			 *   in Section 5) are permitted, as are CNAME RRs whose targets can be
			 *   resolved, in turn, to MX or address RRs.
			 *
			 * https://tools.ietf.org/html/rfc5321#section-5.1
			 *   The lookup first attempts to locate an MX record associated with the
			 *   name.  If a CNAME record is found, the resulting name is processed as
			 *   if it were the initial name. ... If an empty list of MXs is returned,
			 *   the address is treated as if it was associated with an implicit MX
			 *   RR, with a preference of 0, pointing to that host.
			 *
			 * is_email() author's note: We will regard the existence of a CNAME to be
			 * sufficient evidence of the domain's existence. For performance reasons
			 * we will not repeat the DNS lookup for the CNAME's target, but we will
			 * raise a warning because we didn't immediately find an MX record. */
			
			/* FLFL: I don’t think it’s sane to do DNS check in a sync func. Probably won’t do.
			 *       Below is original php code for checking DNS. */
			/* if ($element_count === 0) $parsedata[ISEMAIL_COMPONENT_DOMAIN] .= '.'; /* Checking TLD DNS seems to work only if you explicitly check from the root */
			
			$result = @dns_get_record($parsedata[ISEMAIL_COMPONENT_DOMAIN], DNS_MX); /* Not using checkdnsrr because of a suspected bug in PHP 5.3 (https://bugs.php.net/bug.php?id=51844) */
			
			if ((is_bool($result) && !(bool) $result))
			$return_status[] = ISEMAIL_DNSWARN_NO_RECORD; // Domain can't be found in DNS
			else {
				if (count($result) === 0) {
					$return_status[] = ISEMAIL_DNSWARN_NO_MX_RECORD; // MX-record for domain can't be found
					$result = @dns_get_record($parsedata[ISEMAIL_COMPONENT_DOMAIN], DNS_A + DNS_CNAME);
					
					if (count($result) === 0)
					$return_status[] = ISEMAIL_DNSWARN_NO_RECORD; // No usable records for the domain can be found
				} else $dns_checked = true;
			}*/
		}
		
		/* Check for TLD addresses
		 * -----------------------
		 * TLD addresses are specifically allowed in RFC 5321 but they are
		 * unusual to say the least. We will allocate a separate
		 * status to these addresses on the basis that they are more likely
		 * to be typos than genuine addresses (unless we've already
		 * established that the domain does have an MX record)
		 *
		 * https://tools.ietf.org/html/rfc5321#section-2.3.5
		 *   In the case
		 *   of a top-level domain used by itself in an email address, a single
		 *   string is used without any dots.  This makes the requirement,
		 *   described in more detail below, that only fully-qualified domain
		 *   names appear in SMTP transactions on the public Internet,
		 *   particularly important where top-level domains are involved.
		 *
		 * TLD format
		 * ----------
		 * The format of TLDs has changed a number of times. The standards
		 * used by IANA have been largely ignored by ICANN, leading to
		 * confusion over the standards being followed. These are not defined
		 * anywhere, except as a general component of a DNS host name (a label).
		 * However, this could potentially lead to 123.123.123.123 being a
		 * valid DNS name (rather than an IP address) and thereby creating
		 * an ambiguity. The most authoritative statement on TLD formats that
		 * the author can find is in a (rejected!) erratum to RFC 1123
		 * submitted by John Klensin, the author of RFC 5321:
		 *
		 * https://www.rfc-editor.org/errata_search.php?rfc=1123&eid=1353
		 *   However, a valid host name can never have the dotted-decimal
		 *   form #.#.#.#, since this change does not permit the highest-level
		 *   component label to start with a digit even if it is not all-numeric. */
		/* FLFL: Is the bang on the line below valid? */
		if !dnsChecked && returnStatus.max(by: { $0.value < $1.value })!.value < ValidationCategory.dnswarn.value {
			if elementCount == 0 {returnStatus.append(.rfc5321Tld)}
			
			if Int(String(atomList[componentDomain, default: [:]][elementCount, default: ""].first!)) != nil {
				returnStatus.append(.rfc5321Tldnumeric)
			}
		}
		
		let finalStatus = returnStatus.max(by: { $0.value < $1.value })!
		return finalStatus
	}
	
	private static let treshold = 16
	
	/* Email parts */
	private static let componentLocalpart = 0
	private static let componentDomain = 1
	private static let componentLiteral = 2
	private static let contextComment = 3
	private static let contextFws = 4
	private static let contextQuotedstring = 5
	private static let contextQuotedpair = 6
	
	/* Miscellaneous string constants */
	private static let stringAt = "@"
	private static let stringBackslash = "\\"
	private static let stringDot = "."
	private static let stringDQuote = "\""
	private static let stringOpenParenthesis = "("
	private static let stringCloseParenthesis = ")"
	private static let stringOpenSquareBracket = "["
	private static let stringCloseSquareBracket = "]"
	private static let stringHyphen = "-"
	private static let charColon = Character(":")
	private static let stringDoubleColon = "::"
	private static let stringSpace = " "
	private static let stringHTab = "\t"
	private static let stringCR = "\r"
	private static let stringLF = "\n"
	private static let stringCRLF = "\r\n"
	private static let stringIPv6Tag = "IPv6:"
	/* US-ASCII visible characters not valid for atext (https://tools.ietf.org/html/rfc5322#section-3.2.3) */
	private static let stringSpecials = CharacterSet(charactersIn: "()<>[]:;@\\,.\"")
	
}
