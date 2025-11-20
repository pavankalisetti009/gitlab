import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  START_DATES,
  startOfTomorrow,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { formatDateAsMonth } from '~/lib/utils/datetime/date_format_utility';
import dateFormat from '~/lib/dateformat';
import { dateFormats } from '~/analytics/shared/constants';
import { cloneDate } from '~/lib/utils/datetime/date_calculation_utility';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { s__ } from '~/locale';

export const getMonthsInDateRange = (startDate, endDate) => {
  const dateRangeData = [];
  const formatDate = (date) => dateFormat(date, dateFormats.isoDate, true);

  for (
    let fromDate = cloneDate(startDate);
    fromDate < endDate;
    fromDate.setMonth(fromDate.getMonth() + 1, 1)
  ) {
    let toDate = cloneDate(fromDate);
    toDate.setMonth(toDate.getMonth() + 1, 0);
    if (toDate > endDate) toDate = endDate;

    const formattedFromDate = formatDate(fromDate);

    dateRangeData.push({
      fromDate: formattedFromDate,
      toDate: formatDate(toDate),
      monthLabel: `${formatDateAsMonth(formattedFromDate)} ${fromDate.getFullYear()}`,
    });
  }

  return dateRangeData;
};

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
