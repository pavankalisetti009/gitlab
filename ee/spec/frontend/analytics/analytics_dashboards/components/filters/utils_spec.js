import { newDate } from '~/lib/utils/datetime_utility';
import {
  buildDefaultDashboardFilters,
  dateRangeOptionToFilter,
  filtersToQueryParams,
  getDateRangeOption,
} from 'ee/analytics/analytics_dashboards/components/filters/utils';
import {
  DATE_RANGE_OPTIONS,
  DEFAULT_SELECTED_OPTION_INDEX,
  CUSTOM_DATE_RANGE_KEY,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { mockDateRangeFilterChangePayload } from '../../mock_data';

const option = DATE_RANGE_OPTIONS[0];
describe('buildDefaultDashboardFilters', () => {
  it('returns the default option for an empty query string', () => {
    const defaultOption = DATE_RANGE_OPTIONS[DEFAULT_SELECTED_OPTION_INDEX];

    expect(buildDefaultDashboardFilters('')).toStrictEqual({
      startDate: defaultOption.startDate,
      endDate: defaultOption.endDate,
      dateRangeOption: defaultOption.key,
      filterAnonUsers: false,
    });
  });

  it('returns the option that matches the date_range_option', () => {
    const queryString = `date_range_option=${option.key}`;

    expect(buildDefaultDashboardFilters(queryString)).toStrictEqual({
      startDate: option.startDate,
      endDate: option.endDate,
      dateRangeOption: option.key,
      filterAnonUsers: false,
    });
  });

  it('returns the a custom range when the query string is custom and contains dates', () => {
    const queryString = `date_range_option=${CUSTOM_DATE_RANGE_KEY}&start_date=2023-01-10&end_date=2023-02-08`;

    expect(buildDefaultDashboardFilters(queryString)).toStrictEqual({
      startDate: newDate('2023-01-10'),
      endDate: newDate('2023-02-08'),
      dateRangeOption: CUSTOM_DATE_RANGE_KEY,
      filterAnonUsers: false,
    });
  });

  it('returns the option that matches the date_range_option and ignores the query dates when the option is not custom', () => {
    const queryString = `date_range_option=${option.key}&start_date=2023-01-10&end_date=2023-02-08`;

    expect(buildDefaultDashboardFilters(queryString)).toStrictEqual({
      startDate: option.startDate,
      endDate: option.endDate,
      dateRangeOption: option.key,
      filterAnonUsers: false,
    });
  });

  it('returns "filterAnonUsers=true" when the query param for filtering out anonymous users is true', () => {
    const queryString = 'filter_anon_users=true';

    expect(buildDefaultDashboardFilters(queryString)).toMatchObject({
      filterAnonUsers: true,
    });
  });
});

describe('filtersToQueryParams', () => {
  const customOption = {
    ...mockDateRangeFilterChangePayload,
    dateRangeOption: CUSTOM_DATE_RANGE_KEY,
  };

  const nonCustomOption = {
    ...mockDateRangeFilterChangePayload,
    dateRangeOption: 'foobar',
  };

  it('returns the dateRangeOption with null date params when the option is not custom', () => {
    expect(filtersToQueryParams(nonCustomOption)).toStrictEqual({
      date_range_option: 'foobar',
      end_date: null,
      start_date: null,
      filter_anon_users: null,
    });
  });

  it('returns the dateRangeOption and date params when the option is custom', () => {
    expect(filtersToQueryParams(customOption)).toStrictEqual({
      date_range_option: CUSTOM_DATE_RANGE_KEY,
      start_date: '2016-01-01',
      end_date: '2016-02-01',
      filter_anon_users: null,
    });
  });

  it('returns "filter_anon_users=true" when filtering out anonymous users', () => {
    expect(filtersToQueryParams({ filterAnonUsers: true })).toMatchObject({
      filter_anon_users: true,
    });
  });
});

describe('getDateRangeOption', () => {
  it('should return the date range option', () => {
    expect(getDateRangeOption(option.key)).toStrictEqual(option);
  });
});

describe('dateRangeOptionToFilter', () => {
  it('filters data by `name` for the provided search term', () => {
    expect(dateRangeOptionToFilter(option)).toStrictEqual({
      startDate: option.startDate,
      endDate: option.endDate,
      dateRangeOption: option.key,
    });
  });
});
