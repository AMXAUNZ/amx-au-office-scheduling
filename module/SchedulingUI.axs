MODULE_NAME='SchedulingUI' (dev vdvRms, dev dvTp)


#DEFINE INCLUDE_SCHEDULING_NEXT_ACTIVE_RESPONSE_CALLBACK
#DEFINE INCLUDE_SCHEDULING_ACTIVE_RESPONSE_CALLBACK
#DEFINE INCLUDE_SCHEDULING_NEXT_ACTIVE_UPDATED_CALLBACK
#DEFINE INCLUDE_SCHEDULING_ACTIVE_UPDATED_CALLBACK
#DEFINE INCLUDE_SCHEDULING_EVENT_ENDED_CALLBACK
#DEFINE INCLUDE_SCHEDULING_EVENT_STARTED_CALLBACK
#DEFINE INCLUDE_SCHEDULING_EVENT_UPDATED_CALLBACK
#DEFINE INCLUDE_SCHEDULING_CREATE_RESPONSE_CALLBACK


#INCLUDE 'TimeUtil';
#INCLUDE 'RmsAssetLocationTracker';
#INCLUDE 'TpApi';
#INCLUDE 'RmsApi';
#INCLUDE 'RmsEventListener';
#INCLUDE 'RmsSchedulingApi';
#INCLUDE 'RmsSchedulingEventListener';


define_variable

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

// Options available for 'meet now' and 'book next' inital meeting lengths
constant integer BOOKING_REQUEST_LENGTHS[] = {10, 20, 30, 60};

// Maximum possible value to be stored in minutesUntilX variables
constant long MAX_MINUTES = $ffffffff;

volatile char inUse;
volatile RmsEventBookingResponse activeBooking;
volatile RmsEventBookingResponse nextBooking;

volatile integer bookingRequestLength;


/**
 * Initialise module variables that cannot be assisgned at compile time.
 */
define_function init() {
	clearActiveMeeting();
	clearNextMeeting();

	setLocationTrackerAsset(RmsDevToString(dvTp));
}

/**
 * Render the appropriate popups and page elements for the current system state.
 * This should be called whenever our scheduling information updates.
 */
define_function redraw() {

	// Throttle UI redraws to 100ms
	// Placing this in a wait also enables us to ensure that we have had a
	// chance to handle all relevent events and ensure we don't redraw with
	// partial / incorrect data.
	cancel_wait 'ui update';
	wait 1 'ui update' {

		select {
	
			// Meeting approaching
			active (!inUse && nextBooking.minutesUntilStart <= 5): {
				renderNextMeeting();
			}
			
			// Room available
			active (!inUse): {
				renderRoomAvilable();
			}
	
			// Room in use
			active (inUse && activeBooking.remainingMinutes > 5): {
				renderActiveMeeting();
			}
	
			// Nearing end of current meeting and there's upcoming availability
			active (inUse && (nextBooking.minutesUntilStart - activeBooking.remainingMinutes > 10)): {
				renderBookNext();
			}
	
			// Back to back meeting
			active (inUse): {
				renderBackToBack();
			}

			// Ummmm...
			active (1): {
				amx_log(AMX_WARNING, 'Unexpected system state. Could not update UI');
			}
	
		}
	}
}

/**
 * Set up the UI to display the 'room available' screen.
 *
 * Do not call this directly. If an update is required use redraw().
 */
define_function renderRoomAvilable() {
	stack_var char nextInfoText[512];
	
	if (nextBooking.startDate == ldate) {
		nextInfoText = "'"', nextBooking.subject, '" begins in ', fuzzyTime(nextBooking.minutesUntilStart), '.'";
	} else {
		nextInfoText = 'No bookings currently scheduled for the rest of the day.';
	}

	setButtonText(dvTp, BTN_NEXT_INFO, nextInfoText);

	setPageAnimated(dvTp, PAGE_AVAILABLE, 'fade', 0, 20);
}

/**
 * Set up the UI to display the next active meeting info.
 *
 * Do not call this directly. If an update is required use redraw().
 */
define_function renderNextMeeting() {
	setButtonText(dvTP, BTN_ACTIVE_MEETING_NAME, nextBooking.subject);
	setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Starts in ', fuzzyTime(nextBooking.minutesUntilStart)");
	setButtonText(dvTp, BTN_ACTIVE_TIMES,"time12Hour(activeBooking.startTime), ' - ', time12Hour(activeBooking.endTime)");

	// TODO show attendees

	showPopupEx(dvTp, POPUP_ACTIVE_INFO, PAGE_IN_USE);

	setPageAnimated(dvTp, PAGE_IN_USE, 'fade', 0, 20);
}

/**
 * Set up the UI to display the active meeting info.
 *
 * Do not call this directly. If an update is required use redraw().
 */
define_function renderActiveMeeting() {
	setButtonText(dvTp, BTN_ACTIVE_MEETING_NAME, activeBooking.subject);
	setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Ends in ', fuzzyTime(activeBooking.remainingMinutes)");
	setButtonText(dvTp, BTN_ACTIVE_TIMES,"time12Hour(activeBooking.startTime), ' - ', time12Hour(activeBooking.endTime)");

	// TODO set attendees

	showPopupEx(dvTp, POPUP_ACTIVE_INFO, PAGE_IN_USE);
	
	setPageAnimated(dvTp, PAGE_IN_USE, 'fade', 0, 20);
}

/**
 * Set up the UI to display the 'book next' screen.
 *
 * Do not call this directly. If an update is required use redraw().
 */
define_function renderBookNext() {
	stack_var char availability[512];
	
	if (nextBooking.startDate == ldate) {
		availability = fuzzyTime(nextBooking.minutesUntilStart);
	} else {
		availability = 'the rest of the day';
	}
	
	setButtonText(dvTp, BTN_ACTIVE_MEETING_NAME, activeBooking.subject);
	setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Ends in ', fuzzyTime(activeBooking.remainingMinutes)");
	setButtonText(dvTp, BTN_AVAILABILITY_WINDOW, "'The room is available for ', availability, ' following the current meeting.'");

	showPopupEx(dvTp, POPUP_BOOK_NEXT, PAGE_IN_USE);
	
	setPageAnimated(dvTp, PAGE_IN_USE, 'fade', 0, 20);
}

/**
 * Set up the UI to display the 'back to back' screen.
 *
 * Do not call this directly. If an update is required use redraw().
 */
define_function renderBackToBack() {	
	setButtonText(dvTp, BTN_ACTIVE_MEETING_NAME, activeBooking.subject);
	setButtonText(dvTp, BTN_ACTIVE_MEETING_TIMER, "'Ends in ', fuzzyTime(activeBooking.remainingMinutes)");
	setButtonText(dvTp, BTN_BACK_TO_BACK_INFO, "'The room is reserved for "', nextBooking.subject, '" directly following this.'");
	
	showPopupEx(dvTp, POPUP_BACK_TO_BACK, PAGE_IN_USE);
	
	setPageAnimated(dvTp, PAGE_IN_USE, 'fade', 0, 20);
}

/**
 * Update the meeting length presented for selection based on the available
 * time window.
 */
define_function updateAvailableBookingTimes() {
	setButtonEnabled(dvTp, BTN_TIME_SELECT[1], (nextBooking.minutesUntilStart > 10));
	setButtonFaded(dvTp, BTN_TIME_SELECT[1], (nextBooking.minutesUntilStart > 10));
	
	setButtonEnabled(dvTp, BTN_TIME_SELECT[2], (nextBooking.minutesUntilStart > 20));
	setButtonFaded(dvTp, BTN_TIME_SELECT[2], (nextBooking.minutesUntilStart > 20));
	
	setButtonEnabled(dvTp, BTN_TIME_SELECT[3], (nextBooking.minutesUntilStart > 30));
	setButtonFaded(dvTp, BTN_TIME_SELECT[3], (nextBooking.minutesUntilStart > 30));
	
	setButtonEnabled(dvTp, BTN_TIME_SELECT[4], (nextBooking.minutesUntilStart > 60));
	setButtonFaded(dvTp, BTN_TIME_SELECT[4], (nextBooking.minutesUntilStart > 60));	
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
 * Sets the system state.
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
			setPageAnimated(dvTp, PAGE_CONNECTING, 'fade', 0, 20);
		}

	}
}

/**
 * Sets the room available state.
 *
 * @param	isInUse		a boolean, true if the room is in use
 */
define_function setInUse(char isInUse) {
	inUse = isInUse;
	redraw();
}

/**
 * Sets the active meeting info for the touch panel location.
 *
 * @param	booking		an RmsEventBookingResponse containing the active meeting
 *						data
 */
define_function setActiveMeetingInfo(RmsEventBookingResponse booking) {
	activeBooking = booking;
	redraw();
}

/**
 * Sets the next meeting info for the touch panel location.
 *
 * @param	booking		an RmsEventBookingResponse containing the next meeting
 *						data
 */
define_function setNextMeetingInfo(RmsEventBookingResponse booking) {
	
	// As of SDK v4.1.14 the next active update events will fire when creating
	// bookings before all the data is available. When valid data is coming
	// in minutesUntilStart wil always be > 0. Handling this here just
	// simplified things in the render() function.
	if (booking.minutesUntilStart == 0) {
		booking.minutesUntilStart = MAX_MINUTES;
	}
	
	nextBooking = booking;
	
	updateAvailableBookingTimes();
	redraw();
}

/**
 * Clears the contents of the currently tracked active meeting.
 *
 */
define_function clearActiveMeeting() {
	stack_var RmsEventBookingResponse blank;
	blank.minutesUntilStart = MAX_MINUTES;
	setActiveMeetingInfo(blank);
}

/**
 * Clears the contents of the currently tracked active meeting.
 *
 */
define_function clearNextMeeting() {
	stack_var RmsEventBookingResponse blank;
	blank.minutesUntilStart = MAX_MINUTES;
	setNextMeetingInfo(blank);
}


// RMS callbacks

define_function RmsEventSchedulingNextActiveResponse(char isDefaultLocation,
		integer recordIndex,
		integer recordCount,
		char bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location == locationTracker.location.id) {
		setNextMeetingInfo(eventBookingResponse);
	}
}

define_function RmsEventSchedulingActiveResponse(char isDefaultLocation,
		integer recordIndex,
		integer recordCount,
		char bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location == locationTracker.location.id) {
		setActiveMeetingInfo(eventBookingResponse);
		setInUse(true);
	}
}

define_function RmsEventSchedulingNextActiveUpdated(char bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location == locationTracker.location.id) {
		setNextMeetingInfo(eventBookingResponse);
	}
}

define_function RmsEventSchedulingActiveUpdated(char bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location == locationTracker.location.id) {
		setActiveMeetingInfo(eventBookingResponse);
		setInUse(true);
	}
}

define_function RmsEventSchedulingEventEnded(CHAR bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location == locationTracker.location.id) {
		clearActiveMeeting();
		setInUse(false);
	}
}

define_function RmsEventSchedulingEventStarted(CHAR bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location == locationTracker.location.id) {
		setActiveMeetingInfo(eventBookingResponse);
		if (activeBooking.bookingId == nextBooking.bookingId) {
			clearNextMeeting();
		}
		setInUse(true);
	}
}

define_function RmsEventSchedulingEventUpdated(CHAR bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location == locationTracker.location.id) {
		// As of SDK v4.1.14 the active and next active update callbacks will
		// not fire for up to a minute after event creations or modifications.
		// The general update callback (this method) does however get called
		// as soon as anything changes so we can force an update here to make
		// sure we keep out UI as responsive as possible. This is however called
		// for every event so the wait also acts as a run once to cut down on
		// redundant queries.
		cancel_wait 'forced update query';
		wait 5 'forced update query' {
			RmsBookingActiveRequest(locationTracker.location.id);
			RmsBookingNextActiveRequest(locationTracker.location.id);
		}
	}
}

define_function RmsEventSchedulingCreateResponse(char isDefaultLocation,
		char responseText[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location = locationTracker.location.id) {
		// TODO handle create feedback
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
	}

}

button_event[dvTp, BTN_MEET_NOW]
button_event[dvTp, BTN_BOOK_NEXT] {

	push: {
		// Default to a 20 minute meeting, or if time doesn't allow fall back to
		// 10 minutes
		if (nextBooking.minutesUntilStart > BOOKING_REQUEST_LENGTHS[2]) {
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
