import { __, sprintf } from '~/locale';
import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import { AI_IMPACT_OVER_TIME_METRICS } from 'ee/analytics/dashboards/ai_impact/constants';
import { calculateRate } from 'ee/analytics/dashboards/ai_impact/utils';
import {
  extractQueryResponseFromNamespace,
  scaledValueForDisplay,
} from 'ee/analytics/dashboards/api';
import {
  LAST_30_DAYS,
  LAST_180_DAYS,
  DORA_METRIC_QUERY_RANGES,
  startOfTomorrow,
} from 'ee/dora/components/static_data/shared';
import { AI_METRICS } from '~/analytics/shared/constants';
import { defaultClient } from '../graphql/client';

const DATE_RANGE_TITLES = { [LAST_30_DAYS]: sprintf(__('Last %{days} days'), { days: 30 }) };

const extractMetricRateValue = ({ metric, rawQueryResult: result }) => {
  const resp = extractQueryResponseFromNamespace({
    result,
    resultKey: 'aiMetrics',
  });

  switch (metric) {
    case AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE: {
      const { codeSuggestionsContributorsCount, codeContributorsCount } = resp;
      return calculateRate({
        numerator: codeSuggestionsContributorsCount,
        denominator: codeContributorsCount,
      });
    }

    case AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE: {
      const { codeSuggestionsAcceptedCount, codeSuggestionsShownCount } = resp;
      return calculateRate({
        numerator: codeSuggestionsAcceptedCount,
        denominator: codeSuggestionsShownCount,
      });
    }

    case AI_METRICS.DUO_PRO_USAGE_RATE: {
      const { duoChatContributorsCount, duoProAssignedUsersCount } = resp;
      return calculateRate({
        numerator: duoChatContributorsCount,
        denominator: duoProAssignedUsersCount,
      });
    }

    default:
      return null;
  }
};

const fetchAiImpactQuery = async ({ metric, namespace, startDate, endDate }) => {
  const rawQueryResult = await defaultClient.query({
    query: AiMetricsQuery,
    variables: {
      fullPath: namespace,
      startDate,
      endDate,
    },
  });

  const rate = extractMetricRateValue({ metric, rawQueryResult });
  if (rate) {
    const { units } = AI_IMPACT_OVER_TIME_METRICS[metric];

    // scaledValueForDisplay expects a value between 0 -> 1
    return scaledValueForDisplay(rate / 100, units);
  }
  return null;
};

export default async function fetch({
  namespace,
  query: { metric, dateRange = LAST_180_DAYS },
  queryOverrides: { dateRange: dateRangeOverride = null, ...overridesRest } = {},
  setVisualizationOverrides = () => {},
}) {
  const dateRangeKey = dateRangeOverride
    ? dateRangeOverride.toUpperCase()
    : dateRange.toUpperCase();

  // Default to 180 days if an invalid date range is given
  const startDate = DORA_METRIC_QUERY_RANGES[dateRangeKey]
    ? DORA_METRIC_QUERY_RANGES[dateRangeKey]
    : DORA_METRIC_QUERY_RANGES[LAST_180_DAYS];

  const visualizationOptionOverrides = DATE_RANGE_TITLES[dateRangeKey]
    ? {
        titleIcon: 'clock',
        title: DATE_RANGE_TITLES[dateRangeKey],
      }
    : {};

  setVisualizationOverrides({ visualizationOptionOverrides });

  return fetchAiImpactQuery({
    startDate,
    endDate: startOfTomorrow,
    metric,
    namespace,
    ...overridesRest,
  });
}
