import { extractGraphqlAiData } from 'ee/analytics/dashboards/ai_impact/api';

describe('AI impact dashboard api', () => {
  describe('extractGraphqlAiData', () => {
    it.each([
      ['code_suggestions_acceptance_rate', { codeSuggestions: { shownCount: 4 } }],
      ['code_suggestions_acceptance_rate', { codeSuggestions: { acceptedCount: 3 } }],
      [
        'code_suggestions_acceptance_rate',
        { codeSuggestions: { acceptedCount: 3, shownCount: 4 } },
      ],
      [
        'code_suggestions_acceptance_rate',
        { codeSuggestions: { acceptedCount: 0, shownCount: 20 } },
      ],
      ['code_suggestions_usage_rate', { codeContributorsCount: 5 }],
      ['code_suggestions_usage_rate', { codeSuggestions: { contributorsCount: 2 } }],
      [
        'code_suggestions_usage_rate',
        { codeSuggestions: { contributorsCount: 5 }, codeContributorsCount: 10 },
      ],
      [
        'code_suggestions_usage_rate',
        { codeSuggestions: { contributorsCount: 0 }, codeContributorsCount: 10 },
      ],
      ['duo_chat_usage_rate', { duoAssignedUsersCount: 3 }],
      ['duo_chat_usage_rate', { duoChatContributorsCount: 4 }],
      ['duo_chat_usage_rate', { duoChatContributorsCount: 7, duoAssignedUsersCount: 8 }],
      ['duo_chat_usage_rate', { duoChatContributorsCount: 0, duoAssignedUsersCount: 50 }],
      ['duo_rca_usage_rate', { duoAssignedUsersCount: 3 }],
      ['duo_rca_usage_rate', { rootCauseAnalysisUsersCount: 10 }],
      ['duo_rca_usage_rate', { rootCauseAnalysisUsersCount: 5, duoAssignedUsersCount: 8 }],
      ['duo_rca_usage_rate', { rootCauseAnalysisUsersCount: 0, duoAssignedUsersCount: 50 }],
      ['duo_review_requests_count', {}],
      [
        'duo_review_requests_count',
        { codeReview: { requestReviewDuoCodeReviewOnMrByAuthorEventCount: 10 } },
      ],
      [
        'duo_review_requests_count',
        { codeReview: { requestReviewDuoCodeReviewOnMrByNonAuthorEventCount: 5 } },
      ],
      [
        'duo_review_requests_count',
        {
          codeReview: {
            requestReviewDuoCodeReviewOnMrByAuthorEventCount: 0,
            requestReviewDuoCodeReviewOnMrByNonAuthorEventCount: 0,
          },
        },
      ],
      [
        'duo_review_requests_count',
        {
          codeReview: {
            requestReviewDuoCodeReviewOnMrByAuthorEventCount: 5,
            requestReviewDuoCodeReviewOnMrByNonAuthorEventCount: 10,
          },
        },
      ],
      ['duo_review_comment_count', {}],
      [
        'duo_review_comment_count',
        { codeReview: { postCommentDuoCodeReviewOnDiffEventCount: 25 } },
      ],
      ['duo_review_comment_count', { codeReview: { postCommentDuoCodeReviewOnDiffEventCount: 0 } }],
    ])('returns %s given %o', (identifier, data) => {
      expect(extractGraphqlAiData(data)[identifier]).toMatchSnapshot();
    });
  });
});
