import { sum } from 'lodash';
import UserAiUserMetricsQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_user_ai_user_metrics.query.graphql';
import { getStartDate } from 'ee/analytics/analytics_dashboards/components/filters/utils';
import {
  DATE_RANGE_OPTION_LAST_30_DAYS,
  startOfTomorrow,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { hasAnyNonNullFields } from 'ee/analytics/shared/utils';
import { defaultClient } from '../graphql/client';

// We want to default to 10 items per page to keep the tables small
const PAGINATION_PAGE_SIZE = 10;

const extractFields = (obj, fields = []) =>
  fields.reduce((acc, field) => ({ ...acc, [field]: obj?.[field] ?? 0 }), {});

// Getters to simplify field extraction ready for the data table
const getDuoCodeReviewReactedFields = (codeReview) => {
  const fields = [
    'requestReviewDuoCodeReviewOnMrByAuthorEventCount',
    'reactThumbsDownOnDuoCodeReviewCommentEventCount',
    'reactThumbsUpOnDuoCodeReviewCommentEventCount',
  ];
  const {
    requestReviewDuoCodeReviewOnMrByAuthorEventCount,
    reactThumbsUpOnDuoCodeReviewCommentEventCount,
    reactThumbsDownOnDuoCodeReviewCommentEventCount,
  } = extractFields(codeReview, fields);
  return {
    requestReviewDuoCodeReviewOnMrByAuthorEventCount,
    duoCodeReviewCommentsReactedTo: sum([
      reactThumbsUpOnDuoCodeReviewCommentEventCount,
      reactThumbsDownOnDuoCodeReviewCommentEventCount,
    ]),
  };
};

const prepareAdditionalMetrics = ({ nodes = [], ...rest }) => {
  // Since we are using `gl_introduced`, we need to check that the fields actually exist in the response
  if (!hasAnyNonNullFields(nodes, ['codeSuggestions', 'codeReview', 'troubleshootJob'])) {
    return {};
  }

  return {
    nodes: nodes.map(({ codeSuggestions, codeReview, troubleshootJob, ...nodeRest }) => ({
      ...extractFields(troubleshootJob, ['troubleshootJobEventCount']),
      ...extractFields(codeSuggestions, [
        'codeSuggestionAcceptedInIdeEventCount',
        'codeSuggestionShownInIdeEventCount',
      ]),
      ...getDuoCodeReviewReactedFields(codeReview),
      ...nodeRest,
    })),
    ...rest,
  };
};

export default async function fetch({
  namespace: fullPath,
  query: { dateRange = DATE_RANGE_OPTION_LAST_30_DAYS },
  queryOverrides: { pagination = {} } = {},
}) {
  const startDate = getStartDate(dateRange);

  const response = await defaultClient.query({
    query: UserAiUserMetricsQuery,
    variables: {
      fullPath,
      startDate,
      endDate: startOfTomorrow,
      first: PAGINATION_PAGE_SIZE,
      last: pagination.last,
      before: pagination.startCursor,
      after: pagination.endCursor,
    },
  });

  const parsed = prepareAdditionalMetrics(
    extractQueryResponseFromNamespace({
      result: response,
      resultKey: 'aiUserMetrics',
    }),
  );

  return parsed;
}
