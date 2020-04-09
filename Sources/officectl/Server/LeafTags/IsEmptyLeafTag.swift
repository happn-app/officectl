import Foundation

import Leaf
import Vapor



struct IsEmptyLeafTag : LeafTag {
	
	static let name = "isEmpty"
	
	func render(_ ctx: LeafContext) throws -> LeafData {
		guard let array = ctx.parameters.onlyElement?.array else {
			throw "parameter given to isEmpty leaf tag is not a single array"
		}
		return .bool(array.isEmpty)
	}
	
}
