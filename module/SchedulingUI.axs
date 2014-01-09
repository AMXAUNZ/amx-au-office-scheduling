MODULE_NAME='SchedulingUI' (dev vdvRms, dev dvTp)


#DEFINE INCLUDE_SCHEDULING_CREATE_RESPONSE_CALLBACK
#DEFINE INCLUDE_TP_NFC_TAG_READ_CALLBACK


#INCLUDE 'FuzzyTime';
#INCLUDE 'String';
#INCLUDE 'Unixtime'
#INCLUDE 'RmsAssetLocationTracker';
#INCLUDE 'BookingTracker';
#INCLUDE 'TpApi';
#INCLUDE 'TPEventListener';
#INCLUDE 'RmsApi';
#INCLUDE 'RmsEventListener';
#INCLUDE 'RmsSchedulingApi';
#INCLUDE 'RmsSchedulingEventListener';


define_variable

// System states
constant char STATE_OFFLINE = 1;
constant char STATE_AVAILABLE = 2;
constant char STATE_IN_USE = 3;
constant char STATE_BOOKING_NEAR = 4;
constant char STATE_BOOKING_ENDING = 5;
constant char STATE_BOOKED_BACK_TO_BACK = 6;

// Page names
constant char PAGE_BLANK[] = 'blank';
constant char PAGE_CONNECTED[] = 'connected';
constant char PAGE_CONNECTING[] = 'connecting';
constant char PAGE_AVAILABLE[] = 'available';
constant char PAGE_IN_USE[] = 'inUse';

// Popups
constant char POPUP_CREATE[] = 'create';
constant char POPUP_TODAY[] = 'today';
constant char POPUP_ACTIVE_INFO[] = 'activeInfo';
constant char POPUP_BACK_TO_BACK[] = 'backToBack';
constant char POPUP_BOOK_NEXT[] = 'bookNext';

// Button addresses
constant integer BTN_MEET_NOW = 1;
constant integer BTN_NEXT_INFO = 2;
constant integer BTN_ACTIVE_MEETING_NAME = 3;
constant integer BTN_ACTIVE_MEETING_TIMER = 4;
constant integer BTN_TIME_SELECT[] = {5, 6, 7, 8};
constant integer BTN_ACTIVE_TIMES = 9;
constant integer BTN_BACK_TO_BACK_INFO = 10;
constant integer BTN_AVAILABILITY_WINDOW = 11;
constant integer BTN_BOOK_NEXT = 12;

// UI re-render manager
constant long UI_UPDATE_INTERVAL[] = {15000};
constant long TL_UI_UPDATE = 1;

// Options available for 'meet now' and 'book next' inital meeting lengths
constant integer BOOKING_REQUEST_LENGTHS[] = {10, 20, 30, 60};

volatile integer bookingRequestLength;


/**
 * Initialise module variables that cannot be assisgned at compile time.
 */
define_function init() {
	setLocationTrackerAsset(RmsDevToString(dvTp));
}

/**
 * Gets the current system / room booking state.
 *
 * @returns		an char representing one of the STATE_... constants
 */
define_function char getState() {
	stack_var char state;
	stack_var char isBooked;
	stack_var integer timeUntilNextBooking;
	stack_var integer timeRemaining;
	
	isBooked = isBookedNow();
	timeUntilNextBooking = getMinutesUntilNextBooking();
	timeRemaining = getMinutesUntilBookingEnd();

	select {

		// No connection to the RMS server
		active (![vdvRMS, RMS_CHANNEL_CLIENT_REGISTERED]): {
			state = STATE_OFFLINE;
		}

		// Meeting approaching
		active (!isBooked && timeUntilNextBooking <= 5): {
			state = STATE_BOOKING_NEAR;
		}

		// Room available
		active (!isBooked): {
			state = STATE_AVAILABLE;
		}

		// Room in use
		active (isBooked && timeRemaining > 5): {
			state = STATE_IN_USE;
		}

		// Nearing end of current meeting and there's upcoming availability
		active (isBooked && (timeUntilNextBooking - timeRemaining > 10)): {
			state = STATE_BOOKING_ENDING;
		}

		// Back to back meeting
		active (isBooked): {
			state = STATE_BOOKED_BACK_TO_BACK;
		}

		// Ummmm...
		active (1): {
			state = STATE_OFFLINE;
			amx_log(AMX_ERROR, 'Unexpected system state.');
		}

	}

	return state;
}

/**
 * Request a UI redraw. This should be called by every event that affects our
 * system state;
 */
define_function redraw() {
	// Throttle UI renders to 1000ms
	// Placing this in a wait also enables us to ensure that we have had a
	// chance to handle all relevent events and ensure we don't redraw with
	// partial / incorrect data.
	cancel_wait 'ui update';
	wait 10 'ui update' {
		render(getState());
	}
}

/**
 * Render the appropriate popups and page elements for a passed system state.
 *
 * To trigger an update from other areas of code use redraw().
 */
define_function render(char state) {
	stack_var integer currentId;
	stack_var event current;
	stack_var integer nextId;
	stack_var event next;
	stack_var slong timeOffset;
	
	currentId = getActiveBookingId();
	if (currentId) {
		current = todaysBookings[currentId];
	}
	nextId = getNextBookingId();
	if (nextId) {
		next = todaysBookings[nextId];
	}
	
	// FIXME
	// Current this will render all times local to the master's timezone
	// rather than the touch panel asset.
	timeOffset = unixtime_utc_offset_hr * UNIXTIME_SECONDS_PER_HOUR +
			unixtime_utc_offset_min * UNIXTIME_SECONDS_PER_MINUTE;
	
	switch (state) {

	case STATE_OFFLINE: {
		setPageAnimated(dvTp, PAGE_CONNECTING, 'fade', 0, 20);
		break;
	}

	case STATE_AVAILABLE: {
		stack_var char nextInfoText[512];

		if (nextId) {
			nextInfoText = "'"', next.subject, '" begins in ', fuzzyTimeDelta(next.start), '.'";
		} else {
			nextInfoText = 'No bookings currently scheduled for the rest of the day.';
		}

		setButtonText(dvTp, BTN_NEXT_INFO, nextInfoText);

		setPageAnimated(dvTp, PAGE_AVAILABLE, 'fade', 0, 20);

		break;
	}

	case STATE_IN_USE: {
		setButtonText(dvTp, BTN_ACTIVE_MEETING_NAME, current.subject);
		setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Ends in ', fuzzyTimeDelta(current.end)");
		setButtonText(dvTp, BTN_ACTIVE_TIMES, "fmt_date('g:ia', current.start + timeOffset), ' - ', fmt_date('g:ia', current.end + timeOffset)");

		// TODO set attendees

		showPopupEx(dvTp, POPUP_ACTIVE_INFO, PAGE_IN_USE);

		setPageAnimated(dvTp, PAGE_IN_USE, 'fade', 0, 20);

		break;
	}

	case STATE_BOOKING_NEAR: {
		setButtonText(dvTP, BTN_ACTIVE_MEETING_NAME, next.subject);
		setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Starts in ', fuzzyTimeDelta(next.start)");
		setButtonText(dvTp, BTN_ACTIVE_TIMES, "fmt_date('g:ia', current.start + timeOffset), ' - ', fmt_date('g:ia', current.end + timeOffset)");

		// TODO show attendees

		showPopupEx(dvTp, POPUP_ACTIVE_INFO, PAGE_IN_USE);

		setPageAnimated(dvTp, PAGE_IN_USE, 'fade', 0, 20);

		break;
	}

	case STATE_BOOKING_ENDING: {
		stack_var char availability[512];

		if (nextId) {
			availability = fuzzyTime(current.end, next.start);
		} else {
			availability = 'the rest of the day';
		}

		setButtonText(dvTp, BTN_ACTIVE_MEETING_NAME, current.subject);
		setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Ends in ', fuzzyTimeDelta(current.end)");
		setButtonText(dvTp, BTN_AVAILABILITY_WINDOW, "'The room is available for ', availability, ' following the current meeting.'");

		showPopupEx(dvTp, POPUP_BOOK_NEXT, PAGE_IN_USE);

		setPageAnimated(dvTp, PAGE_IN_USE, 'fade', 0, 20);

		break;
	}

	case STATE_BOOKED_BACK_TO_BACK: {
		setButtonText(dvTp, BTN_ACTIVE_MEETING_NAME, current.subject);
		setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Ends in ', fuzzyTimeDelta(current.end)");
		setButtonText(dvTp, BTN_BACK_TO_BACK_INFO, "'The room is reserved for "', next.subject, '" directly following this.'");

		showPopupEx(dvTp, POPUP_BACK_TO_BACK, PAGE_IN_USE);

		setPageAnimated(dvTp, PAGE_IN_USE, 'fade', 0, 20);

		break;
	}

	default: {
		amx_log(AMX_ERROR, 'Unhandled system state. Could not render UI.');
	}

	}
}

/**
 * Update the meeting length presented for selection based on the available
 * time window.
 */
define_function updateAvailableBookingTimes() {
	stack_var integer timeUntilNextBooking;
	
	timeUntilNextBooking = getMinutesUntilNextBooking();

	setButtonEnabled(dvTp, BTN_TIME_SELECT[1], (timeUntilNextBooking > 10));
	setButtonFaded(dvTp, BTN_TIME_SELECT[1], (timeUntilNextBooking > 10));

	setButtonEnabled(dvTp, BTN_TIME_SELECT[2], (timeUntilNextBooking > 20));
	setButtonFaded(dvTp, BTN_TIME_SELECT[2], (timeUntilNextBooking > 20));

	setButtonEnabled(dvTp, BTN_TIME_SELECT[3], (timeUntilNextBooking > 30));
	setButtonFaded(dvTp, BTN_TIME_SELECT[3], (timeUntilNextBooking > 30));

	setButtonEnabled(dvTp, BTN_TIME_SELECT[4], (timeUntilNextBooking > 60));
	setButtonFaded(dvTp, BTN_TIME_SELECT[4], (timeUntilNextBooking > 60));
}

/**
 * Set the legnth that will be utilised by ad-hoc booking requests.
 */
define_function setBookingRequestLength(integer minutes) {
	stack_var integer i;

	for (i = 1; i <= length_array(BTN_TIME_SELECT); i++) {
		[dvTp, BTN_TIME_SELECT[i]] = (BOOKING_REQUEST_LENGTHS[i] == minutes);
	}

	bookingRequestLength = minutes;
}

/**
 * Sets the system online state.
 *
 * @param	isOnLine	a boolean, true if we are good to go
 */
define_function setOnline(char isOnline) {
	if (isOnline) {

		cancel_wait 'systemOnlineAnimSequence';
		setPageAnimated(dvTp, PAGE_CONNECTED, 'fade', 0, 2);
		wait 10 'systemOnlineAnimSequence' {
			setPageAnimated(dvTp, PAGE_BLANK, 'fade', 0, 10);
			wait 10 'systemOnlineAnimSequence' {
				redraw();
			}
		}

	} else {

		cancel_wait 'systemOnlineAnimSequence';
		setPageAnimated(dvTp, PAGE_BLANK, 'fade', 0, 10);
		wait 10 'systemOnlineAnimSequence' {
			redraw();
		}

	}
}

/**
 * Creates an adhoc booking.
 *
 * @param	startTime	the booking start time in the form HH:MM:SS
 * @param	length		the booking length in minutes
 * @param	user		???
 */
define_function createAdHocBooking(char startTime[8], integer length,
		char user[]) {
	RmsBookingCreate(ldate,
			startTime,
			length,
			'Ad-hoc Meeting',
			'Ad-hoc meeting created from touch panel booking system.',
			locationTracker.location.id);
}


// RMS callbacks

define_function RmsEventSchedulingCreateResponse(char isDefaultLocation,
		char responseText[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location = locationTracker.location.id) {
		// TODO handle create feedback
		// TODO need to make sure this is inserted into todaysBookings
	}
}


// Touch panel callbacks

define_function NfcTagRead(integer tagType, char uid[], integer uidLength) {

	// TODO lookup user

	switch (getState()) {

	case STATE_AVAILABLE:
		// FIXME
		// This needs to handle cases where the TZ of the panel differs from the
		// master.
		createAdHocBooking(time, bookingRequestLength, '');
		break;

	case STATE_BOOKING_ENDING:
		// TODO implement 'book next' functionality'
		break;

	}

}


define_event

channel_event[vdvRMS, RMS_CHANNEL_CLIENT_REGISTERED] {

	on: {
		setOnline(true);
	}

	off: {
		setOnline(false);
	}

}

data_event[dvTp] {

	online: {
		setOnline([vdvRMS, RMS_CHANNEL_CLIENT_REGISTERED]);

		timeline_create(TL_UI_UPDATE,
			UI_UPDATE_INTERVAL,
			1,
			TIMELINE_RELATIVE,
			TIMELINE_REPEAT);
	}

	offline: {
		timeline_kill(TL_UI_UPDATE);
	}

}

timeline_event[TL_UI_UPDATE] {
	redraw();
}

button_event[dvTp, BTN_MEET_NOW]
button_event[dvTp, BTN_BOOK_NEXT] {

	push: {
		// Default to a 20 minute meeting, or if time doesn't allow fall back to
		// 10 minutes
		if (getMinutesUntilNextBooking() > BOOKING_REQUEST_LENGTHS[2]) {
			setBookingRequestLength(BOOKING_REQUEST_LENGTHS[2]);
		} else {
			setBookingRequestLength(BOOKING_REQUEST_LENGTHS[1]);
		}
	}

}

button_event[dvTp, BTN_TIME_SELECT] {

	push: {
		stack_var integer i;
		i = get_last(BTN_TIME_SELECT);
		setBookingRequestLength(BOOKING_REQUEST_LENGTHS[i]);
	}

}


define_start

init();
