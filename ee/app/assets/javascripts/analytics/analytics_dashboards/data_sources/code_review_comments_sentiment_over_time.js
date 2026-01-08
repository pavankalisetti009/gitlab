import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  DATE_RANGE_OPTIONS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { s__ } from '~/locale';
import { getMonthsInDateRange } from 'ee/analytics/dashboards/utils';
import { formatAsPercentage } from 'ee/analytics/analytics_dashboards/components/visualizations/utils';
import { calculateRate } from 'ee/analytics/dashboards/ai_impact/utils';
import { helpPagePath } from '~/helpers/help_page_helper';

const extractCodeReviewMetrics = (result) => {
  const { codeReview } = extractQueryResponseFromNamespace({
    result,
    resultKey: 'aiMetrics',
  });

  const {
    postCommentDuoCodeReviewOnDiffEventCount,
    reactThumbsDownOnDuoCodeReviewCommentEventCount,
    reactThumbsUpOnDuoCodeReviewCommentEventCount,
  } = codeReview ?? {};

  return {
    postCommentDuoCodeReviewOnDiffEventCount,
    reactThumbsDownOnDuoCodeReviewCommentEventCount,
    reactThumbsUpOnDuoCodeReviewCommentEventCount,
  };
};

const codeReviewSentimentQuery = async ({ namespace, startDate, endDate, monthLabel }) => {
  const result = await defaultClient.query({
    query: AiMetricsQuery,
    variables: {
      fullPath: namespace,
      startDate,
      endDate,
    },
  });

  return { monthLabel, data: extractCodeReviewMetrics(result) };
};

const formatChartData = (result = []) => {
  const approvalRates = result.map(({ monthLabel, data = {} }) => [
    monthLabel,
    calculateRate({
      numerator: data.reactThumbsUpOnDuoCodeReviewCommentEventCount,
      denominator: data.postCommentDuoCodeReviewOnDiffEventCount,
      asDecimal: true,
    }) ?? 0,
  ]);

  const disapprovalRates = result.map(({ monthLabel, data = {} }) => [
    monthLabel,
    calculateRate({
      numerator: data.reactThumbsDownOnDuoCodeReviewCommentEventCount,
      denominator: data.postCommentDuoCodeReviewOnDiffEventCount,
      asDecimal: true,
    }) ?? 0,
  ]);

  return [
    {
      name: s__('CodeReviewCommentsSentimentChart|👍 Approval rate'),
      data: approvalRates,
    },
    {
      name: s__('CodeReviewCommentsSentimentChart|👎 Disapproval rate'),
      data: disapprovalRates,
    },
  ];
};

const fetchCodeReviewSentimentData = async ({ namespace, startDate, endDate }) => {
  const monthsData = getMonthsInDateRange(startDate, endDate);
  const promises = monthsData.map(({ monthLabel, fromDate, toDate }) =>
    codeReviewSentimentQuery({
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
  setVisualizationOverrides = () => {},
}) {
  const { startDate, endDate } =
    DATE_RANGE_OPTIONS[dateRange] ?? DATE_RANGE_OPTIONS[DATE_RANGE_OPTION_LAST_180_DAYS];

  const chartData = await fetchCodeReviewSentimentData({
    namespace: namespaceOverride ?? namespace,
    startDate,
    endDate,
  });

  if (!hasChartData(chartData)) return [];

  setVisualizationOverrides({
    visualizationOptionOverrides: {
      tooltip: {
        description: s__(
          'CodeReviewCommentsSentimentChart|Users that reacted positively or negatively to GitLab Duo Code review comments. Expect negativity bias. %{linkStart}Learn more%{linkEnd}.',
        ),
        descriptionLink: helpPagePath('user/analytics/duo_and_sdlc_trends', {
          anchor: 'gitlab-duo-code-review-comments-sentiment',
        }),
      },
      yAxis: {
        axisLabel: {
          formatter(value) {
            return formatAsPercentage(value, 0);
          },
        },
      },
    },
  });

  return chartData;
}
