PROGRAM_NAME='ProfileImageManager'


#IF_NOT_DEFINED __PROFILE_IMAGE_MANAGER__
#DEFINE __PROFILE_IMAGE_MANAGER__


#INCLUDE 'String';


// TODO build a Duet module to handle all this, map to external services as
// as required, and generally be less hacky. The setup below is a little
// primative.

define_variable

constant integer PROFILE_IMAGE_SIZE = 45;


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
	stack_var char address[128];
	stack_var char prefix[64];

	// This is really, really nasty bad and horrible email address matching. If
	// you're using this you may want to do something a little nicer here.
	// Basically if this is an email address we'll leave it as it is, otherwise,
	// we'll (poorly) assume that this is an AMX'er. This *really* needs to be
	// neatend up when we have time.
	if (find_string(key, '@', 1)) {
		address = key;
	} else {
		address = "string_replace(key, ' ', '.'), '@amxaustralia.com.au'";
	}
	
	// Because we're sharing the MD5 util we need to prefix we something so that
	// we can parse out the responses for this instance in the response.
	prefix = "itoa(dvTp.number), '::', resource";
 
	send_command vdvMd5Util, "'md5-', prefix, ',', address";
}


define_event

data_event[vdvMd5Util] {
	
	string: {
		stack_var char id[64];
		stack_var integer device;
		
		id = string_get_key(data.text, ',');
		device = atoi(string_get_key(id, '::'))
		
		if (dvTp.number == device) {
			stack_var char resource[64];
			stack_var char md5[32];
		
			resource = string_get_value(id, '::');
			md5 = string_get_value(data.text, ',');
			
			// Load up a Gravatar into the appropriate image slot
			send_command dvTp, "'^RMF-', resource, ',%F', md5, '?s=', itoa(PROFILE_IMAGE_SIZE), '&d=identicon'";
			send_command dvTp, "'^RFRP-', resource, ',once'";
		}
	}
	
}


#END_IF // __PROFILE_IMAGE_MANAGER__