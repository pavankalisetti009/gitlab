import { queryThroughputData } from 'ee/analytics/merge_request_analytics/api';
import { formatThroughputChartData } from 'ee/analytics/merge_request_analytics/utils';
import { startOfTomorrow } from 'ee/analytics/dora/components/static_data/shared';
import { getStartDate } from 'ee/analytics/analytics_dashboards/components/filters/utils';
import { DATE_RANGE_OPTION_LAST_365_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';

const responseHasAnyData = (rawData) =>
  Object.values(rawData).some(({ totalTimeToMerge, count }) => totalTimeToMerge || count);

export default async function fetch({
  namespace,
  query: { dateRange: defaultDateRange = DATE_RANGE_OPTION_LAST_365_DAYS },
  queryOverrides = {},
  filters: { startDate: filtersStartDate, endDate = startOfTomorrow } = {},
}) {
  const startDate = filtersStartDate || getStartDate(defaultDateRange);
  const rawData = await queryThroughputData({ namespace, startDate, endDate, ...queryOverrides });

  if (!responseHasAnyData(rawData)) {
    // return an empty object so the correct dashboard "empty state" is rendered
    return {};
  }

  return formatThroughputChartData(rawData);
}
