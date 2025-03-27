import { __ } from '~/locale';
import { getWeekdayNames } from '~/lib/utils/datetime_utility';
import { DAILY, HOUR_IN_SECONDS } from '../constants';

const DAY_IN_SECONDS = HOUR_IN_SECONDS * 24;
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

const CADENCE_CONFIG = {
  [DAILY]: {
    time_window: { value: HOUR_IN_SECONDS },
  },
  [WEEKLY]: {
    days: DEFAULT_START_WEEKDAY,
    time_window: { value: DAY_IN_SECONDS },
  },
  [MONTHLY]: {
    days_of_month: [DEFAULT_START_MONTH_DAY],
    time_window: { value: DAY_IN_SECONDS },
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
