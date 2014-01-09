PROGRAM_NAME='BookingTracker'


#DEFINE INCLUDE_SCHEDULING_EVENT_UPDATED_CALLBACK
#DEFINE INCLUDE_SCHEDULING_BOOKINGS_RECORD_RESPONSE_CALLBACK
#DEFINE INCLUDE_SCHEDULING_BOOKING_SUMMARY_DAILY_RESPONSE_CALLBACK


#INCLUDE 'Unixtime';
#INCLUDE 'RmsSchedulingApi';
#INCLUDE 'RmsSchedulingEventListener';


define_constant

// This can be changed as require, just bear in mind each event slot is a little
// piggy when it comes to memory.
integer MAX_DAILY_BOOKINGS = 30;


define_type

structure event {
	SLONG start;
	SLONG end;
    CHAR subject[255];
    CHAR details[1024];
    CHAR isPrivate;
    CHAR isAllDay;
    CHAR organizer[255];
    CHAR onBehalfOf[255];
    CHAR attendees[15][255];
}


define_variable

constant integer BOOKING_MAX_TIME = $ffff;

volatile event todaysBookings[MAX_DAILY_BOOKINGS];


/**
 * Resync all of todays bookings.
 *
 * Note: this is purely a RMS module -> NetLinx resync, not a server action.
 */
 // TODO figure out the best places to call this from
define_function resyncEvents() {
	RmsBookingsSummaryDailyRequest(ldate, locationTracker.location.id);
	RmsBookingsRequest(ldate, locationTracker.location.id);
}

/**
 * Set the total number of events tracked in todaysBookings.
 *
 * @param	count		an integer specifying the number of events tracked
 */
define_function setBookingCount(integer count) {
	stack_var integer i;

	for (i = max_length_array(todaysBookings); i > count; i--) {
		stack_var event blank;
		todaysBookings[i] = blank;
	}

	set_length_array(todaysBookings, count);
}

/**
 * Store an RmsEventBookingResponse as an element within our todaysBookings
 * array.
 *
 * @param	booking		the RmsEventBookingResponse to convert and store
 * @param	id			the index to save this in
 */
define_function storeBooking(RmsEventBookingResponse booking, integer id) {
	stack_var event e;
	
	if (id > max_length_array(todaysBookings)) {
		amx_log(AMX_ERROR, 'Could note store booking, index greater than allocated memory');
		return;
	}

	e.start = unixtime(booking.startDate, booking.startTime);
	e.end = unixtime(booking.endDate, booking.endTime);
	e.subject = booking.subject;
	e.details = booking.details;
	e.isPrivate = booking.isPrivateEvent;
	e.isAllDay = booking.isAllDayEvent;
	e.organizer = booking.organizer;
	e.onBehalfOf = booking.onBehalfOf;
	explode('|', booking.attendees, e.attendees, 0);

	todaysBookings[id] = e;
	
	redraw();
}

/**
 * Get the first instance of a booking id that intersects with a specific time.
 *
 * @param	t			a unixtime value to check for
 * @return				the booking id, 0 if no matching booking is found
 */
define_function integer getBookingAt(slong t) {
	stack_var integer id;
	
	// TODO implemement a more efficient search here
	for (id = 1; id <= length_array(todaysBookings); id++) {
		if (t >= todaysBookings[id].start &&
				t <= todaysBookings[id].end) {
			return id;
		}
	}
	return 0;
}

/**
 * Get the first booking to begin following a specific time.
 *
 * @param	t			a unixtime value to check for
 * @return				the booking id, 0 if no matching booking is found
 */
define_function integer getBookingAfter(slong t) {
	stack_var integer id;
	
	// TODO implemement a more efficient search here
	for (id = 1; id <= length_array(todaysBookings); id++) {
		if (t < todaysBookings[id].start) {
			return id;
		}
	}
	return 0;
}

/**
 * Gets the id of the currently active booking.
 *
 * @return				the active booking id, 0 if no booking is found
 */
define_function integer getActiveBookingId() {
	return getBookingAt(unixtime_now());
}

/**
 * Gets the id of the next booking for the day.
 *
 * @return				the next booking id, 0 if none is found
 */
define_function integer getNextBookingId() {
	return getBookingAfter(unixtime_now());
}

/**
 * Check if the location has an active booking.
 *
 * @return				a boolean, true if a booking is active
 */
define_function char isBookedNow() {
	return getActiveBookingId() != 0;
}

/**
 * Gets the number of minutes until the start of the next booking.
 *
 * @return				the number of minutes until the next booking of the day
 *						begins, BOOKING_MAX_TIME if no more more bookings exist
 */
define_function integer getMinutesUntilNextBooking() {
	stack_var integer nextBooking;
	stack_var slong timeNow;
	timeNow = unixtime_now();
	nextBooking = getBookingAfter(timeNow);
	if (nextBooking == 0) {
		return BOOKING_MAX_TIME;
	}
	return type_cast((todaysBookings[nextBooking].start - timeNow) *
			UNIXTIME_SECONDS_PER_MINUTE);
}

/**
 * Gets the number of minutes until the current booking ends.
 *
 * @return				the number of minutes until the current booking ends,
 *						BOOKING_MAX_TIME if no bookings is active
 */
define_function integer getMinutesUntilBookingEnd() {
	stack_var integer activeBooking;
	stack_var slong timeNow;
	timeNow = unixtime_now();
	activeBooking = getBookingAt(timeNow);
	if (activeBooking == 0) {
		return BOOKING_MAX_TIME;
	}
	return type_cast((todaysBookings[activeBooking].end - timeNow) *
			UNIXTIME_SECONDS_PER_MINUTE);
}


// RMS callbacks

define_function RmsEventSchedulingSummaryDailyResponse(CHAR isDefaultLocation,
		RmsEventBookingDailyCount dailyCount) {
	if (dailyCount.location == locationTracker.location.id) {
		setBookingCount(dailyCount.bookingCount)
	}
}

define_function RmsEventSchedulingEventUpdated(CHAR bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location == locationTracker.location.id) {
		// Little hack to only sync once if we happen to hear back about
		// multiple event updates in one hit.
		cancel_wait 'Scheduling event resync';
		wait 10 'Scheduling event resync' {
			resyncEvents();
		}
	}
}

define_function RmsEventSchedulingBookingsRecordResponse(CHAR isDefaultLocation,
		INTEGER recordIndex,
		INTEGER recordCount,
		CHAR bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location == locationTracker.location.id) {
		storeBooking(eventBookingResponse, recordIndex);
	}
}
