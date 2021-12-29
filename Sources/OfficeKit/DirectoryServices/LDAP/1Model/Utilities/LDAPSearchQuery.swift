/*
 * LDAPSearchQuery.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/09/05.
 */

import Foundation



/* https://tools.ietf.org/html/rfc4515#section-3 */
public indirect enum LDAPSearchQuery {
	
	public enum FilterType : String {
		
		case equal          =  "="
		case approx         = "~="
		case greaterOrEqual = ">="
		case lessOrEqual    = "<="
		
	}
	
	case present(attribute: LDAPAttributeDescription)
	case simple(attribute: LDAPAttributeDescription, filtertype: FilterType, value: Data)
	case substring(attribute: LDAPAttributeDescription, prefix: Data?, middleData: [Data], suffix: Data?) /* Basically gives: “"attribute" "=" "prefix" "*" middleData.map{ "$0*" } "suffix"” */
	case extensibleWithAttribute(attribute: LDAPAttributeDescription, dnAttribute: Bool, matchingRule: LDAPObjectID?, value: Data)
	case extensibleWithoutAttribute(dnAttribute: Bool, matchingRule: LDAPObjectID, value: Data)
	
	case and([LDAPSearchQuery])
	case or([LDAPSearchQuery])
	case not(LDAPSearchQuery)
	
	var stringValue: String {
		let ret: String
		switch self {
			case .present(attribute: let attribute):
				ret = attribute.stringValue + "=*"
				
			case .simple(attribute: let attribute, filtertype: let filter, value: let value):
				ret = attribute.stringValue + filter.rawValue + dataToStr(value)
				
			case .substring(attribute: let attribute, prefix: let prefix, middleData: let middle, suffix: let suffix):
				ret = attribute.stringValue + "=" + dataToStr(prefix) + "*" + middle.reduce("", { $0 + dataToStr($1) + "*" }) + dataToStr(suffix)
				
			case .extensibleWithAttribute(attribute: let attribute, dnAttribute: let hasDN, matchingRule: let matchingRule, value: let value):
				let matchingRuleString = (matchingRule.flatMap{ ":" + $0.stringValue } ?? "")
				ret = attribute.stringValue + (hasDN ? ":dn" : "") + matchingRuleString + ":=" + dataToStr(value)
				
			case .extensibleWithoutAttribute(dnAttribute: let hasDN, matchingRule: let matchingRule, value: let value):
				ret = (hasDN ? ":dn" : "") + ":" + matchingRule.stringValue + ":=" + dataToStr(value)
				
			case .and(let subsearches):
				ret = "&" + subsearches.reduce("", { $0 + $1.stringValue })
				
			case .or(let subsearches):
				ret = "|" + subsearches.reduce("", { $0 + $1.stringValue })
				
			case .not(let subsearch):
				ret = "!" + subsearch.stringValue
		}
		return "(" + ret + ")"
	}
	
	private func dataToStr(_ data: Data?) -> String {
		guard let data = data else {return ""}
		/* RFC says that any UTFMB (UTF2, UTF3 & UTF4) chat can be left unescaped in the resulting string, and almost all UTF1
		 * (exactly UTF1 minus NULL, left and right parenthesis, the asterisk and the backlash).
		 * For simplicity and readability (we would prefer not having non-printable characters in the resulting query),
		 * we’ll escape everything that is not whilelisted in whiteListedChars… */
		return data.reduce("", { $0 + (LDAPSearchQuery.whiteListedChars.contains($1) ? String(Character(UnicodeScalar($1))) : String(format: "\\%02x", $1)) })
	}
	
	private static let whiteListedChars = Set<UInt8>(arrayLiteral:
		0x21 /* ! */, 0x22 /* " */, 0x23 /* # */, 0x24 /* $ */, 0x25 /* % */,
		0x26 /* & */, 0x27 /* ' */, 0x2b /* + */, 0x2c /* , */, 0x2d /* - */,
		0x2e /* . */, 0x2f /* / */, 0x30 /* 0 */, 0x31 /* 1 */, 0x32 /* 2 */,
		0x33 /* 3 */, 0x34 /* 4 */, 0x35 /* 5 */, 0x36 /* 6 */, 0x37 /* 7 */,
		0x38 /* 8 */, 0x39 /* 9 */, 0x3a /* : */, 0x3b /* ; */, 0x3c /* < */,
		0x3d /* = */, 0x3e /* > */, 0x3f /* ? */, 0x40 /* @ */, 0x41 /* A */,
		0x42 /* B */, 0x43 /* C */, 0x44 /* D */, 0x45 /* E */, 0x46 /* F */,
		0x47 /* G */, 0x48 /* H */, 0x49 /* I */, 0x4a /* J */, 0x4b /* K */,
		0x4c /* L */, 0x4d /* M */, 0x4e /* N */, 0x4f /* O */, 0x50 /* P */,
		0x51 /* Q */, 0x52 /* R */, 0x53 /* S */, 0x54 /* T */, 0x55 /* U */,
		0x56 /* V */, 0x57 /* W */, 0x58 /* X */, 0x59 /* Y */, 0x5a /* Z */,
		0x5b /* [ */, 0x5d /* ] */, 0x5e /* ^ */, 0x5f /* _ */, 0x60 /* ` */,
		0x61 /* a */, 0x62 /* b */, 0x63 /* c */, 0x64 /* d */, 0x65 /* e */,
		0x66 /* f */, 0x67 /* g */, 0x68 /* h */, 0x69 /* i */, 0x6a /* j */,
		0x6b /* k */, 0x6c /* l */, 0x6d /* m */, 0x6e /* n */, 0x6f /* o */,
		0x70 /* p */, 0x71 /* q */, 0x72 /* r */, 0x73 /* s */, 0x74 /* t */,
		0x75 /* u */, 0x76 /* v */, 0x77 /* w */, 0x78 /* x */, 0x79 /* y */,
		0x7a /* z */, 0x7b /* { */, 0x7c /* | */, 0x7d /* } */, 0x7e /* ~ */
	)
	
}
