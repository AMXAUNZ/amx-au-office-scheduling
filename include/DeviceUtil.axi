PROGRAM_NAME='DeviceUtil'

#IF_NOT_DEFINED __DEVICE_UTIL__
#DEFINE __DEVICE_UTIL__


/**
 * Checks if a device is currently online.
 *
 * @param	d		the d:p:s of the device to check
 * @return			a boolean, true if the device is currently online
 */
define_function char isDeviceOnline(dev d) {
	return device_id(d) != 0;
}


#END_IF // __DEVICE_UTIL__
