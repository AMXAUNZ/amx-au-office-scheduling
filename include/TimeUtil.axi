PROGRAM_NAME='TimeUtil'


#INCLUDE 'Unixtime';


define_constant

FUZZY_TIME_RETURN_SIZE = 32;


/**
 * Convert a delta between two unixtime values into a human readable (and easily
 * understandable) string.
 *
 * @param	t1			a unixtime time value to form the lower end of the delta
 * @param	t2			a unixtime value to form the upper end of the delta
 * @return				a string containing the time difference between between
 *						't1' and 't2' in a represented in a nice, readble
 *						format.
 */
define_function char[FUZZY_TIME_RETURN_SIZE] fuzzyTime(slong t1, slong t2) {
	stack_var char ret[FUZZY_TIME_RETURN_SIZE];

/*
	select {
		active (minutes <= 1 * TIME_MINUTE): {
			ret = '1 minute';
		}
		active (minutes <= 25 * TIME_MINUTE): {
			ret = "itoa(minutes), ' minutes'";
		}
		active (minutes <= 40 * TIME_MINUTE): {
			ret = 'half an hour';
		}
		active (minutes < 80 * TIME_MINUTE): {
			ret = '1 hour';
		}
		active (minutes <  105 * TIME_MINUTE): {
			ret = '1 and a half hours';
		}
		active (minutes < 2 * TIME_HOUR): {
			ret = '2 hours';
		}
		active (minutes < 20 * TIME_HOUR): {
			ret = "itoa(minutes / TIME_HOUR), ' hours'";
		}
		active (minutes < 30 * TIME_HOUR): {
			ret = '1 day';
		}
		active (minutes < 40 * TIME_HOUR): {
			ret = '1 and a half days';
		}
		active (minutes < 2 * TIME_DAY): {
			ret = '2 days';
		}
		active (minutes < 30 * TIME_DAY): {
			ret = "itoa(minutes / TIME_DAY), ' days'";
		}
		active (minutes < 40 * TIME_MONTH): {
			ret = '1 month';
		}
		active (minutes < 50 * TIME_DAY): {
			ret = '1 and a half months';
		}
		active (minutes < 2 * TIME_MONTH): {
			ret = '2 months';
		}
		active (minutes <= 12 * TIME_MONTH): {
			ret = "itoa(minutes / TIME_MONTH), ' months'";
		}
		active (1): {
			ret = 'more than a year';
		}
	}
	*/
	ret = itoa(t2-t1);

	return ret;
}

/**
 * Get the
 */
 /**
 * Convert a delta between now and a passed time value into a human readable
 * (and easily understandable) string.
 *
 * @param	t			a unixtime time compare to
 * @return				a string containing the time difference between between
 *						now and 't'.
 */
define_function char[FUZZY_TIME_RETURN_SIZE] fuzzyTimeDelta(slong t) {
	return fuzzyTime(unixtime_now(), t);
}
