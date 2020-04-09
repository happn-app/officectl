function show_input_errors() {
	var submit_button = document.getElementById("login_form_submit")
	if (typeof submit_button === "undefined" || submit_button === null) {return}
	
	/* Reset the error message */
	show_validation_error("")
	submit_button.disabled = true /* We enable the button at the end of the validation, when all tests pass */
	
	/* Validate the user id */
	if (get_full_user_email(show_validation_error) == null) {return}
	
	/* Get the password field value */
	var password = get_input_value("login_form_input_pass", show_validation_error)
	if (password == null) {return}
	
	submit_button.disabled = false
}

function get_full_user_email(show_error_function) {
	var nameValue = get_input_value("login_form_input_user_id", show_error_function)
	if (nameValue == null) {return null}
	/* Get the cleaned email input element */
	var inputClean = document.getElementById("login_form_input_user_id_clean")
	if (typeof inputClean === "undefined" || inputClean === null) {show_error_function("Internal error: cannot get input named “login_form_input_user_id_clean”"); return null}
	
	emailClean = get_full_user_email_from(nameValue, show_error_function)
	if (emailClean === null) {return null} /* The error should already have been shown. */
	inputClean.value = emailClean
	
	return emailClean
}

function login_form_action(form, action_path) {
	var email = get_full_user_email(show_validation_error)
	if (email == null) {return false}
	
	var password = get_input_value("login_form_input_pass", show_validation_error)
	if (password == null) {return false}
	
	var form = document.getElementById("form")
	if (typeof form === "undefined" || form === null) {show_validation_error("Internal error: cannot get the form element"); return false}
	
	form.action = action_path
	form.method = "post"
	
	return true
}
