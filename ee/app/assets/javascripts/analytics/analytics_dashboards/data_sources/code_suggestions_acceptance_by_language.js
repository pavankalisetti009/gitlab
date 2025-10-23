import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { s__, sprintf } from '~/locale';
import {
  LAST_30_DAYS,
  DORA_METRIC_QUERY_RANGES,
  startOfTomorrow,
} from 'ee/analytics/dora/components/static_data/shared';
import { getLanguageDisplayName } from 'ee/analytics/analytics_dashboards/code_suggestions_languages';
import { formatAsPercentage } from 'ee/analytics/dora/components/util';
import { truncate } from '~/lib/utils/text_utility';
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

const extractAcceptanceMetricsByLanguage = (results = []) => {
  const extractedResults = results
    .map((result) => {
      const { codeSuggestions: { acceptedCount, shownCount, languages = [] } = {} } =
        extractAiMetricsResponse(result);
      const acceptanceRate = shownCount > 0 ? acceptedCount / shownCount : null;
      const [languageId] = languages ?? [];
      const language = getLanguageDisplayName(languageId);

      return { acceptanceRate, language, acceptedCount, shownCount };
    })
    .filter(({ acceptanceRate }) => acceptanceRate !== null)
    .sort((a, b) => a.acceptanceRate - b.acceptanceRate);

  return extractedResults.reduce(
    (acc, { acceptanceRate, language, acceptedCount, shownCount }) => {
      acc.chartData.push([acceptanceRate, language]);
      acc.contextualData[language] = { acceptedCount, shownCount };

      return acc;
    },
    { chartData: [], contextualData: {} },
  );
};

export default async function fetch({
  namespace,
  query: { dateRange = LAST_30_DAYS },
  queryOverrides: { dateRange: dateRangeOverride, namespace: namespaceOverride } = {},
  setVisualizationOverrides = () => {},
  setAlerts = () => {},
}) {
  const dateRangeKey = dateRangeOverride
    ? dateRangeOverride.toUpperCase()
    : dateRange.toUpperCase();

  const startDate =
    DORA_METRIC_QUERY_RANGES[dateRangeKey] ?? DORA_METRIC_QUERY_RANGES[LAST_30_DAYS];

  const { successfulLanguages, failedLanguages } = await fetchAllCodeSuggestionsLanguagesMetrics({
    fullPath: namespaceOverride ?? namespace,
    startDate,
    endDate: startOfTomorrow,
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
      xAxis: {
        axisLabel: {
          formatter(value) {
            return formatAsPercentage(value, 0);
          },
        },
      },
    },
  });

  return {
    [s__('CodeSuggestionsAcceptanceByLanguageChart|Acceptance rate')]: chartData,
    contextualData,
  };
}
