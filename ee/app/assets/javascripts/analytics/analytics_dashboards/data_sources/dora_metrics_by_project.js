import {
  dateAtFirstDayOfMonth,
  nDaysBefore,
  nMonthsBefore,
  toISODateFormat,
} from '~/lib/utils/datetime_utility';
import { SUPPORTED_DORA_METRICS } from 'ee/analytics/dashboards/constants';
import { percentChange } from 'ee/analytics/dashboards/utils';
import DoraMetricsByProjectQuery from 'ee/analytics/dashboards/graphql/dora_metrics_by_project.query.graphql';
import { BUCKETING_INTERVAL_MONTHLY } from 'ee/analytics/dashboards/graphql/constants';
import { defaultClient } from '../graphql/client';

const calculateTrends = (previous, current) =>
  SUPPORTED_DORA_METRICS.reduce(
    (trends, id) => ({
      ...trends,
      [id]: percentChange({ current: current[id], previous: previous[id] }),
    }),
    {},
  );

const fetchDoraMetricsQuery = async ({ namespace, startDate, endDate }) => {
  const {
    data: {
      group: {
        projects: { nodes },
      },
    },
  } = await defaultClient.query({
    query: DoraMetricsByProjectQuery,
    variables: {
      fullPath: namespace,
      interval: BUCKETING_INTERVAL_MONTHLY,
      startDate,
      endDate,
    },
  });

  const projects = nodes.map(
    ({
      id,
      name,
      avatarUrl,
      webUrl,
      dora: {
        metrics: [pastMetrics, currentMetrics],
      },
    }) => ({
      id,
      name,
      avatarUrl,
      webUrl,
      trends: calculateTrends(pastMetrics, currentMetrics),
      ...currentMetrics,
    }),
  );

  return { projects };
};

export default async function fetch({ namespace }) {
  const thisMonth = dateAtFirstDayOfMonth(new Date());
  const endDate = nDaysBefore(thisMonth, 1);
  const startDate = nMonthsBefore(thisMonth, 2);

  return fetchDoraMetricsQuery({
    startDate: toISODateFormat(startDate),
    endDate: toISODateFormat(endDate),
    namespace,
  });
}
