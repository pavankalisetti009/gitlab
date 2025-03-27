import { __ } from '~/locale';
import { getWeekdayNames } from '~/lib/utils/datetime_utility';
import { DAILY } from '../constants';

const DEFAULT_START_WEEKDAY = 'monday';
const DEFAULT_START_MONTH_DAY = 1;
const WEEKLY = 'weekly';
const MONTHLY = 'monthly';

export const isCadenceWeekly = (cadence) => cadence === WEEKLY;
export const isCadenceMonthly = (cadence) => cadence === MONTHLY;

export const CADENCE_OPTIONS = [
  { value: DAILY, text: __('Daily') },
  { value: WEEKLY, text: __('Weekly') },
  { value: MONTHLY, text: __('Monthly') },
];

// Constants for time units in seconds
export const TIME_UNITS = {
  MINUTE: 60,
  HOUR: 3600,
  DAY: 86400, // 24 hours * 60 minutes * 60 seconds
};

export const TIME_UNIT_OPTIONS = [
  { value: TIME_UNITS.MINUTE, text: __('Minutes') },
  { value: TIME_UNITS.HOUR, text: __('Hours') },
  { value: TIME_UNITS.DAY, text: __('Days') },
];

const CADENCE_CONFIG = {
  [DAILY]: {
    time_window: { value: TIME_UNITS.MINUTE },
  },
  [WEEKLY]: {
    days: DEFAULT_START_WEEKDAY,
    time_window: { value: TIME_UNITS.DAY },
  },
  [MONTHLY]: {
    days_of_month: [DEFAULT_START_MONTH_DAY],
    time_window: { value: TIME_UNITS.DAY },
  },
};

export const updateScheduleCadence = ({ schedule, cadence }) => {
  const { days, days_of_month, ...updatedSchedule } = schedule;
  updatedSchedule.type = cadence;

  if (CADENCE_CONFIG[cadence]) {
    Object.assign(updatedSchedule, {
      ...CADENCE_CONFIG[cadence],
      time_window: {
        ...updatedSchedule.time_window,
        value: CADENCE_CONFIG[cadence].time_window.value,
      },
    });
  }

  return updatedSchedule;
};

/**
 * Time options in one hour increments for the daily scheduler
 * @returns {Array} Array of time options
 */
export const HOUR_MINUTE_LIST = Array.from(Array(24).keys()).map((num) => {
  const hour = num.toString().length === 1 ? `0${num}:00` : `${num}:00`;
  return { value: hour, text: hour };
});

/**
 * Weekday options for the weekly scheduler
 * @returns {Array} Array of weekday options
 */
export const WEEKDAY_OPTIONS = getWeekdayNames().map((day) => {
  return { value: day.toLowerCase(), text: day };
});

/**
 * Generate options for monthly day selection
 * @returns {Array} Array of day options
 */
export const getMonthlyDayOptions = () => {
  return Array.from({ length: 31 }, (_, i) => {
    const day = i + 1;
    return { value: day, text: day };
  });
};

/**
 * Converts a value and time unit to seconds
 * @param {Number} value - The numeric value
 * @param {Number} unit - The time unit in seconds (from TIME_UNITS)
 * @returns {Number} Total seconds
 */
export const timeUnitToSeconds = (value, unit) => {
  return value * unit;
};

/**
 * Converts seconds to a value in the specified unit
 * @param {Number} seconds
 * @param {Number} unit - The time unit to convert to
 * @returns {Number} Value in the specified unit
 */
export const secondsToValue = (seconds, unit) => {
  return seconds / unit;
};

/**
 * Determines the most appropriate time unit for a given number of seconds
 * @param {Number} seconds
 * @returns {Number} The appropriate time unit from TIME_UNITS
 */
export const determineTimeUnit = (seconds) => {
  if (seconds % TIME_UNITS.DAY === 0 && seconds >= TIME_UNITS.DAY) {
    return TIME_UNITS.DAY;
  }
  if (seconds % TIME_UNITS.HOUR === 0 && seconds >= TIME_UNITS.HOUR) {
    return TIME_UNITS.HOUR;
  }
  return TIME_UNITS.MINUTE;
};
