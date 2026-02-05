import { dayAfter } from '~/lib/utils/datetime_utility';
import { queryThroughputData } from 'ee/analytics/merge_request_analytics/api';
import {
  computeMttmData,
  filterToMRThroughputQueryObject,
} from 'ee/analytics/merge_request_analytics/utils';
import {
  DATE_RANGE_OPTION_LAST_365_DAYS,
  DATE_RANGE_OPTIONS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

export default async function fetch({
  namespace,
  query: { dateRange = DATE_RANGE_OPTION_LAST_365_DAYS } = {},
  queryOverrides = {},
  filters: { startDate: filtersStartDate, endDate: filtersEndDate, searchFilters } = {},
}) {
  const { startDate, endDate } = DATE_RANGE_OPTIONS[dateRange]
    ? DATE_RANGE_OPTIONS[dateRange]
    : DATE_RANGE_OPTIONS[DATE_RANGE_OPTION_LAST_365_DAYS];

  const rawData = await queryThroughputData({
    namespace,
    startDate: filtersStartDate ?? startDate,
    endDate: filtersEndDate ?? dayAfter(endDate, { utc: true }),
    ...filterToMRThroughputQueryObject(searchFilters),
    ...queryOverrides,
  });

  const { value = 0 } = computeMttmData(rawData);
  return value;
}
