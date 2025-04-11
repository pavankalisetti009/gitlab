import getThroughputChartData from 'ee/analytics/merge_request_analytics/graphql/queries/throughput_chart.query.graphql';
import {
  computeMonthRangeData,
  formatThroughputChartData,
} from 'ee/analytics/merge_request_analytics/utils';
import { BUCKETING_INTERVAL_MONTHLY } from '~/analytics/shared/graphql/constants';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { startOfTomorrow } from 'ee/dora/components/static_data/shared';
import { getStartDate } from 'ee/analytics/analytics_dashboards/components/filters/utils';
import { DATE_RANGE_OPTION_LAST_365_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { defaultClient } from '../graphql/client';

const QUERY_RESULT_KEY = 'mergeRequests';

const extractThroughputDataForPeriod = ({ month, year, result }) => {
  const data = extractQueryResponseFromNamespace({
    result,
    resultKey: QUERY_RESULT_KEY,
  });
  return {
    key: `${month}_${year}`,
    data: data?.count ? data : { count: null, totalTimeToMerge: null },
  };
};

const timePeriodToThroughputQuery = async ({
  month,
  year,
  namespace,
  interval,
  mergedAfter,
  mergedBefore,
  ...params
}) => {
  const result = await defaultClient.query({
    query: getThroughputChartData,
    variables: {
      fullPath: namespace,
      interval,
      startDate: mergedAfter,
      endDate: mergedBefore,
      ...params,
    },
  });
  return extractThroughputDataForPeriod({ month, year, result });
};

const fetchCounts = async ({
  namespace,
  startDate,
  endDate,
  interval,
  labels = null,
  notLabels = null,
  sourceBranches = null,
  targetBranches = null,
  // The rest should not be set to null
  milestoneTitle,
  assigneeUsername,
  authorUsername,
}) => {
  const monthData = computeMonthRangeData(startDate, endDate);
  const promises = monthData.map(({ year, month, mergedAfter, mergedBefore }) =>
    timePeriodToThroughputQuery({
      year,
      month,
      namespace,
      interval,
      mergedAfter,
      mergedBefore,
      labels,
      notLabels,
      sourceBranches,
      targetBranches,
      milestoneTitle,
      assigneeUsername,
      authorUsername,
    }),
  );

  const result = await Promise.all(promises);
  const rawData = result.reduce(
    (acc, { key, data }) => ({
      ...acc,
      [key]: data,
    }),
    {},
  );

  return formatThroughputChartData(rawData);
};

export default function fetch({
  namespace,
  query: { dateRange = DATE_RANGE_OPTION_LAST_365_DAYS, interval = BUCKETING_INTERVAL_MONTHLY },
  queryOverrides = {},
  filters: { startDate: filtersStartDate, endDate = startOfTomorrow } = {},
}) {
  const startDate = filtersStartDate || getStartDate(dateRange);

  return fetchCounts({
    namespace,
    interval,
    startDate,
    endDate,
    ...queryOverrides,
  });
}
