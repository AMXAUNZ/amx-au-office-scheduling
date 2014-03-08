MODULE_NAME='SchedulingUI' (dev vdvRms, dev dvTp)


#DEFINE INCLUDE_SCHEDULING_CREATE_RESPONSE_CALLBACK
#DEFINE INCLUDE_TP_NFC_TAG_READ_CALLBACK
#DEFINE INCLUDE_RESOURCE_LOAD_CALLBACK
#DEFINE LOCATION_TRACKER_UPDATE_CALLBACK


#INCLUDE 'String';
#INCLUDE 'Unixtime';
#INCLUDE 'TimeUtil';
#INCLUDE 'DeviceUtil';
#INCLUDE 'ProfileImageManager';
#INCLUDE 'RmsAssetLocationTracker';
#INCLUDE 'RmsRapidUpdater';
#INCLUDE 'DailyBookingTracker';
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
constant char STATE_RESERVING = 7;

// Page names
constant char PAGE_BLANK[] = 'blank';
constant char PAGE_CONNECTED[] = 'connected';
constant char PAGE_CONNECTING[] = 'connecting';
constant char PAGE_AVAILABLE[] = 'available';
constant char PAGE_IN_USE[] = 'inUse';
constant char PAGE_RESERVING[] = 'reserving';

// Popups
constant char POPUP_CREATE[] = 'create';
constant char POPUP_TODAY[] = 'today';
constant char POPUP_ACTIVE_INFO[] = 'activeInfo';
constant char POPUP_BACK_TO_BACK[] = 'backToBack';
constant char POPUP_BOOK_NEXT[] = 'bookNext';

// Sub page prefixs
constant char SUBPAGE_ATTENDEE[] = '[attendee]';
constant char SUBPAGE_BOOKING[] = '[booking]';

// Dynamic image resources
constant char DYN_ATTENDEE_PREFIX[] = 'attendee';

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
constant integer BTN_ATTENDEE_IMG[] = {13, 14, 15, 16, 17, 18, 19, 20, 21, 22};
constant integer BTN_ATTENDEE_NAME[] = {23, 24, 25, 26, 27, 28, 29, 30, 31, 32};
constant integer BTN_ATTENDEES = 33;
constant integer BTN_BOOKING_NAME[] = {34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48};
constant integer BTN_BOOKING_TIME[] = {49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63};
constant integer BTN_BOOKINGS = 64;
constant integer BTN_ONLINE_INDICATOR = 255;

// UI re-render manager
constant long UI_UPDATE_INTERVAL[] = {15000};
constant long UI_UPDATE_TL = 3478;

// Options available for 'meet now' and 'book next' inital meeting lengths
constant integer BOOKING_REQUEST_LENGTHS[] = {10, 20, 30, 60};

// Variable text character length
// We're not using a monospace font so this is super hacky, ideally we need to
// look at individual characters, sum the widths and also account for word
// wrapping on multi line buttons, but this will do for now...
constant integer MAX_MEETING_NAME_LENGTH = 25;
constant integer MAX_ATTENDEE_NAME_LENGTH = 28;
constant integer MAX_MEETING_LIST_NAME_LENGTH = 32;

volatile integer bookingRequestLength;

volatile char awaitingMeetNowConfirm;
volatile char awaitingBookNextConfirm;
volatile char awaitingCreateResponse;


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
	stack_var integer minutesUntilNextBooking;
	stack_var integer minutesRemaining;

	isBooked = isBookedNow();
	minutesUntilNextBooking = getMinutesUntilNextBooking();
	minutesRemaining = getMinutesUntilBookingEnd();

	select {

		// No connection to the RMS server
		active (![vdvRMS, RMS_CHANNEL_CLIENT_REGISTERED]): {
			state = STATE_OFFLINE;
		}

		active (awaitingCreateResponse): {
			state = STATE_RESERVING;
		}

		// Meeting approaching
		active (!isBooked && minutesUntilNextBooking <= 10): {
			state = STATE_BOOKING_NEAR;
		}

		// Room available
		active (!isBooked): {
			state = STATE_AVAILABLE;
		}

		// Room in use
		active (isBooked && minutesRemaining > 5): {
			state = STATE_IN_USE;
		}

		// Nearing end of current meeting and there's upcoming availability
		active (isBooked &&
				(minutesUntilNextBooking - minutesRemaining > 10)): {
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
	// Throttle UI renders to 100ms
	cancel_wait 'ui update';
	wait 1 'ui update' {
		if (device_id(dvTp)) {
			render(getState());
		}
	}
}

/**
 * Render the appropriate popups and page elements for a passed system state.
 *
 * To trigger an update from other areas of code use redraw().
 */
define_function render(char state) {
	stack_var integer currentId;
	stack_var integer nextId;
	stack_var event current;
	stack_var event next;
	stack_var slong timeNow;
	stack_var slong timeOffset;
	
	// Don't both attempting to render anything if the panel isn't there.
	if (!isDeviceOnline(dvTp)) {
		return;
	}

	on[dvTp, BTN_ONLINE_INDICATOR];

	currentId = getActiveBookingId();
	if (currentId) {
		current = todaysBookings[currentId];
	}
	nextId = getNextBookingId();
	if (nextId) {
		next = todaysBookings[nextId];
	}

	timeNow = unixtime_now();
	timeOffset = getTimeOffset();

	updateBookingList(todaysBookings);

	switch (state) {

	case STATE_OFFLINE: {
		setPageAnimated(dvTp, PAGE_CONNECTING, 'fade', 0, 20);
		break;
	}

	case STATE_RESERVING: {
		setPageAnimated(dvTp, PAGE_RESERVING, 'fade', 0, 5);
		break;
	}

	case STATE_AVAILABLE: {
		stack_var char nextInfoText[512];

		if (nextId) {
			nextInfoText = "'Next in use in ', fuzzyTime(timeNow, next.start), '.'";
		} else {
			nextInfoText = 'No bookings currently scheduled for the rest of the day.';
		}

		setButtonText(dvTp, BTN_NEXT_INFO, nextInfoText);

		setPageAnimated(dvTp, PAGE_AVAILABLE, 'fade', 0, 20);

		break;
	}

	case STATE_IN_USE: {
		setButtonText(dvTp, BTN_ACTIVE_MEETING_NAME, string_truncate(current.subject, MAX_MEETING_NAME_LENGTH));
		setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Ends in ', fuzzyTime(timeNow, current.end)");
		setButtonText(dvTp, BTN_ACTIVE_TIMES, "fmt_date('g:ia', current.start + timeOffset), ' - ', fmt_date('g:ia', current.end + timeOffset)");

		updateAttendees(current.attendees);

		showPopupEx(dvTp, POPUP_ACTIVE_INFO, PAGE_IN_USE);

		setPageAnimated(dvTp, PAGE_IN_USE, 'fade', 0, 20);

		break;
	}

	case STATE_BOOKING_NEAR: {
		setButtonText(dvTP, BTN_ACTIVE_MEETING_NAME, string_truncate(next.subject, MAX_MEETING_NAME_LENGTH));
		setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Starts in ', fuzzyTime(timeNow, next.start)");
		setButtonText(dvTp, BTN_ACTIVE_TIMES, "fmt_date('g:ia', next.start + timeOffset), ' - ', fmt_date('g:ia', next.end + timeOffset)");

		updateAttendees(next.attendees);

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

		setButtonText(dvTp, BTN_ACTIVE_MEETING_NAME, string_truncate(current.subject, MAX_MEETING_NAME_LENGTH));
		setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Ends in ', fuzzyTime(timeNow, current.end)");
		setButtonText(dvTp, BTN_AVAILABILITY_WINDOW, "'The room is available for ', availability, ' following the current meeting.'");

		showPopupEx(dvTp, POPUP_BOOK_NEXT, PAGE_IN_USE);

		setPageAnimated(dvTp, PAGE_IN_USE, 'fade', 0, 20);

		break;
	}

	case STATE_BOOKED_BACK_TO_BACK: {
		setButtonText(dvTp, BTN_ACTIVE_MEETING_NAME, string_truncate(current.subject, MAX_MEETING_NAME_LENGTH));
		setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Ends in ', fuzzyTime(timeNow, current.end)");
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
 * Clears the attendee list shown on the UI.
 *
 */
define_function clearAttendees() {
	stack_var integer i;

	for (i = max_length_array(BTN_ATTENDEE_NAME); i; i--) {
		hideSubPage(dvTp, BTN_ATTENDEES, "SUBPAGE_ATTENDEE, itoa(i)");
		setButtonImage(dvTp, BTN_ATTENDEE_IMG[i], 'profile-placeholder.png');
	}
}

/**
 * Update the attendee list shown on the UI.
 *
 * @param	attendees		an array of attendee names
 */
define_function updateAttendees(char attendees[][]) {
	stack_var integer i;
	stack_var char updateRequired;
	local_var char lastUpdate[BOOKING_MAX_ATTENDEES][MAX_ATTENDEE_NAME_LENGTH];
	
	if (length_array(attendees) = 0) {
		updateRequired = true;
	} else if (length_array(attendees) != length_array(lastUpdate)) {
		updateRequired = true;
	} else {
		for (i = length_array(attendees); i; i--) {
			if (attendees[] != lastUpdate[i]) {
				updateRequired = true;
			}
		}
	}
	
	lastUpdate = attendees;
	
	if (!updateRequired) {
		return;
	}
	
	clearAttendees();

	for (i = length_array(attendees); i; i--) {
		loadProfileImage(dvTp, "DYN_ATTENDEE_PREFIX, itoa(i)", attendees[i]);
		setButtonText(dvTp, BTN_ATTENDEE_NAME[i], string_truncate(attendees[i], MAX_ATTENDEE_NAME_LENGTH));
		showSubPage(dvTp, BTN_ATTENDEES, "SUBPAGE_ATTENDEE, itoa(i)");
	}
}

/**
 * Update the todays bookings list shown on the UI.
 *
 * @param	attendees		an array of attendee names
 */
define_function clearUIBookingList() {
	stack_var integer i;

	for (i = max_length_array(BTN_BOOKING_NAME); i; i--) {
		hideSubPage(dvTp, BTN_BOOKINGS, "SUBPAGE_BOOKING, itoa(i)");
	}
}

/**
 * Update the todays bookings list shown on the UI.
 *
 * @param	attendees		an array of attendee names
 */
define_function updateBookingList(Event bookings[]) {
	stack_var integer i;
	stack_var slong timeOffset;
	stack_var char updateRequired;
	local_var Event lastUpdate[MAX_DAILY_BOOKINGS];

	if (length_array(bookings) = 0) {
		updateRequired = true;
	} else if (length_array(bookings) != length_array(lastUpdate)) {
		updateRequired = true;
	} else {
		for (i = length_array(bookings); i; i--) {
			if (!bookingIsEqual(bookings[i], lastUpdate[i])) {
				updateRequired = true;
				break;
			}
		}
	}
	
	lastUpdate = bookings;
	
	if (!updateRequired) {
		return;
	}
	
	clearUIBookingList();

	timeOffset = getTimeOffset();

	for (i = length_array(bookings); i; i--) {
		setButtonText(dvTp, BTN_BOOKING_NAME[i], string_truncate(bookings[i].subject, MAX_MEETING_LIST_NAME_LENGTH));
		setButtonText(dvTp, BTN_BOOKING_TIME[i], "fmt_date('g:ia', bookings[i].start + timeOffset), ' - ', fmt_date('g:ia', bookings[i].end + timeOffset)");
		showSubPage(dvTp, BTN_BOOKINGS, "SUBPAGE_BOOKING, itoa(i)");
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
 * @param	startTime	the booking start
 * @param	length		the booking length in minutes
 * @param	user		???
 */
define_function createBooking(slong startTime, integer length,
		char user[]) {
	stack_var slong offset;

	// Booking request times appear to be in the TZ of the location the request
	// is for.
	offset = getTimeOffset();
	RmsBookingCreate(unixtime_to_netlinx_ldate(startTime + offset),
			unixtime_to_netlinx_time(startTime + offset),
			length,
			'Ad-hoc Meeting',
			'Ad-hoc meeting created from touch panel booking system.',
			locationTracker.location.id);

	awaitingCreateResponse = true;

	// Rather than waiting for the next heartbeat for a response lets accelerate
	// things a little bit so we can keep the UI nice and fast.
	setRmsRapidUpdateEnabled(true);
}

/**
 * Sets the pre-selected booking length.
 */
define_function setDefaultBookingLength() {
	// Default to a 20 minute meeting, or if time doesn't allow fall back to
	// 10 minutes
	if (getMinutesUntilNextBooking() > BOOKING_REQUEST_LENGTHS[2]) {
		setBookingRequestLength(BOOKING_REQUEST_LENGTHS[2]);
	} else {
		setBookingRequestLength(BOOKING_REQUEST_LENGTHS[1]);
	}
}

/**
 * Submit a 'meet now' request for the passed user.
 *
 * @param	user		???
 */
define_function meetNow(char user[]) {
	createBooking(unixtime_now(), bookingRequestLength, '');
}


/**
 * Submit a 'book next' request for the passed user.
 *
 * @param	user		???
 */
define_function bookNext(char user[]) {
	stack_var Event current;
	current = todaysBookings[getActiveBookingId()];
	createBooking(current.end, bookingRequestLength, '');
}


// RMS callbacks

define_function RmsEventSchedulingCreateResponse(char isDefaultLocation,
		char responseText[],
		RmsEventBookingResponse eventBookingResponse) {
	setRmsRapidUpdateEnabled(false);
	awaitingCreateResponse = false;
	bookingTrackerHandleCreateResponse(eventBookingResponse);
}


// Touch panel callbacks

define_function TpResourceLoaded(char name[]) {
	select {
		active (string_starts_with(name, DYN_ATTENDEE_PREFIX)): {
			setButtonImage(dvTp, BTN_ATTENDEE_IMG[atoi(name)], name);
		}
	}
}

define_function NfcTagRead(integer tagType, char uid[], integer uidLength) {
	if (awaitingMeetNowConfirm) {
		meetNow('');
		awaitingMeetNowConfirm = false;
		redraw();
	} else if (awaitingBookNextConfirm) {
		bookNext('');
		awaitingMeetNowConfirm = false;
		redraw();
	}
}


// Location tracker callbacks

define_function locationTrackerUpdated(RmsLocation location) {
	resyncDailyBookings();
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

		timeline_create(UI_UPDATE_TL,
			UI_UPDATE_INTERVAL,
			1,
			TIMELINE_RELATIVE,
			TIMELINE_REPEAT);
	}

	offline: {
		timeline_kill(UI_UPDATE_TL);
	}

}

timeline_event[UI_UPDATE_TL] {
	redraw();
}

button_event[dvTp, BTN_MEET_NOW] {

	push: {
		updateAvailableBookingTimes()
		setDefaultBookingLength();
		showPopup(dvTp, POPUP_CREATE);
		awaitingMeetNowConfirm = true;
		cancel_wait 'Meet now confirm'
		wait 300 'Meet now confirm' {
			awaitingMeetNowConfirm = false;
			hidePopup(dvTp, POPUP_CREATE);
		}
	}

}

button_event[dvTp, BTN_BOOK_NEXT] {

	push: {
		updateAvailableBookingTimes();
		setDefaultBookingLength();
		showPopup(dvTp, POPUP_CREATE);
		awaitingBookNextConfirm = true;
		cancel_wait 'Book next confirm'
		wait 300 'Book next confirm' {
			awaitingBookNextConfirm = false;
			hidePopup(dvTp, POPUP_CREATE);
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
