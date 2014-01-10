PROGRAM_NAME='DailyBookingTracker'


#DEFINE INCLUDE_SCHEDULING_EVENT_UPDATED_CALLBACK
#DEFINE INCLUDE_SCHEDULING_BOOKINGS_RECORD_RESPONSE_CALLBACK


#INCLUDE 'Unixtime';
#INCLUDE 'String';
#INCLUDE 'BookingManager';
#INCLUDE 'RmsSchedulingApi';
#INCLUDE 'RmsSchedulingEventListener';


define_variable

// This can be resized as required, just bear in mind each event slot is a
// little piggy when it comes to memory.
volatile Event todaysBookings[30];

constant long DAILY_BOOKING_RESYNC_TL = 27532;
constant long DAILY_BOOKING_RESYNC_INTERVAL[] = {300000};


/**
 * Stores an RmsBookingResponse as an event in a booking array.
 *
 * @param	booking		an RmsEventBookingRepsonse to store
 * @param	bookingList	an array to store the booking in
 */
define_function storeRmsBookingResponse(RmsEventBookingResponse booking,
		Event bookingList[]) {
	stack_var Event e;

	e.start = unixtime(booking.startDate, booking.startTime);
	e.end = unixtime(booking.endDate, booking.endTime);
	e.subject = booking.subject;
	if (booking.details != 'N/A') {
		e.details = booking.details;
	}
	e.isPrivate = booking.isPrivateEvent;
	e.isAllDay = booking.isAllDayEvent;
	if (booking.organizer != 'N/A') {
		e.organizer = booking.organizer;
	}
	if (booking.onBehalfOf != 'N/A') {
		e.onBehalfOf = booking.onBehalfOf;
	}
	if (booking.attendees != 'N/A') {
		explode('|', booking.attendees, e.attendees, 0);
	}

	insertBooking(e, bookingList);
}

/**
 * Clear out all currently tracked events and resync to RMS.
 *
 * Note: this is purely a RMS module -> NetLinx resync, not a server action.
 */
define_function resyncDailyBookings() {
	clearBookingList(todaysBookings);
	RmsBookingsRequest(ldate, locationTracker.location.id);
}

/**
 * Gets the id of the currently active booking.
 *
 * @return				the active booking id, 0 if no booking is found
 */
define_function integer getActiveBookingId() {
	return getBookingAt(unixtime_now(), todaysBookings);
}

/**
 * Gets the id of the next booking for the day.
 *
 * @return				the next booking id, 0 if none is found
 */
define_function integer getNextBookingId() {
	return getBookingAfter(unixtime_now(), todaysBookings);
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
 *						begins, $ffff if no more more bookings exist
 */
define_function integer getMinutesUntilNextBooking() {
	stack_var integer nextBooking;
	stack_var slong timeNow;
	timeNow = unixtime_now();
	nextBooking = getBookingAfter(timeNow, todaysBookings);
	if (nextBooking == 0) {
		return $ffff;
	}
	return type_cast((todaysBookings[nextBooking].start - timeNow) *
			UNIXTIME_SECONDS_PER_MINUTE);
}

/**
 * Gets the number of minutes until the current booking ends.
 *
 * @return				the number of minutes until the current booking ends,
 *						0 if no booking is active
 */
define_function integer getMinutesUntilBookingEnd() {
	stack_var integer activeBooking;
	stack_var slong timeNow;
	timeNow = unixtime_now();
	activeBooking = getBookingAt(timeNow, todaysBookings);
	if (activeBooking == 0) {
		return 0;
	}
	return type_cast((todaysBookings[activeBooking].end - timeNow) *
			UNIXTIME_SECONDS_PER_MINUTE);
}

/**
 * RMS response handler for any RmsEventBookingResponses that should be 
 * considered for including in the daily bookings list.
 *
 * @param	booking		the RmsEventBookingResponse to (possibly) store
 */
define_function handleRmsBookingResponse(RmsEventBookingResponse booking) {
	if (booking.isSuccessful &&
			booking.location == locationTracker.location.id &&
			booking.startDate == ldate) {
		storeRmsBookingResponse(booking, todaysBookings);
		redraw();
	}
}


// RMS callbacks

define_function RmsEventSchedulingEventUpdated(CHAR bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	handleRmsBookingResponse(eventBookingResponse);
}

define_function RmsEventSchedulingBookingsRecordResponse(CHAR isDefaultLocation,
		INTEGER recordIndex,
		INTEGER recordCount,
		CHAR bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	handleRmsBookingResponse(eventBookingResponse);
}


define_start

timeline_create(DAILY_BOOKING_RESYNC_TL,
		DAILY_BOOKING_RESYNC_INTERVAL,
		1,
		TIMELINE_RELATIVE,
		TIMELINE_REPEAT);


define_event

timeline_event[DAILY_BOOKING_RESYNC_TL] {
	resyncDailyBookings();
}


define_start

clearBookingList(todaysBookings);
