/* Some utils in officectl. Very ad-hoc, should probably never be used anywhere else! */

function show_validation_error(error) {
	/* Get the error element */
	var error_element = document.getElementById("error")
	if (typeof error_element === "undefined" || error_element === null) {return}
	
	if (typeof error !== "string") {error_element.textContent = "Internal error"}
	else                           {error_element.textContent = error}
}

function get_input_value(input_name, show_error_function) {
	/* Note: The show_error_function is not validated to actually be a function,
	 *       nor the input_name to be a string (they should if we wanted to be
	 *       extra thorough; but I don’t…) */
	
	/* Get the input */
	var input = document.getElementById(input_name)
	if (typeof input === "undefined" || input === null) {show_error_function("Internal error: cannot get input named “" + input_name + "”"); return null}
	/* Get the value of the input */
	var value = input.value
	if (typeof value !== "string") {show_error_function("Internal error: cannot get the value of the input named “" + input_name + "”"); return null}
	return value
}

function get_full_user_email_from(unvalidated_email, show_error_function) {
	/* Note: The show_error_function is not validated to actually be a function… */
	if (typeof unvalidated_email !== "string") {show_error_function("Internal error when validating email"); return null}

	/* For empty names we do nothing */
	if (unvalidated_email.length == 0) {show_error_function("Username is mandatory"); return null}
	
	var components = unvalidated_email.split("@")
	if (components.length == 0 || components.length > 2) {show_error_function("This id seems invalid!"); return null}
	
	var userId = components[0].toLowerCase()
	var domain = (components.length >= 2 ? components[1] : "happn.fr")
	/* Validate the domain */
	if (domain == "happn.com") {domain = "happn.fr"}
	if (domain != "happn.fr") {show_error_function("Only @happn.fr and @happn.com addresses are supported for now."); return null}
	/* Validate the username */
	if (userId.match(/[^0-9a-z_.-]/) !== null) {show_error_function("Invalid username"); return null}
	
	return userId + "@" + domain
}
