import { __, sprintf } from '~/locale';
import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import {
  AI_IMPACT_OVER_TIME_METRICS,
  AI_IMPACT_OVER_TIME_METRICS_TOOLTIPS,
} from 'ee/analytics/dashboards/ai_impact/constants';
import { calculateRate } from 'ee/analytics/dashboards/ai_impact/utils';
import {
  DATE_RANGE_OPTION_LAST_30_DAYS,
  DATE_RANGE_OPTIONS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { toISODateFormat } from '~/lib/utils/datetime_utility';
import { AI_METRICS } from '~/analytics/shared/constants';
import { scaledValueForDisplay, extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { defaultClient } from '../graphql/client';

const DATE_RANGE_TITLES = {
  [DATE_RANGE_OPTION_LAST_30_DAYS]: sprintf(__('Last %{days} days'), { days: 30 }),
};

const extractMetricData = ({ metric, rawQueryResult: result }) => {
  const resp = extractQueryResponseFromNamespace({
    result,
    resultKey: 'aiMetrics',
  });

  const tooltip = AI_IMPACT_OVER_TIME_METRICS_TOOLTIPS[metric];

  switch (metric) {
    case AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE: {
      const {
        codeSuggestions: { contributorsCount: codeSuggestionsContributorsCount },
        codeContributorsCount,
      } = resp;
      return {
        rate: calculateRate({
          numerator: codeSuggestionsContributorsCount,
          denominator: codeContributorsCount,
        }),
        tooltip,
      };
    }

    case AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE: {
      const {
        codeSuggestions: { acceptedCount, shownCount },
      } = resp;
      return {
        rate: calculateRate({
          numerator: acceptedCount,
          denominator: shownCount,
        }),
        tooltip,
      };
    }

    case AI_METRICS.DUO_CHAT_USAGE_RATE: {
      const { duoChatContributorsCount, duoAssignedUsersCount } = resp;
      return {
        rate: calculateRate({
          numerator: duoChatContributorsCount,
          denominator: duoAssignedUsersCount,
        }),
        tooltip,
      };
    }

    case AI_METRICS.DUO_USAGE_RATE: {
      const { duoUsedCount, duoAssignedUsersCount } = resp;
      return {
        rate: calculateRate({
          numerator: duoUsedCount,
          denominator: duoAssignedUsersCount,
        }),
        tooltip,
      };
    }

    default:
      return { rate: null, tooltip: null };
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

  const { rate, tooltip } = extractMetricData({ metric, rawQueryResult });

  if (rate === null)
    return {
      rate: '-',
      tooltip,
    };

  const { units } = AI_IMPACT_OVER_TIME_METRICS[metric];

  return {
    // scaledValueForDisplay expects a value between 0 -> 1
    rate: scaledValueForDisplay(rate / 100, units),
    tooltip,
  };
};

export default async function fetch({
  namespace,
  query: { metric, dateRange = DATE_RANGE_OPTION_LAST_30_DAYS },
  queryOverrides: { dateRange: dateRangeOverride = null, ...overridesRest } = {},
  setVisualizationOverrides = () => {},
}) {
  const dateRangeKey = dateRangeOverride || dateRange;

  // Default to 30 days if an invalid date range is given
  const { startDate, endDate } = DATE_RANGE_OPTIONS[dateRangeKey]
    ? DATE_RANGE_OPTIONS[dateRangeKey]
    : DATE_RANGE_OPTIONS[DATE_RANGE_OPTION_LAST_30_DAYS];

  const { rate, tooltip } = await fetchAiImpactQuery({
    startDate: toISODateFormat(startDate, true),
    endDate: toISODateFormat(endDate, true),
    metric,
    namespace,
    ...overridesRest,
  });

  const visualizationOptionOverrides = {
    ...(DATE_RANGE_TITLES[dateRangeKey] && {
      title: DATE_RANGE_TITLES[dateRangeKey],
    }),
    tooltip,
  };

  setVisualizationOverrides({ visualizationOptionOverrides });

  return rate;
}
