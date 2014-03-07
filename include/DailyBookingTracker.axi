PROGRAM_NAME='DailyBookingTracker'


#DEFINE INCLUDE_SCHEDULING_EVENT_UPDATED_CALLBACK
#DEFINE INCLUDE_SCHEDULING_BOOKINGS_RECORD_RESPONSE_CALLBACK


#INCLUDE 'Unixtime';
#INCLUDE 'String';
#INCLUDE 'Math';
#INCLUDE 'TimeUtil';
#INCLUDE 'BookingManager';
#INCLUDE 'RmsSchedulingApi';
#INCLUDE 'RmsSchedulingEventListener';


define_variable

// This can be resized as required, just bare in mind each event slot is a
// little piggy when it comes to memory.
volatile Event todaysBookings[30];

constant long DAILY_BOOKING_RESYNC_TL = 27532;
constant long DAILY_BOOKING_RESYNC_INTERVAL[] = {300000};


/**
 * Check if a booking ID is a temporary value assigned prior to full sync.
 *
 * @param	if			the Event to check
 * @return				a boolean, true if the passed Event has a temporary
 *						external id
 */
define_function char bookingHasTemporaryId(Event e) {
	stack_var char tempId[BOOKING_MAX_ID_LENGTH];

	// As of SDK v4.1.16 RMS booking responses will come back with an id that
	// is a concatination of what appears to be the location id, followed by a
	// dash, the event start timestamp, another dash and the end timestamp.
	// Additionally in a create response the ID appears to just contain a two
	// digit number followed by a dash.
	select {
		active(right_string(e.externalId, length_string(tempId)) == tempId): {
			return true;
		}

		active (length_string(e.externalId) == 3 &&
				right_string(e.externalId, 1) == '-'): {
			return true;
		}

		active(1): {
			return false;
		}
	}
}

/**
 * Convert an RmsEventBookingResponse to and Event structure.
 *
 * Note: as NetLinx cannot return structures an event must be passed in to
 * populate.
 *
 * @param	booking		a RmsEventBookingResponseToConvert
 * @param	e			the Event to store the response in
 */
define_function rmsBookingResponseToEvent(RmsEventBookingResponse booking,
		Event e) {
	stack_var slong timeOffset;

	e.externalId = booking.bookingId;

	// FIXME it appears that RMS responses contain the date and times in the
	// local TZ of the location associated with the booking currently this will
	// break if this differs to the TZ of the master
	e.start = unixtime(booking.startDate, booking.startTime);
	e.end = unixtime(booking.endDate, booking.endTime);

	if (booking.subject != 'N/A') {
		e.subject = booking.subject;
	}
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
}

/**
 * Stores an RmsBookingResponse as an event in a booking array.
 *
 * @param	booking		an RmsEventBookingRepsonse to store
 * @param	bookingList	an array to store the booking in
 */
define_function storeRmsBookingResponse(RmsEventBookingResponse booking,
		Event bookingList[]) {
	stack_var Event e;
	stack_var integer insertIndex;

	rmsBookingResponseToEvent(booking, e);

	// Update booking details if we're already tracking this one
	insertIndex = getBooking(e.externalId, bookingList);
	if (insertIndex) {
		updateBooking(e, bookingList, insertIndex);
		return;
	}

	// If that didn't work lets see if there is a booking with a temp ID we can
	// update
	insertIndex = getBookingAt(e.start, bookingList);
	if (insertIndex) {
		if (bookingHasTemporaryId(bookingList[insertIndex])) {
			updateBooking(e, bookingList, insertIndex);
			return;
		}
	}

	// Otherwise insert as a freshn'
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

	// Ideally this should be called from
	// RmsEventSchedulingBookingsRecordResponse(..) when it's the last record
	// however as of SDK v4.1.16 this appears to be broken and containes the
	// same value as recordIndex for every call.
	cancel_wait 'post daily booking resync redraw';
	wait 50 'post daily booking resync redraw'{
		redraw();
	}
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
	return type_cast(ceil(1.0 * (todaysBookings[nextBooking].start - timeNow) /
			UNIXTIME_SECONDS_PER_MINUTE));
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
	return type_cast(ceil(1.0 * (todaysBookings[activeBooking].end - timeNow) /
			UNIXTIME_SECONDS_PER_MINUTE));
}

define_function bookingTrackerHandleCreateResponse(RmsEventBookingResponse response) {
	if (response.isSuccessful &&
			response.location == locationTracker.location.id &&
			response.startDate == ldate) {
		storeRmsBookingResponse(response, todaysBookings);
		redraw();
	}
}


// RMS callbacks

define_function RmsEventSchedulingEventUpdated(CHAR bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	if (eventBookingResponse.location == locationTracker.location.id &&
			eventBookingResponse.startDate == ldate) {
		storeRmsBookingResponse(eventBookingResponse, todaysBookings);
		redraw();
	}
}

define_function RmsEventSchedulingBookingsRecordResponse(CHAR isDefaultLocation,
		INTEGER recordIndex,
		INTEGER recordCount,
		CHAR bookingId[],
		RmsEventBookingResponse eventBookingResponse) {
	// As of SDK v4.1.16 this appears to fire if there are no bookings for the
	// day, albiet with a recordCount of 0
	if (eventBookingResponse.location == locationTracker.location.id &&
			eventBookingResponse.startDate == ldate &&
			recordCount > 0) {
		storeRmsBookingResponse(eventBookingResponse, todaysBookings);
	}
}


define_start

clearBookingList(todaysBookings);


define_event

channel_event[vdvRMS, RMS_CHANNEL_CLIENT_REGISTERED] {

	on: {
		timeline_create(DAILY_BOOKING_RESYNC_TL,
				DAILY_BOOKING_RESYNC_INTERVAL,
				1,
				TIMELINE_RELATIVE,
				TIMELINE_REPEAT);

		cancel_wait 'daily booking initial sync';
		wait 100 'daily booking initial sync'{
			resyncDailyBookings();
		}
	}

	off: {
		if (timeline_active(DAILY_BOOKING_RESYNC_TL)) {
			timeline_kill(DAILY_BOOKING_RESYNC_TL);
		}
	}

}

timeline_event[DAILY_BOOKING_RESYNC_TL] {
	resyncDailyBookings();
}
