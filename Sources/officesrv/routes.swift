import Vapor



/** Register the application’s routes here. */
public func routes(_ router: Router) throws {
	/* Basic "Hello, world!" example */
	router.get("hello") { req in
		return "Hello, world!"
	}
	
//	let resetPassPath: [PathComponent] = [.constant("reset-password"), .parameter("userId")]
//	router.get(resetPassPath, use: <#T##(Request) throws -> ResponseEncodable#>)
//	// Example of configuring a controller
//	let todoController = TodoController()
//	router.get("todos", use: todoController.index)
//	router.post("todos", use: todoController.create)
//	router.delete("todos", Todo.parameter, use: todoController.delete)
}
