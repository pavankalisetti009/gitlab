import { __, sprintf } from '~/locale';
import {
  dayAfter,
  nDaysBefore,
  nMonthsBefore,
  getDateInPast,
  getStartOfDay,
} from '~/lib/utils/datetime_utility';
import {
  OPERATORS_IS,
  OPERATORS_IS_NOT,
  OPERATORS_IS_NOT_OR,
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_SOURCE_BRANCH,
  TOKEN_TYPE_TARGET_BRANCH,
} from '~/vue_shared/components/filtered_search_bar/constants';

/* eslint-disable @gitlab/require-i18n-strings */
export const LAST_WEEK = 'LAST_WEEK';
export const LAST_MONTH = 'LAST_MONTH';
export const LAST_30_DAYS = 'LAST_30_DAYS';
export const LAST_90_DAYS = 'LAST_90_DAYS';
export const LAST_180_DAYS = 'LAST_180_DAYS';
/* eslint-enable @gitlab/require-i18n-strings */

// Compute all relative dates based on the _beginning_ of today.
// We use this date as the end date for the charts. This causes
// the current date to be the last day included in the graph.
const startOfToday = getStartOfDay(new Date(), { utc: true });

// We use this date as the "to" parameter for the API. This allows
// us to get DORA 4 metrics about the current day.
export const startOfTomorrow = dayAfter(startOfToday, { utc: true });

const lastWeek = nDaysBefore(startOfTomorrow, 7, { utc: true });
const lastMonth = nMonthsBefore(startOfTomorrow, 1, { utc: true });
const last30Days = nDaysBefore(startOfTomorrow, 30, { utc: true });
const last90Days = nDaysBefore(startOfTomorrow, 90, { utc: true });
const last180Days = nDaysBefore(startOfTomorrow, 180, { utc: true });

export const DORA_METRIC_QUERY_RANGES = {
  LAST_WEEK: lastWeek,
  LAST_MONTH: lastMonth,
  LAST_30_DAYS: last30Days,
  LAST_90_DAYS: last90Days,
  LAST_180_DAYS: last180Days,
};

export const TODAY = startOfToday;
export const SEVEN_DAYS_AGO = getDateInPast(TODAY, 7);

export const DATE_RANGE_OPTION_TODAY = 'today';
export const DATE_RANGE_OPTION_LAST_7_DAYS = '7d';
export const DATE_RANGE_OPTION_LAST_30_DAYS = '30d';
export const DATE_RANGE_OPTION_LAST_60_DAYS = '60d';
export const DATE_RANGE_OPTION_LAST_90_DAYS = '90d';
export const DATE_RANGE_OPTION_LAST_180_DAYS = '180d';
export const DATE_RANGE_OPTION_LAST_365_DAYS = '365d';
export const DATE_RANGE_OPTION_CUSTOM = 'custom';

export const DEFAULT_DATE_RANGE_OPTIONS = [
  DATE_RANGE_OPTION_LAST_30_DAYS,
  DATE_RANGE_OPTION_LAST_7_DAYS,
  DATE_RANGE_OPTION_TODAY,
  DATE_RANGE_OPTION_CUSTOM,
];

export const DEFAULT_SELECTED_DATE_RANGE_OPTION = DATE_RANGE_OPTION_LAST_7_DAYS;

/**
 * The default options to display in the date_range_filter.
 *
 * Each options consists of:
 *
 * key - The key used to select the option and sync with the URL
 * text - Text to display in the dropdown item
 * startDate - Optional, the start date to set
 * endDate - Optional, the end date to set
 * showDateRangePicker - Optional, show the date range picker component and uses
 *                       it to set the date.
 */
export const DATE_RANGE_OPTIONS = {
  [DATE_RANGE_OPTION_LAST_365_DAYS]: {
    key: DATE_RANGE_OPTION_LAST_365_DAYS,
    text: sprintf(__('Last %{days} days'), { days: 365 }),
    startDate: nDaysBefore(TODAY, 365, { utc: true }),
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_LAST_180_DAYS]: {
    key: DATE_RANGE_OPTION_LAST_180_DAYS,
    text: sprintf(__('Last %{days} days'), { days: 180 }),
    startDate: nDaysBefore(TODAY, 180, { utc: true }),
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_LAST_90_DAYS]: {
    key: DATE_RANGE_OPTION_LAST_90_DAYS,
    text: sprintf(__('Last %{days} days'), { days: 90 }),
    startDate: nDaysBefore(TODAY, 90, { utc: true }),
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_LAST_60_DAYS]: {
    key: DATE_RANGE_OPTION_LAST_60_DAYS,
    text: sprintf(__('Last %{days} days'), { days: 60 }),
    startDate: nDaysBefore(TODAY, 60, { utc: true }),
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_LAST_30_DAYS]: {
    key: DATE_RANGE_OPTION_LAST_30_DAYS,
    text: sprintf(__('Last %{days} days'), { days: 30 }),
    startDate: nDaysBefore(TODAY, 30, { utc: true }),
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_LAST_7_DAYS]: {
    key: DATE_RANGE_OPTION_LAST_7_DAYS,
    text: sprintf(__('Last %{days} days'), { days: 7 }),
    startDate: SEVEN_DAYS_AGO,
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_TODAY]: {
    key: DATE_RANGE_OPTION_TODAY,
    text: __('Today'),
    startDate: TODAY,
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_CUSTOM]: {
    key: DATE_RANGE_OPTION_CUSTOM,
    text: __('Custom range'),
    showDateRangePicker: true,
  },
};

export const DATE_RANGE_OPTION_KEYS = Object.keys(DATE_RANGE_OPTIONS);

export const START_DATES = {
  [DATE_RANGE_OPTION_TODAY]: nDaysBefore(startOfTomorrow, 1, { utc: true }),
  [DATE_RANGE_OPTION_LAST_7_DAYS]: nDaysBefore(startOfTomorrow, 7, { utc: true }),
  [DATE_RANGE_OPTION_LAST_30_DAYS]: nDaysBefore(startOfTomorrow, 30, { utc: true }),
  [DATE_RANGE_OPTION_LAST_60_DAYS]: nDaysBefore(startOfTomorrow, 60, { utc: true }),
  [DATE_RANGE_OPTION_LAST_90_DAYS]: nDaysBefore(startOfTomorrow, 90, { utc: true }),
  [DATE_RANGE_OPTION_LAST_180_DAYS]: nDaysBefore(startOfTomorrow, 180, { utc: true }),
  [DATE_RANGE_OPTION_LAST_365_DAYS]: nDaysBefore(startOfTomorrow, 365, { utc: true }),
};

export const FILTERED_SEARCH_SUPPORTED_TOKENS = [
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_SOURCE_BRANCH,
  TOKEN_TYPE_TARGET_BRANCH,
];

export const FILTERED_SEARCH_MAX_LABELS = 100;

export const FILTERED_SEARCH_OPERATOR_IS = 'is';
export const FILTERED_SEARCH_OPERATOR_IS_NOT = 'is_not';
export const FILTERED_SEARCH_OPERATOR_IS_NOT_OR = 'is_not_or';

export const FILTERED_SEARCH_OPERATORS = {
  [FILTERED_SEARCH_OPERATOR_IS]: OPERATORS_IS,
  [FILTERED_SEARCH_OPERATOR_IS_NOT]: OPERATORS_IS_NOT,
  [FILTERED_SEARCH_OPERATOR_IS_NOT_OR]: OPERATORS_IS_NOT_OR,
};

export const FILTERED_SEARCH_PROJECT_ONLY_TOKENS = [
  TOKEN_TYPE_SOURCE_BRANCH,
  TOKEN_TYPE_TARGET_BRANCH,
];

export const PROJECT_FILTER_QUERY_NAME = 'project';
