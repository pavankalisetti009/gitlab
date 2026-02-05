import { sum } from 'lodash';
import UserAiUserMetricsQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_user_ai_user_metrics.query.graphql';
import {
  DATE_RANGE_OPTIONS,
  DATE_RANGE_OPTION_LAST_30_DAYS,
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

const prepareAdditionalMetrics = ({ nodes = [], pageInfo = {}, ...rest }, pagination) => {
  // Since we are using `gl_introduced`, we need to check that the fields actually exist in the response
  if (
    !hasAnyNonNullFields(nodes, [
      'codeSuggestions',
      'codeReview',
      'troubleshootJob',
      'totalEventCount',
    ])
  ) {
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
    pageInfo: {
      ...pagination,
      ...pageInfo,
    },
    ...rest,
  };
};

const SORTABLE_FIELD_KEYS = {
  requestReviewDuoCodeReviewOnMrByAuthorEventCount:
    'REQUEST_REVIEW_DUO_CODE_REVIEW_ON_MR_BY_AUTHOR',
  codeSuggestionShownInIdeEventCount: 'CODE_SUGGESTION_SHOWN_IN_IDE',
  codeSuggestionAcceptedInIdeEventCount: 'CODE_SUGGESTION_ACCEPTED_IN_IDE',
  troubleshootJobEventCount: 'TROUBLESHOOT_JOB_TOTAL_COUNT',
  totalEventCount: 'TOTAL_EVENTS_COUNT',
};

const constructSortKey = ({ sortBy, sortDesc }) => {
  if (SORTABLE_FIELD_KEYS[sortBy]) {
    const baseKey = SORTABLE_FIELD_KEYS[sortBy];
    return sortDesc ? `${baseKey}_DESC` : `${baseKey}_ASC`;
  }
  return null;
};

export default async function fetch({
  namespace: fullPath,
  query: {
    dateRange = DATE_RANGE_OPTION_LAST_30_DAYS,
    sortBy: defaultSortBy,
    sortDesc: defaultSortDesc,
  },
  queryOverrides: {
    pagination = { first: PAGINATION_PAGE_SIZE },
    sortBy: sortByOverride,
    sortDesc: sortDescOverride,
  } = {},
}) {
  const { startDate, endDate } = DATE_RANGE_OPTIONS[dateRange]
    ? DATE_RANGE_OPTIONS[dateRange]
    : DATE_RANGE_OPTIONS[DATE_RANGE_OPTION_LAST_30_DAYS];

  const sortBy = sortByOverride ?? defaultSortBy;
  const sortDesc = sortDescOverride ?? defaultSortDesc;

  const response = await defaultClient.query({
    query: UserAiUserMetricsQuery,
    variables: {
      fullPath,
      startDate,
      endDate,
      first: pagination.first,
      last: pagination.last,
      before: pagination.startCursor,
      after: pagination.endCursor,
      sort: constructSortKey({ sortBy, sortDesc }),
    },
  });

  return prepareAdditionalMetrics(
    extractQueryResponseFromNamespace({
      result: response,
      resultKey: 'aiUserMetrics',
    }),
    pagination,
  );
}
