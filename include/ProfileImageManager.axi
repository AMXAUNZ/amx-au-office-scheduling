PROGRAM_NAME='ProfileImageManager'


#IF_NOT_DEFINED __PROFILE_IMAGE_MANAGER__
#DEFINE __PROFILE_IMAGE_MANAGER__


#INCLUDE 'String';


// TODO build a Duet modudule that can do an MD5 hash of the email before
// sending to external services as well as profile image lookup in AD if
// appropriate.


/**
 * Sets a dynamic image resource to the appropriate profile image for a lookup
 * key.
 *
 * @param	tp			the touch panel containing the dynamic image resource
 * @param	resource	the resource name to update
 * @param	lookupKey	the key to utilise for the profile image source
 *						(name, email address, etc)
 */
define_function setProfileImage(dev tp, char resource[], char key[]) {
	stack_var char email[255];
	
	if (isEmailAddress(key)) {
		email = key;
	} else {
		email = "string_replace(key, ' ', '.'), '@amxaustralia.com.au'";
	}
	
	setProfileImageFromEmail(tp, resource, email);
}

define_function setProfileImageFromEmail(dev tp, char resource[], char email[]) {
	send_command tp, "'^RMF-', resource, ',%P0%Havatars.io%Aemail%F', lower_string(trim(email))";
}

define_function char isEmailAddress(char str[]) {
	// This is super, super hacky (it's only temporary though...)
	return find_string(str, '@', 2);
}



#END_IF // __PROFILE_IMAGE_MANAGER__