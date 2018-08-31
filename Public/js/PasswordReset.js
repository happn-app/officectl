function show_validation_error(error) {
	/* Get the error element */
	var error_element = document.getElementById("error")
	if (typeof error_element === "undefined" || error_element === null) {return}
	
	if (typeof error !== "string") {error_element.textContent = "Internal error"}
	else                           {error_element.textContent = error}
}

function get_input_value(input_name, show_error_function) {
	/* Get the input */
	var input = document.getElementById(input_name)
	if (typeof input === "undefined" || input === null) {show_error_function("Internal error: cannot get input named “" + input_name + "”"); return null}
	/* Get the value of the input */
	var value = input.value
	if (typeof value !== "string") {show_error_function("Internal error: cannot get the value of the input named “" + input_name + "”"); return null}
	return value
}

function show_input_errors() {
	var submit_button = document.getElementById("form_submit")
	if (typeof submit_button === "undefined" || submit_button === null) {return}
	
	/* Reset the error message */
	show_validation_error("")
	submit_button.disabled = true /* We enable the button at the end of the validation, when all tests pass */
	
	/* Validate the user id */
	if (get_full_user_email(show_validation_error) == null) {return}
	
	/* Get the passwords fields values */
	var old_password = get_input_value("form_input_old_pass", show_validation_error)
	if (old_password == null) {return}
	
	var new_password = get_input_value("form_input_new_pass", show_validation_error)
	if (new_password == null) {return}
	
	var new_password2 = get_input_value("form_input_new_pass2", show_validation_error)
	if (new_password2 == null) {return}
	
	/* Validate the passwords fields */
	if (new_password != new_password2) {show_validation_error("New password and verification must match"); return}
	
	submit_button.disabled = false
}

function get_full_user_email(show_error_function) {
	var nameValue = get_input_value("form_input_user_id", show_error_function)
	if (nameValue == null) {return null}
	
	/* For empty names we do nothing */
	if (nameValue.length == 0) {show_error_function("Username is mandatory"); return null}
	
	var components = nameValue.split("@")
	if (components.length > 2) {show_error_function("This id seems invalid!"); return null}
	
	var userId = components[0].toLowerCase()
	var domain = (components.length >= 2 ? components[1] : "happn.fr")
	/* Validate the domain */
	if (domain == "happn.com") {domain = "happn.fr"}
	if (domain != "happn.fr") {show_error_function("Only @happn.fr and @happn.com addresses are supported for now."); return null}
	/* Validate the username */
	if (userId.match(/[^0-9a-z_.-]/) !== null) {show_error_function("Invalid username"); return null}
	
	return userId + "@" + domain
}

function form_action(form) {
	var email = get_full_user_email(show_validation_error)
	if (email == null) {return false}
	
	var old_password = get_input_value("form_input_old_pass", show_validation_error)
	if (old_password == null) {return false}
	
	var new_password = get_input_value("form_input_new_pass", show_validation_error)
	if (new_password == null) {return false}
	
	var form = document.getElementById("form")
	if (typeof form === "undefined" || form === null) {show_validation_error("Internal error: cannot get the form element"); return false}
	
	form.action = "/password-reset/" + email
	form.method = "post"
	
	return true
}
