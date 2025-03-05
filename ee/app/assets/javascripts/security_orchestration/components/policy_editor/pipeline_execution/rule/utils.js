import { __ } from '~/locale';
import { DAILY, HOUR_IN_SECONDS } from '../constants';

const DAY_IN_SECONDS = HOUR_IN_SECONDS * 24;
const DEFAULT_START_TIME = '00:00';
const DEFAULT_START_WEEKDAY = 'monday';
const DEFAULT_START_MONTH_DAY = '1';
const WEEKLY = 'weekly';
const MONTHLY = 'monthly';

export const CADENCE_OPTIONS = [
  { value: DAILY, text: __('Daily') },
  { value: WEEKLY, text: __('Weekly') },
  { value: MONTHLY, text: __('Monthly') },
];

const CADENCE_CONFIG = {
  [DAILY]: {
    start_time: DEFAULT_START_TIME,
    time_window: { value: HOUR_IN_SECONDS },
  },
  [WEEKLY]: {
    days: DEFAULT_START_WEEKDAY,
    time_window: { value: DAY_IN_SECONDS },
  },
  [MONTHLY]: {
    days_of_month: DEFAULT_START_MONTH_DAY,
    time_window: { value: DAY_IN_SECONDS },
  },
};

export const updateScheduleCadence = ({ schedule, cadence }) => {
  const { start_time, days, days_of_month, ...updatedSchedule } = schedule;
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
