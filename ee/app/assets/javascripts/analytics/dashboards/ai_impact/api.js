import {
  AI_METRICS,
  FLOW_METRICS,
  DORA_METRICS,
  SUPPORTED_CODE_SUGGESTIONS_DIMENSION_KEYS,
} from '~/analytics/shared/constants';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import { calculateRate, generateMetricTableTooltip } from './utils';

/**
 * @typedef {Object} TableMetric
 * @property {String} identifier - Identifier for the specified metric
 * @property {Number|'-'} value - Display friendly value
 * @property {String} tooltip - Actual usage rate values to be displayed in tooltip
 */

/**
 * @typedef {Object} CodeSuggestionsItem
 * @property {Integer} contributorsCount - Number of code contributors who used GitLab Duo Code Suggestions features
 * @property {Integer} acceptedCount - Number of code suggestions accepted by code contributors
 * @property {Integer} shownCount - Number of code suggestions shown to code contributors
 */

/**
 * @typedef {Object} AiMetricItem
 * @property {Integer} codeContributorsCount - Number of code contributors
 * @property {CodeSuggestionsItem} codeSuggestions - Code suggestions response
 */

/**
 * @typedef {Object} AiMetricResponseItem
 * @property {TableMetric} code_suggestions_usage_rate
 * @property {TableMetric} code_suggestions_acceptance_rate
 */

/**
 * Takes the raw `aiMetrics` graphql response and prepares the data for display
 * in the table.
 *
 * @param {AiMetricItem} data
 * @returns {AiMetricResponseItem} AI metrics ready for rendering in the dashboard
 */
export const extractGraphqlAiData = ({
  codeContributorsCount = null,
  codeSuggestions: {
    contributorsCount: codeSuggestionsContributorsCount = null,
    acceptedCount = null,
    shownCount = null,
  } = {},
  duoChatContributorsCount = null,
  rootCauseAnalysisUsersCount = null,
  duoAssignedUsersCount = null,
  duoUsedCount = null,
  codeReview: {
    requestReviewDuoCodeReviewOnMrByAuthorEventCount = null,
    requestReviewDuoCodeReviewOnMrByNonAuthorEventCount = null,
    postCommentDuoCodeReviewOnDiffEventCount = null,
  } = {},
  agentPlatformFlows = {},
  agentPlatformChats = {},
} = {}) => {
  const codeSuggestionsUsageRate = calculateRate({
    numerator: codeSuggestionsContributorsCount,
    denominator: codeContributorsCount,
  });

  const codeSuggestionsAcceptanceRate = calculateRate({
    numerator: acceptedCount,
    denominator: shownCount,
  });

  const duoChatUsageRate = calculateRate({
    numerator: duoChatContributorsCount,
    denominator: duoAssignedUsersCount,
  });

  const duoRcaUsageRate = calculateRate({
    numerator: rootCauseAnalysisUsersCount,
    denominator: duoAssignedUsersCount,
  });

  const duoReviewCount =
    requestReviewDuoCodeReviewOnMrByAuthorEventCount === null &&
    requestReviewDuoCodeReviewOnMrByNonAuthorEventCount === null
      ? '-'
      : (requestReviewDuoCodeReviewOnMrByAuthorEventCount ?? 0) +
        (requestReviewDuoCodeReviewOnMrByNonAuthorEventCount ?? 0);

  return {
    [AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE]: {
      identifier: AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE,
      value: codeSuggestionsUsageRate ?? '-',
      tooltip: generateMetricTableTooltip({
        numerator: codeSuggestionsContributorsCount,
        denominator: codeContributorsCount,
      }),
    },
    [AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE]: {
      identifier: AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE,
      value: codeSuggestionsAcceptanceRate ?? '-',
      tooltip: generateMetricTableTooltip({
        numerator: acceptedCount,
        denominator: shownCount,
      }),
    },
    [AI_METRICS.DUO_CHAT_USAGE_RATE]: {
      identifier: AI_METRICS.DUO_CHAT_USAGE_RATE,
      value: duoChatUsageRate ?? '-',
      tooltip: generateMetricTableTooltip({
        numerator: duoChatContributorsCount,
        denominator: duoAssignedUsersCount,
      }),
    },
    [AI_METRICS.DUO_RCA_USAGE_RATE]: {
      identifier: AI_METRICS.DUO_RCA_USAGE_RATE,
      value: duoRcaUsageRate ?? '-',
      tooltip: generateMetricTableTooltip({
        numerator: rootCauseAnalysisUsersCount,
        denominator: duoAssignedUsersCount,
      }),
    },
    [AI_METRICS.DUO_USED_COUNT]: {
      identifier: AI_METRICS.DUO_USED_COUNT,
      value: duoUsedCount ?? '-',
    },
    [AI_METRICS.DUO_REVIEW_REQUESTS_COUNT]: {
      identifier: AI_METRICS.DUO_REVIEW_REQUESTS_COUNT,
      value: duoReviewCount ?? '-',
    },
    [AI_METRICS.DUO_REVIEW_COMMENT_COUNT]: {
      identifier: AI_METRICS.DUO_REVIEW_COMMENT_COUNT,
      value: postCommentDuoCodeReviewOnDiffEventCount ?? '-',
    },
    [AI_METRICS.DUO_AGENT_PLATFORM_FLOWS]: {
      identifier: AI_METRICS.DUO_AGENT_PLATFORM_FLOWS,
      value: agentPlatformFlows?.startedSessionEventCount ?? '-',
    },
    [AI_METRICS.DUO_AGENT_PLATFORM_CHATS]: {
      identifier: AI_METRICS.DUO_AGENT_PLATFORM_CHATS,
      value: agentPlatformChats?.startedSessionEventCount ?? '-',
    },
  };
};

export const extractAiMetricsResponse = (result) =>
  extractQueryResponseFromNamespace({
    result,
    resultKey: 'aiMetrics',
  });

/**
 * Fetches code suggestions metrics grouped by a specified dimension.
 *
 * Retrieves all available dimension values (IDEs or languages) from an initial query,
 * then fetches detailed metrics for each dimension individually. Empty dimension values
 * are filtered out before querying.
 *
 * @async
 * @param {Object} variables - GraphQL query variables
 * @param {string} variables.fullPath - The full path of the project or group
 * @param {string} variables.startDate - Start date in ISO 8601 format
 * @param {string} variables.endDate - End date in ISO 8601 format
 * @param {string} dimensionKey - The dimension to group metrics by ('ideNames' or 'languages')
 * @returns {Promise<{successful: Array, failed: Array}>} Query results
 * @returns {Array<Object>} successful - Array of successful GraphQL query responses
 * @returns {Array<string>} failed - Array of dimension identifiers that failed to fetch
 * @throws {Error} If dimensionKey is not a valid dimension
 */
export const fetchCodeSuggestionsMetricsByDimension = async (variables, dimensionKey) => {
  if (!SUPPORTED_CODE_SUGGESTIONS_DIMENSION_KEYS.includes(dimensionKey)) {
    throw new Error(
      `Invalid dimension key: ${dimensionKey}. Must be one of: ${SUPPORTED_CODE_SUGGESTIONS_DIMENSION_KEYS.join(', ')}`,
    );
  }

  const rawAiMetricsQueryResult = await defaultClient.query({
    query: AiMetricsQuery,
    variables,
  });

  const { codeSuggestions } = extractAiMetricsResponse(rawAiMetricsQueryResult);

  // Filter out empty strings returned for unknown/unsupported dimensions
  const dimensions = codeSuggestions?.[dimensionKey]?.filter((dimension) => dimension !== '') ?? [];

  const results = await Promise.allSettled(
    dimensions.map(async (dimension) => {
      try {
        return await defaultClient.query({
          query: AiMetricsQuery,
          variables: {
            ...variables,
            [dimensionKey]: dimension,
          },
        });
      } catch (error) {
        throw new Error(dimension);
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

export const skippedDoraMetrics = (skipMetrics) => ({
  skipDeploymentFrequency: skipMetrics.includes(DORA_METRICS.DEPLOYMENT_FREQUENCY),
  skipLeadTimeForChanges: skipMetrics.includes(DORA_METRICS.LEAD_TIME_FOR_CHANGES),
  skipTimeToRestoreService: skipMetrics.includes(DORA_METRICS.TIME_TO_RESTORE_SERVICE),
  skipChangeFailureRate: skipMetrics.includes(DORA_METRICS.CHANGE_FAILURE_RATE),
});

export const skippedFlowMetrics = (skipMetrics) => ({
  skipIssueCount: skipMetrics.includes(FLOW_METRICS.ISSUES),
  skipIssuesCompletedCount: skipMetrics.includes(FLOW_METRICS.ISSUES_COMPLETED),
  skipCycleTime: skipMetrics.includes(FLOW_METRICS.CYCLE_TIME),
  skipLeadTime: skipMetrics.includes(FLOW_METRICS.LEAD_TIME),
  skipDeploymentCount: skipMetrics.includes(FLOW_METRICS.DEPLOYS),
  skipTimeToMerge: skipMetrics.includes(FLOW_METRICS.MEDIAN_TIME_TO_MERGE),
});
