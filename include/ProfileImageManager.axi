PROGRAM_NAME='ProfileImageManager'


#IF_NOT_DEFINED __PROFILE_IMAGE_MANAGER__
#DEFINE __PROFILE_IMAGE_MANAGER__


#INCLUDE 'String';


// TODO build a Duet modudule so that we can also look up external users with
// a service such as Gravatar and/or LinkedIn


/**
 * Sets a dynamic image resource to the appropriate profile image for a lookup
 * key.
 *
 * @param	tp			the touch panel containing the dynamic image resource
 * @param	resource	the resource name to update
 * @param	lookupKey	the key to utilise for the profile image source
 *						(name, email address, etc)
 */
define_function loadProfileImage(dev tp, char resource[], char key[]) {
	stack_var char fileName[128];
	
	filename = "string_replace(key, ' ', '.'), '.jpg'";

	send_command tp, "'^RMF-', resource, ',%F', fileName";
	send_command tp, "'^RFRP-', resource, ',once'";
}


#END_IF // __PROFILE_IMAGE_MANAGER__