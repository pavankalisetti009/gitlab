import { queryToObject } from '~/lib/utils/url_utility';
import { formatDate, newDate } from '~/lib/utils/datetime_utility';
import { ISO_SHORT_FORMAT } from '~/vue_shared/constants';
import {
  convertObjectPropsToCamelCase,
  convertObjectPropsToSnakeCase,
  parseBoolean,
} from '~/lib/utils/common_utils';
import {
  DATE_RANGE_OPTIONS,
  DEFAULT_SELECTED_OPTION_INDEX,
  CUSTOM_DATE_RANGE_KEY,
} from './constants';

const isCustomOption = (option) => option && option === CUSTOM_DATE_RANGE_KEY;

export const getDateRangeOption = (optionKey) =>
  DATE_RANGE_OPTIONS.find(({ key }) => key === optionKey);

export const dateRangeOptionToFilter = ({ startDate, endDate, key }) => ({
  startDate,
  endDate,
  dateRangeOption: key,
});

const DEFAULT_FILTER = dateRangeOptionToFilter(DATE_RANGE_OPTIONS[DEFAULT_SELECTED_OPTION_INDEX]);

export const buildDefaultDashboardFilters = (queryString) => {
  const {
    dateRangeOption: optionKey,
    startDate,
    endDate,
    filterAnonUsers,
  } = convertObjectPropsToCamelCase(queryToObject(queryString, { gatherArrays: true }));

  const customDateRange = isCustomOption(optionKey);

  return {
    ...DEFAULT_FILTER,
    // Override default filter with user defined option
    ...(optionKey && dateRangeOptionToFilter(getDateRangeOption(optionKey))),
    // Override date range when selected option is custom date range
    ...(customDateRange && { startDate: newDate(startDate) }),
    ...(customDateRange && { endDate: newDate(endDate) }),
    filterAnonUsers: parseBoolean(filterAnonUsers),
  };
};

export const filtersToQueryParams = ({ dateRangeOption, startDate, endDate, filterAnonUsers }) => {
  const customDateRange = isCustomOption(dateRangeOption);

  return convertObjectPropsToSnakeCase({
    dateRangeOption,
    // Clear the date range unless the custom date range is selected
    startDate: customDateRange ? formatDate(startDate, ISO_SHORT_FORMAT) : null,
    endDate: customDateRange ? formatDate(endDate, ISO_SHORT_FORMAT) : null,
    // Clear the anon users filter unless truthy
    filterAnonUsers: filterAnonUsers || null,
  });
};
