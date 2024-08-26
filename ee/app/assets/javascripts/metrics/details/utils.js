import { CUSTOM_DATE_RANGE_OPTION } from '~/observability/constants';
import { periodToDateRange, createIssueUrlWithDetails } from '~/observability/utils';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import { filterObjToQuery } from './filters';

export function createIssueUrlWithMetricDetails({
  metricName,
  metricType,
  filters,
  createIssueUrl,
}) {
  const absoluteDateRange =
    filters.dateRange.value === CUSTOM_DATE_RANGE_OPTION
      ? filters.dateRange
      : periodToDateRange(filters.dateRange.value);

  const queryWithUpdatedDateRange = filterObjToQuery({
    ...filters,
    dateRange: absoluteDateRange,
  });

  const metricsDetails = {
    fullUrl: mergeUrlParams(queryWithUpdatedDateRange, window.location.href, {
      spreadArrays: true,
    }),
    name: metricName,
    type: metricType,
    timeframe: [absoluteDateRange.startDate.toUTCString(), absoluteDateRange.endDate.toUTCString()],
  };

  return createIssueUrlWithDetails(createIssueUrl, metricsDetails, 'observability_metric_details');
}
