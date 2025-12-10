import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { s__, __, sprintf } from '~/locale';
import {
  LAST_30_DAYS,
  DORA_METRIC_QUERY_RANGES,
  startOfTomorrow,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { truncate } from '~/lib/utils/text_utility';
import { GENERIC_DASHBOARD_ERROR } from 'ee/analytics/dashboards/constants';
import { defaultClient } from '../graphql/client';

const extractAiMetricsResponse = (result) =>
  extractQueryResponseFromNamespace({
    result,
    resultKey: 'aiMetrics',
  });

const fetchAllCodeSuggestionsIdeMetrics = async (variables) => {
  const rawAiMetricsQueryResult = await defaultClient.query({
    query: AiMetricsQuery,
    variables,
  });

  const { codeSuggestions } = extractAiMetricsResponse(rawAiMetricsQueryResult);

  // Filter out empty strings returned for unknown/unsupported IDE names
  const codeSuggestionsIdes = codeSuggestions?.ideNames?.filter((ide) => ide !== '') ?? [];

  const results = await Promise.allSettled(
    codeSuggestionsIdes.map(async (ide) => {
      try {
        return await defaultClient.query({
          query: AiMetricsQuery,
          variables: {
            ...variables,
            ideNames: ide,
          },
        });
      } catch (error) {
        throw new Error(ide);
      }
    }),
  );

  const successful = results
    .filter((result) => result.status === 'fulfilled')
    .map((result) => result.value);

  const failed = results
    .filter((result) => result.status === 'rejected')
    .map((result) => result.reason?.message);

  return { successful, failed };
};

const extractAcceptanceMetricsByIde = (results = []) => {
  const extractedResults = results
    .map((result) => {
      const { codeSuggestions: { acceptedCount, shownCount, ideNames = [] } = {} } =
        extractAiMetricsResponse(result);
      const acceptanceRate = shownCount > 0 ? acceptedCount / shownCount : null;
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

  const { successful, failed } = await fetchAllCodeSuggestionsIdeMetrics({
    fullPath: namespaceOverride ?? namespace,
    startDate,
    endDate: startOfTomorrow,
  });

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
