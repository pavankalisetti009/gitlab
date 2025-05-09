import { queryThroughputData } from 'ee/analytics/merge_request_analytics/api';
import { computeMttmData } from 'ee/analytics/merge_request_analytics/utils';
import { startOfTomorrow } from 'ee/analytics/dora/components/static_data/shared';
import { getStartDate } from 'ee/analytics/analytics_dashboards/components/filters/utils';
import {
  DATE_RANGE_OPTION_LAST_365_DAYS,
  DATE_RANGE_OPTION_KEYS,
  DATE_RANGE_OPTIONS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

export default async function fetch({
  namespace,
  query: { dateRange: defaultDateRange = DATE_RANGE_OPTION_LAST_365_DAYS } = {},
  queryOverrides = {},
  filters: { dateRangeOption, startDate: filtersStartDate, endDate = startOfTomorrow } = {},
  setVisualizationOverrides = () => {},
}) {
  const startDate = filtersStartDate || getStartDate(defaultDateRange);
  const rawData = await queryThroughputData({ namespace, startDate, endDate, ...queryOverrides });

  let dateRangeKey = dateRangeOption || defaultDateRange;
  if (!DATE_RANGE_OPTION_KEYS.includes(dateRangeKey)) {
    // Default to 365 days if an invalid date range is given
    dateRangeKey = DATE_RANGE_OPTION_LAST_365_DAYS;
  }

  const title = DATE_RANGE_OPTIONS[dateRangeKey].text;
  const visualizationOptionOverrides = {
    titleIcon: 'clock',
    title,
  };

  setVisualizationOverrides({ visualizationOptionOverrides });

  const { value = 0 } = computeMttmData(rawData);
  return value;
}
