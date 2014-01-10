PROGRAM_NAME='BookingManager'


#IF_NOT_DEFINED __BOOKING_MANAGER__
#DEFINE __BOOKING_MANAGER__


define_constant

integer MAX_SUBJECT_LENGTH = 255;
integer MAX_DETAILS_LENGTH = 255;
integer MAX_NAME_LENGTH = 128;
integer MAX_ATTENDEES = 10;


define_type

structure Event {
	SLONG start;
	SLONG end;
    CHAR subject[MAX_SUBJECT_LENGTH];
    CHAR details[MAX_DETAILS_LENGTH];
    CHAR isPrivate;
    CHAR isAllDay;
    CHAR organizer[MAX_NAME_LENGTH];
    CHAR onBehalfOf[MAX_NAME_LENGTH];
    CHAR attendees[MAX_ATTENDEES][MAX_NAME_LENGTH];
}


/**
 * Get the first instance of a booking id that intersects with a specific time.
 *
 * @param	t			a unixtime value to check for
 * @param	bookingList	an ordered array of Events to search in
 * @return				the booking id, 0 if no matching booking is found
 */
define_function integer getBookingAt(slong t, Event bookingList[]) {
	stack_var integer id;

	// TODO implemement a more efficient search here
	for (id = 1; id <= length_array(bookingList); id++) {
		if (t >= bookingList[id].start &&
				t <= bookingList[id].end) {
			return id;
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

	// TODO implemement a more efficient search here
	for (id = 1; id <= length_array(bookingList); id++) {
		if (t < bookingList[id].start) {
			return id;
		}
	}
	return 0;
}

/**
 * Inserts an Event into an ordered array of Events. Simultaneous bookings are
 * not allowed, If array already contains an event with a matching start time
 * other details will be updated.
 *
 * @param	booking		an Event to insert
 * @param	bookingList a ordered array of Event to insert into
 */
define_function insertBooking(Event booking, Event bookingList[]) {
	stack_var integer insertIndex;

	if (length_array(bookingList) == max_length_array(bookingList)) {
		amx_log(AMX_ERROR, 'Could not insert Event, passed array is already at capacity');
		return;
	}

	// Check to see if we're just updating an existing entry
	insertIndex = getBookingAt(booking.start, bookingList);
	if (!insertIndex) {
	
		// See if there's any more bookings we need to shift down
		stack_var integer nextBookingIndex;
		nextBookingIndex = getBookingAfter(booking.start, bookingList);
		if (nextBookingIndex) {
			stack_var integer tmp;
			tmp = length_array(bookingList) + 1;
			while (tmp > nextBookingIndex) {
				bookingList[tmp] = bookingList[tmp - 1];
				tmp--;
			}
			insertIndex = nextBookingIndex;
		} else {
			insertIndex = length_array(bookingList) + 1;
		}
		
		set_length_array(bookingList, length_array(bookingList) + 1);
	}

	bookingList[insertIndex] = booking;
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
