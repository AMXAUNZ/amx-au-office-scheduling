PROGRAM_NAME='RmsRapidUpdater'


#INCLUDE 'RmsExtendedApi'


define_variable

// Minimum allowed update interval in ms
constant long MIN_RMS_RAPID_UPDATE_INTERVAL = 200;

constant long DEFAULT_RMS_RAPID_UPDATE_INTERVAL = 1000;

constant long RMS_RAPID_UPDATE_TL = 78345;


/**
 * Control RMS rapid updates.
 *
 * When enabled the RMS client will hit the server for any pending messages at
 * the interval specified, allowing you to make things happen a little quicker
 * that the safety threshold will allow. This should be used with caution.
 *
 * @param	interval	the update interval in milli seconds, 0 to disable
 */
define_function rmsRapidUpdate(long interval) {
	if (timeline_active(RMS_RAPID_UPDATE_TL)) {
		timeline_kill(RMS_RAPID_UPDATE_TL);
	}

	if (interval > 0) {
		stack_var long times[1];

		if (interval < MIN_RMS_RAPID_UPDATE_INTERVAL) {
			interval = MIN_RMS_RAPID_UPDATE_INTERVAL;
		}
		times[1] = interval;

		timeline_create(RMS_RAPID_UPDATE_TL,
				times,
				1,
				TIMELINE_ABSOLUTE,
				TIMELINE_REPEAT);
	}
}

/**
 * Enable / disable RMS rapid updates using a default interval
 */
define_function setRmsRapidUpdateEnabled(char isEnabled) {
	if (isEnabled) {
		rmsRapidUpdate(DEFAULT_RMS_RAPID_UPDATE_INTERVAL);
	} else {
		rmsRapidUpdate(0);
	}
}


define_event

timeline_event[RMS_RAPID_UPDATE_TL] {
	if ([vdvRMS, RMS_CHANNEL_CLIENT_ONLINE]) {
		RmsRetrieveClientMessages();
	}
}
