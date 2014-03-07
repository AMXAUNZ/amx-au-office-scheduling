PROGRAM_NAME='BookingManager'


#IF_NOT_DEFINED __BOOKING_MANAGER__
#DEFINE __BOOKING_MANAGER__


define_constant

integer BOOKING_MAX_ID_LENGTH = 255;
integer BOOKING_MAX_SUBJECT_LENGTH = 255;
integer BOOKING_MAX_DETAILS_LENGTH = 255;
integer BOOKING_MAX_NAME_LENGTH = 128;
integer BOOKING_MAX_ATTENDEES = 10;


define_type

structure Event {
	char externalId[BOOKING_MAX_ID_LENGTH];
	SLONG start;
	SLONG end;
    CHAR subject[BOOKING_MAX_SUBJECT_LENGTH];
    CHAR details[BOOKING_MAX_DETAILS_LENGTH];
    CHAR isPrivate;
    CHAR isAllDay;
    CHAR organizer[BOOKING_MAX_NAME_LENGTH];
    CHAR onBehalfOf[BOOKING_MAX_NAME_LENGTH];
    CHAR attendees[BOOKING_MAX_ATTENDEES][BOOKING_MAX_NAME_LENGTH];
}

/**
 * Check if two booking references are equivelent.
 *
 * @param	b1			the first booking to compare
 * @param	b2			a booking to compare to b1
 * @return				a boolean, true if b1 == b2
 */
define_function char bookingIsEqual(Event b1, Event b2) {
	return b1.externalId == b2.externalId;
}

/**
 * Get the booking id that intersects with a specific time.
 *
 * @param	t			a unixtime value to check for
 * @param	bookingList	an ordered array of Events to search in
 * @return				the booking id, 0 if no matching booking is found
 */
define_function integer getBookingAt(slong t, Event bookingList[]) {
	stack_var integer id;
	stack_var integer min;
	stack_var integer max;

	min = 1;
	max = length_array(bookingList);

	while (max >= min) {
		id = min + (max - min) / 2;
		if (t >= bookingList[id].start && t <= bookingList[id].end) {
			return id;
		} else if (t > bookingList[id].start) {
			min = id + 1;
		} else {
			max = id - 1;
		}
	}

	return 0;
}

/**
 * Get the first booking to begin following a specific time.
 *
 * @param	t			a unixtime value to check for
 * @param	bookingList	an ordered array of Events to search in
 * @return				the booking id, 0 if no matching booking is found
 */
define_function integer getBookingAfter(slong t, Event bookingList[]) {
	stack_var integer id;

	// TODO implement a more efficient search here
	for (id = 1; id <= length_array(bookingList); id++) {
		if (t < bookingList[id].start) {
			return id;
		}
	}

	return 0;
}

/**
 * Get a booking based on an external booking ID.
 *
 * @param	externalId		the external ID to search for
 * @param	bookingList		an array of Events to search in
 * @return					the index of a matching booking, 0 if not found
 */
define_function integer getBooking(char externalId[], Event bookingList[]) {
	stack_var integer id;

	// TODO implement a more efficient search here
	for (id = 1; id <= length_array(bookingList); id++) {
		if (externalId == bookingList[id].externalId) {
			return id;
		}
	}

	return 0;
}

/**
 * Update the booking details at a specific index.
 *
 * @param	booking		the updated Event
 * @param	bookingList a ordered array of Event to insert into
 * @param	index		the insertion index
 */
define_function updateBooking(Event booking, Event bookingList[], integer index) {
	bookingList[index] = booking;
}

/**
 * Inserts an Event into an ordered array of Events.
 *
 * @param	booking		an Event to insert
 * @param	bookingList a ordered array of Event to insert into
 */
define_function insertBooking(Event booking, Event bookingList[]) {
	stack_var integer nextBookingIndex;

	if (length_array(bookingList) == max_length_array(bookingList)) {
		amx_log(AMX_ERROR, 'Could not insert Event, passed array is already at capacity');
		return;
	}

	// See if there's any more bookings we need to shift down
	nextBookingIndex = getBookingAfter(booking.start, bookingList);
	if (nextBookingIndex) {
		stack_var integer tmp;
		tmp = length_array(bookingList) + 1;
		while (tmp > nextBookingIndex) {
			bookingList[tmp] = bookingList[tmp - 1];
			tmp--;
		}
		updateBooking(booking, bookingList, nextBookingIndex);
	} else {
		updateBooking(booking, bookingList, length_array(bookingList) + 1);
	}

	set_length_array(bookingList, length_array(bookingList) + 1);
}

/**
 * Clears an array of Events.
 *
 * @param	bookingList	the array to clear
 */
define_function clearBookingList(Event bookingList[]) {
	set_length_array(bookingList, 0);
}


#END_IF // __BOOKING_MANAGER__
