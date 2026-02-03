import { toISODateFormat } from '~/lib/utils/datetime_utility';
import { __, s__, sprintf } from '~/locale';
import {
  DATE_RANGE_OPTION_LAST_30_DAYS,
  DATE_RANGE_OPTIONS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { getLanguageDisplayName } from 'ee/analytics/analytics_dashboards/code_suggestions_languages';
import { truncate } from '~/lib/utils/text_utility';
import { calculateRate } from 'ee/analytics/dashboards/ai_impact/utils';
import {
  extractAiMetricsResponse,
  fetchCodeSuggestionsMetricsByDimension,
} from 'ee/analytics/dashboards/ai_impact/api';
import { LANGUAGE_DIMENSION_KEY } from '~/analytics/shared/constants';
import { GENERIC_DASHBOARD_ERROR } from 'ee/analytics/dashboards/constants';

// Merges language variants into single entries by canonical name, summing counts.
const mergeMetricsByLanguage = (results = []) => {
  return results.reduce((acc, result) => {
    const { codeSuggestions: { acceptedCount = null, shownCount = null, languages = [] } = {} } =
      extractAiMetricsResponse(result);

    const [languageId] = languages ?? [];
    const language = getLanguageDisplayName(languageId);

    if (acceptedCount === null || shownCount <= 0 || !language) return acc;

    if (!acc[language]) {
      acc[language] = { acceptedCount: 0, shownCount: 0 };
    }

    acc[language].acceptedCount += acceptedCount;
    acc[language].shownCount += shownCount;

    return acc;
  }, {});
};

const calculateAcceptanceRates = (metricsByLanguage = {}) => {
  return Object.entries(metricsByLanguage).reduce((acc, [language, metrics]) => {
    acc[language] = {
      ...metrics,
      acceptanceRate: calculateRate({
        numerator: metrics.acceptedCount,
        denominator: metrics.shownCount,
        asDecimal: true,
      }),
    };
    return acc;
  }, {});
};

const filterAndSortMetrics = (metricsWithRates) => {
  return Object.entries(metricsWithRates)
    .filter(([, { acceptanceRate }]) => acceptanceRate !== null)
    .sort((a, b) => a[1].acceptedCount - b[1].acceptedCount);
};

const formatChartData = (sortedResults) => {
  return {
    chartData: sortedResults.map(([language, { acceptedCount }]) => [acceptedCount, language]),
    contextualData: Object.fromEntries(
      sortedResults.map(([language, { acceptanceRate, shownCount }]) => [
        language,
        { acceptanceRate, shownCount },
      ]),
    ),
  };
};

const extractAcceptanceMetricsByLanguage = (results = []) => {
  const mergedMetricsByLanguage = mergeMetricsByLanguage(results);
  const metricsWithRates = calculateAcceptanceRates(mergedMetricsByLanguage);
  const sortedResults = filterAndSortMetrics(metricsWithRates);

  return formatChartData(sortedResults);
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
    LANGUAGE_DIMENSION_KEY,
  );

  if (failed.length > 0 && successful.length === 0) {
    setAlerts({
      title: GENERIC_DASHBOARD_ERROR,
      errors: [
        s__(
          'CodeSuggestionsAcceptanceByLanguageChart|Failed to load code suggestions data by language.',
        ),
      ],
    });

    return {};
  }

  if (failed.length > 0) {
    const languages = failed.map((language) => getLanguageDisplayName(language)).join(', ');

    setAlerts({
      canRetry: true,
      warnings: [
        sprintf(
          s__('CodeSuggestionsAcceptanceByLanguageChart|Failed to load metrics for: %{languages}'),
          { languages },
        ),
      ],
    });
  }

  const { chartData, contextualData } = extractAcceptanceMetricsByLanguage(successful);

  if (!chartData.some(([value]) => value)) return {};

  setVisualizationOverrides({
    visualizationOptionOverrides: {
      yAxis: {
        axisLabel: {
          formatter: (str) => truncate(str, 10),
        },
      },
    },
  });

  return {
    [__('Suggestions accepted')]: chartData,
    contextualData,
  };
}
