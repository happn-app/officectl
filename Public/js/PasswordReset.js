/* Copied in CertificateRenewal basically. */

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
	
	return get_full_user_email_from(nameValue, show_error_function)
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
