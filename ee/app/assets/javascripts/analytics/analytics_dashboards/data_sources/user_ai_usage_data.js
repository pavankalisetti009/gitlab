import UserAiUserMetricsQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_user_ai_user_metrics.query.graphql';
import { startOfTomorrow } from 'ee/analytics/dora/components/static_data/shared';
import { getStartDate } from 'ee/analytics/analytics_dashboards/components/filters/utils';
import { DATE_RANGE_OPTION_LAST_30_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { defaultClient } from '../graphql/client';

export default async function fetch({
  namespace: fullPath,
  query: { dateRange = DATE_RANGE_OPTION_LAST_30_DAYS },
  queryOverrides: { pagination = { first: 20 } } = {},
}) {
  const startDate = getStartDate(dateRange);

  const response = await defaultClient.query({
    query: UserAiUserMetricsQuery,
    variables: {
      fullPath,
      startDate,
      endDate: startOfTomorrow,
      first: pagination.first,
      last: pagination.last,
      before: pagination.startCursor,
      after: pagination.endCursor,
    },
  });

  return extractQueryResponseFromNamespace({ result: response, resultKey: 'aiUserMetrics' });
}
