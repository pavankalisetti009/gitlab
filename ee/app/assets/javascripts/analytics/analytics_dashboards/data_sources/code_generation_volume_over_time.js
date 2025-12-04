import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  START_DATES,
  startOfTomorrow,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { s__ } from '~/locale';
import { getMonthsInDateRange } from 'ee/analytics/dashboards/utils';

const extractLinesOfCodeMetrics = (result) => {
  const { codeSuggestions } = extractQueryResponseFromNamespace({
    result,
    resultKey: 'aiMetrics',
  });

  const { acceptedLinesOfCode, shownLinesOfCode } = codeSuggestions ?? {};

  return {
    acceptedLinesOfCode,
    shownLinesOfCode,
  };
};

const codeSuggestionsLinesOfCodeQuery = async ({ namespace, startDate, endDate, monthLabel }) => {
  const result = await defaultClient.query({
    query: AiMetricsQuery,
    variables: {
      fullPath: namespace,
      startDate,
      endDate,
    },
  });

  return { monthLabel, data: extractLinesOfCodeMetrics(result) };
};

const formatChartData = (result = []) => {
  // To prevent gaps in the chart, return zeroes rather than nullish values
  const formatDataPoint = (monthLabel, value) => [monthLabel, value ?? 0];

  const acceptedLinesOfCodeData = result.map(({ monthLabel, data: { acceptedLinesOfCode } }) =>
    formatDataPoint(monthLabel, acceptedLinesOfCode),
  );

  const shownLinesOfCodeData = result.map(({ monthLabel, data: { shownLinesOfCode } }) =>
    formatDataPoint(monthLabel, shownLinesOfCode),
  );

  return [
    {
      name: s__('CodeGenerationVolumeTrendsChart|Lines of code accepted'),
      data: acceptedLinesOfCodeData,
    },
    {
      name: s__('CodeGenerationVolumeTrendsChart|Lines of code shown'),
      data: shownLinesOfCodeData,
    },
  ];
};

const fetchCodeSuggestionsLinesOfCodeData = async ({ namespace, startDate, endDate }) => {
  const monthsData = getMonthsInDateRange(startDate, endDate);
  const promises = monthsData.map(({ monthLabel, fromDate, toDate }) =>
    codeSuggestionsLinesOfCodeQuery({
      namespace,
      startDate: fromDate,
      endDate: toDate,
      monthLabel,
    }),
  );

  const result = await Promise.all(promises);

  return formatChartData(result);
};

const hasChartData = (chartData = []) =>
  chartData.some(({ data }) => data.some(([, value]) => value));

export default async function fetch({
  namespace,
  query: { dateRange = DATE_RANGE_OPTION_LAST_180_DAYS },
  queryOverrides: { namespace: namespaceOverride } = {},
}) {
  const startDate = START_DATES[dateRange] ?? START_DATES[DATE_RANGE_OPTION_LAST_180_DAYS];
  const endDate = startOfTomorrow;

  const chartData = await fetchCodeSuggestionsLinesOfCodeData({
    namespace: namespaceOverride ?? namespace,
    startDate,
    endDate,
  });

  if (!hasChartData(chartData)) return [];

  return chartData;
}
