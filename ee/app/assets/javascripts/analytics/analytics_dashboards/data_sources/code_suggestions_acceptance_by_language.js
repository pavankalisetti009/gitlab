import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import { toISODateFormat } from '~/lib/utils/datetime_utility';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { __, s__, sprintf } from '~/locale';
import {
  DATE_RANGE_OPTION_LAST_30_DAYS,
  DATE_RANGE_OPTIONS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { getLanguageDisplayName } from 'ee/analytics/analytics_dashboards/code_suggestions_languages';
import { truncate } from '~/lib/utils/text_utility';
import { calculateRate } from 'ee/analytics/dashboards/ai_impact/utils';
import { defaultClient } from '../graphql/client';

const extractAiMetricsResponse = (result) =>
  extractQueryResponseFromNamespace({
    result,
    resultKey: 'aiMetrics',
  });

const fetchAllCodeSuggestionsLanguagesMetrics = async (variables) => {
  const rawAiMetricsQueryResult = await defaultClient.query({
    query: AiMetricsQuery,
    variables,
  });

  const { codeSuggestions } = extractAiMetricsResponse(rawAiMetricsQueryResult);

  // Filter out empty strings returned for unknown/unsupported languages
  const codeSuggestionsLanguages =
    codeSuggestions?.languages?.filter((languageId) => languageId !== '') ?? [];

  const results = await Promise.allSettled(
    codeSuggestionsLanguages.map(async (languageId) => {
      try {
        return await defaultClient.query({
          query: AiMetricsQuery,
          variables: {
            ...variables,
            languages: languageId,
          },
        });
      } catch (error) {
        throw new Error(languageId);
      }
    }),
  );

  const successfulLanguages = results
    .filter((result) => result.status === 'fulfilled')
    .map((result) => result.value);

  const failedLanguages = results
    .filter((result) => result.status === 'rejected')
    .map((result) => result.reason?.message);

  return { successfulLanguages, failedLanguages };
};

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

  const { successfulLanguages, failedLanguages } = await fetchAllCodeSuggestionsLanguagesMetrics({
    fullPath: namespaceOverride ?? namespace,
    startDate: toISODateFormat(startDate, true),
    endDate: toISODateFormat(endDate, true),
  });

  const { chartData, contextualData } = extractAcceptanceMetricsByLanguage(successfulLanguages);

  if (!chartData.some(([value]) => value)) return {};

  if (failedLanguages.length > 0) {
    const languages = failedLanguages
      .map((language) => getLanguageDisplayName(language))
      .join(', ');

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
