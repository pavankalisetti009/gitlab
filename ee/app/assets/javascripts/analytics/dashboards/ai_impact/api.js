import { AI_METRICS } from '~/analytics/shared/constants';
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
  };
};
