import { orderBy } from 'lodash';
import { secondsToMinutes } from '~/lib/utils/datetime/date_calculation_utility';
import AiAgentPlatformFlowMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_agent_platform_flow_metrics.query.graphql';
import {
  DATE_RANGE_OPTION_LAST_30_DAYS,
  DATE_RANGE_OPTIONS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { toISODateFormat } from '~/lib/utils/datetime_utility';
import { defaultClient } from '../graphql/client';

const requestFlowMetrics = async ({ namespace, startDate, endDate, sortBy, sortDesc = false }) => {
  const result = await defaultClient.query({
    query: AiAgentPlatformFlowMetricsQuery,
    variables: {
      fullPath: namespace,
      startDate,
      endDate,
    },
  });

  const {
    agentPlatform: { flowMetrics },
  } = extractQueryResponseFromNamespace({
    result,
    resultKey: 'aiMetrics',
  });

  // By default null values are sorted last in ASC order, but for better
  // usability we want them to be sorted last for both ASC or DESC.
  const nullSortValue = sortDesc ? Number.NEGATIVE_INFINITY : Number.POSITIVE_INFINITY;
  const nodes = sortBy
    ? orderBy(
        flowMetrics,
        (metric) => (metric[sortBy] !== null ? metric[sortBy] : nullSortValue),
        sortDesc ? 'desc' : 'asc',
      )
    : flowMetrics;
  return nodes.map(({ medianExecutionTime, ...rest }) => ({
    medianExecutionTime:
      medianExecutionTime !== null ? secondsToMinutes(medianExecutionTime) : null,
    ...rest,
  }));
};

export default async function fetch({
  namespace,
  query: { dateRange = DATE_RANGE_OPTION_LAST_30_DAYS } = {},
  queryOverrides: { dateRange: dateRangeOverride = null, ...overridesRest } = {},
}) {
  // Default to 30 days if an invalid date range is given
  const dateRangeKey = dateRangeOverride ?? dateRange;
  const { startDate, endDate } = DATE_RANGE_OPTIONS[dateRangeKey]
    ? DATE_RANGE_OPTIONS[dateRangeKey]
    : DATE_RANGE_OPTIONS[DATE_RANGE_OPTION_LAST_30_DAYS];

  const nodes = await requestFlowMetrics({
    startDate: toISODateFormat(startDate, true),
    endDate: toISODateFormat(endDate, true),
    namespace,
    ...overridesRest,
  });

  return nodes.length ? { nodes } : {};
}
