import { CUSTOM_DATE_RANGE_OPTION } from '~/observability/constants';
import { periodToDateRange, createIssueUrlWithDetails } from '~/observability/utils';
import { mergeUrlParams, setUrlParams, getNormalizedURL } from '~/lib/utils/url_utility';
import { tracingListQueryFromAttributes } from 'ee/tracing/list/filter_bar/filters';
import { METRIC_TYPE } from '../constants';
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

export function viewTracesUrlWithMetric(tracingIndexUrl, { traceIds, timestamp }) {
  const INTERVAL_AROUND_TIMESTAMP = 6 * 60 * 60 * 1000; // 6hrs;
  return setUrlParams(
    tracingListQueryFromAttributes({
      traceIds,
      ...(Number.isFinite(timestamp)
        ? {
            startTimestamp: timestamp - INTERVAL_AROUND_TIMESTAMP,
            endTimestamp: timestamp + INTERVAL_AROUND_TIMESTAMP,
          }
        : {}),
    }),
    getNormalizedURL(tracingIndexUrl),
    true, // clearParams
    true, // railsArraySyntax
    true, // decodeParams
  );
}

export function isHistogram(metricType) {
  return [METRIC_TYPE.ExponentialHistogram, METRIC_TYPE.Histogram].includes(
    metricType.toLowerCase(),
  );
}
