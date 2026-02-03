import truncate from 'lodash/truncate';
import { toISODateFormat } from '~/lib/utils/datetime_utility';
import { s__, __, sprintf } from '~/locale';
import {
  DATE_RANGE_OPTION_LAST_30_DAYS,
  DATE_RANGE_OPTIONS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { GENERIC_DASHBOARD_ERROR } from 'ee/analytics/dashboards/constants';
import {
  extractAiMetricsResponse,
  fetchCodeSuggestionsMetricsByDimension,
} from 'ee/analytics/dashboards/ai_impact/api';
import { IDE_DIMENSION_KEY } from '~/analytics/shared/constants';
import { calculateRate } from 'ee/analytics/dashboards/ai_impact/utils';

const extractAcceptanceMetricsByIde = (results = []) => {
  const extractedResults = results
    .map((result) => {
      const { codeSuggestions: { acceptedCount, shownCount, ideNames = [] } = {} } =
        extractAiMetricsResponse(result);
      const acceptanceRate = calculateRate({
        numerator: acceptedCount,
        denominator: shownCount,
        asDecimal: true,
      });
      const [ideName] = ideNames ?? [];

      return { acceptanceRate, ideName, acceptedCount, shownCount };
    })
    .filter(({ acceptanceRate }) => acceptanceRate !== null)
    .sort((a, b) => a.acceptedCount - b.acceptedCount);

  return extractedResults.reduce(
    (acc, { acceptanceRate, ideName, acceptedCount, shownCount }) => {
      acc.chartData.push([acceptedCount, ideName]);
      acc.contextualData[ideName] = { acceptanceRate, shownCount };

      return acc;
    },
    { chartData: [], contextualData: {} },
  );
};

export default async function fetch({
  namespace,
  query: { dateRange = DATE_RANGE_OPTION_LAST_30_DAYS },
  queryOverrides: { dateRange: dateRangeOverride, namespace: namespaceOverride } = {},
  setVisualizationOverrides = () => {},
  setAlerts = () => {},
}) {
  const dateRangeKey = dateRangeOverride || dateRange;

  const { startDate, endDate } = DATE_RANGE_OPTIONS[dateRangeKey]
    ? DATE_RANGE_OPTIONS[dateRangeKey]
    : DATE_RANGE_OPTIONS[DATE_RANGE_OPTION_LAST_30_DAYS];

  const { successful, failed } = await fetchCodeSuggestionsMetricsByDimension(
    {
      fullPath: namespaceOverride ?? namespace,
      startDate: toISODateFormat(startDate, true),
      endDate: toISODateFormat(endDate, true),
    },
    IDE_DIMENSION_KEY,
  );

  if (failed.length > 0 && successful.length === 0) {
    setAlerts({
      title: GENERIC_DASHBOARD_ERROR,
      errors: [
        s__('CodeSuggestionsAcceptanceByIdeChart|Failed to load code suggestions data by IDE.'),
      ],
    });

    return {};
  }

  if (failed.length > 0) {
    setAlerts({
      canRetry: true,
      warnings: [
        sprintf(
          s__('CodeSuggestionsAcceptanceByIdeChart|Failed to load metrics for: %{ideNames}'),
          { ideNames: failed.join(', ') },
        ),
      ],
    });
  }

  const { chartData, contextualData } = extractAcceptanceMetricsByIde(successful);

  if (!chartData.some(([value]) => value)) return {};

  setVisualizationOverrides({
    visualizationOptionOverrides: {
      yAxis: {
        axisLabel: {
          formatter: (str) => truncate(str, { length: 9 }),
        },
      },
    },
  });

  return {
    [__('Suggestions accepted')]: chartData,
    contextualData,
  };
}
