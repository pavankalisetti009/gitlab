import {
  BUCKETING_INTERVAL_ALL,
  BUCKETING_INTERVAL_MONTHLY,
  BUCKETING_INTERVAL_DAILY,
} from '~/analytics/shared/graphql/constants';
import DoraMetricsQuery from '~/analytics/shared/graphql/dora_metrics.query.graphql';
import { extractQueryResponseFromNamespace, scaledValueForDisplay } from '~/analytics/shared/utils';
import { VALUE_STREAM_METRIC_TILE_METADATA } from '~/analytics/shared/constants';
import { TABLE_METRICS } from 'ee/analytics/dashboards/constants';
import { DORA_METRICS_CHARTS_ADDITIONAL_OPTS } from 'ee/analytics/analytics_dashboards/constants';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  DATE_RANGE_OPTION_KEYS,
  DATE_RANGE_OPTIONS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { getStartDate } from 'ee/analytics/analytics_dashboards/components/filters/utils';
import { startOfTomorrow } from 'ee/dora/components/static_data/shared';
import { defaultClient } from '../graphql/client';

const asValue = ({ metrics, targetMetric, units }) => {
  if (!metrics.length) return '-';

  const metricValue = metrics[0][targetMetric] || 0;
  return scaledValueForDisplay(metricValue, units);
};

const asTimeSeries = ({ metrics, targetMetric }) => {
  // Extracts a date + value, returns an array of arrays [[date, value],[date, value]]
  const data = metrics.map(({ date, ...rest }) => {
    return [date, rest[targetMetric]];
  });

  return [{ name: VALUE_STREAM_METRIC_TILE_METADATA[targetMetric].label, data }];
};

const fetchDoraMetricsQuery = async ({ metric, namespace, startDate, endDate, interval }) => {
  const result = await defaultClient.query({
    query: DoraMetricsQuery,
    variables: {
      fullPath: namespace,
      interval,
      startDate,
      endDate,
    },
  });

  const { metrics } = extractQueryResponseFromNamespace({ result, resultKey: 'dora' });
  const { units } = TABLE_METRICS[metric];

  if ([BUCKETING_INTERVAL_DAILY, BUCKETING_INTERVAL_MONTHLY].includes(interval)) {
    return asTimeSeries({ metrics, targetMetric: metric });
  }

  return asValue({ metrics, targetMetric: metric, units });
};

export default async function fetch({
  namespace,
  query: {
    metric,
    dateRange: defaultDateRange = DATE_RANGE_OPTION_LAST_180_DAYS,
    interval = BUCKETING_INTERVAL_ALL,
  },
  queryOverrides: { dateRange: dateRangeOverride = null, ...overridesRest } = {},
  filters: {
    dateRangeOption,
    startDate: filtersStartDate = null,
    endDate: filtersEndDate = null,
  } = {},
  setVisualizationOverrides = () => {},
}) {
  let dateRangeKey = dateRangeOption || dateRangeOverride || defaultDateRange;
  if (!DATE_RANGE_OPTION_KEYS.includes(dateRangeKey)) {
    // Default to 180 days if an invalid date range is given
    dateRangeKey = DATE_RANGE_OPTION_LAST_180_DAYS;
  }

  const startDate = getStartDate(dateRangeKey);

  if (interval === BUCKETING_INTERVAL_ALL) {
    const title = DATE_RANGE_OPTIONS[dateRangeKey].text;
    const visualizationOptionOverrides = {
      ...(title && {
        titleIcon: 'clock',
        title,
      }),
    };

    setVisualizationOverrides({ visualizationOptionOverrides });
  } else {
    setVisualizationOverrides({
      visualizationOptionOverrides: DORA_METRICS_CHARTS_ADDITIONAL_OPTS[metric],
    });
  }

  return fetchDoraMetricsQuery({
    startDate: filtersStartDate ?? startDate,
    endDate: filtersEndDate ?? startOfTomorrow,
    metric,
    namespace,
    interval,
    ...overridesRest,
  });
}
