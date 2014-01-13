PROGRAM_NAME='TimeUtil'


#INCLUDE 'Unixtime';
#INCLUDE 'Math';


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
	stack_var long delta;
	stack_var char ret[FUZZY_TIME_RETURN_SIZE];

	delta = abs_value(t2 - t1);

	select {
		active (delta <= 30): {
			ret = 'a few moments';
		}
		active (delta <= 1 * UNIXTIME_SECONDS_PER_MINUTE): {
			ret = '1 minute';
		}
		active (delta <= 25 * UNIXTIME_SECONDS_PER_MINUTE): {
			ret = "itoa(ceil(1.0 * delta / UNIXTIME_SECONDS_PER_MINUTE)), ' minutes'";
		}
		active (delta <= 40 * UNIXTIME_SECONDS_PER_MINUTE): {
			ret = 'half an hour';
		}
		active (delta < 80 * UNIXTIME_SECONDS_PER_MINUTE): {
			ret = '1 hour';
		}
		active (delta <  105 * UNIXTIME_SECONDS_PER_MINUTE): {
			ret = '1 and a half hours';
		}
		active (delta < 20 * UNIXTIME_SECONDS_PER_HOUR): {
			ret = "itoa(ceil(1.0 * delta / UNIXTIME_SECONDS_PER_HOUR)), ' hours'";
		}
		active (delta < 30 * UNIXTIME_SECONDS_PER_HOUR): {
			ret = '1 day';
		}
		active (delta < 40 * UNIXTIME_SECONDS_PER_HOUR): {
			ret = '1 and a half days';
		}
		active (delta < 2 * UNIXTIME_SECONDS_PER_DAY): {
			ret = '2 days';
		}
		active (delta < 30 * UNIXTIME_SECONDS_PER_DAY): {
			ret = "itoa(ceil(1.0 * delta / UNIXTIME_SECONDS_PER_DAY)), ' days'";
		}
		active (delta < 40 * UNIXTIME_SECONDS_PER_DAY): {
			ret = '1 month';
		}
		active (delta < 50 * UNIXTIME_SECONDS_PER_DAY): {
			ret = '1 and a half months';
		}
		active (delta < 2 * (UNIXTIME_SECONDS_PER_YEAR / 12)): {
			ret = '2 months';
		}
		active (delta <= 12 * (UNIXTIME_SECONDS_PER_YEAR / 12)): {
			ret = "itoa(ceil(1.0 * delta / (UNIXTIME_SECONDS_PER_YEAR / 12))), ' months'";
		}
		active (1): {
			ret = 'more than a year';
		}
	}

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
