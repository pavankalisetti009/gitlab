import { extractGraphqlAiData } from 'ee/analytics/dashboards/ai_impact/api';

describe('AI impact dashboard api', () => {
  describe('extractGraphqlAiData', () => {
    it.each`
      identifier                            | data
      ${'code_suggestions_acceptance_rate'} | ${{ codeSuggestions: { shownCount: 4 } }}
      ${'code_suggestions_acceptance_rate'} | ${{ codeSuggestions: { acceptedCount: 3 } }}
      ${'code_suggestions_acceptance_rate'} | ${{ codeSuggestions: { acceptedCount: 3, shownCount: 4 } }}
      ${'code_suggestions_acceptance_rate'} | ${{ codeSuggestions: { acceptedCount: 0, shownCount: 20 } }}
      ${'code_suggestions_usage_rate'}      | ${{ codeContributorsCount: 5 }}
      ${'code_suggestions_usage_rate'}      | ${{ codeSuggestions: { contributorsCount: 2 } }}
      ${'code_suggestions_usage_rate'}      | ${{ codeSuggestions: { contributorsCount: 5 }, codeContributorsCount: 10 }}
      ${'code_suggestions_usage_rate'}      | ${{ codeSuggestions: { contributorsCount: 0 }, codeContributorsCount: 10 }}
      ${'duo_chat_usage_rate'}              | ${{ duoAssignedUsersCount: 3 }}
      ${'duo_chat_usage_rate'}              | ${{ duoChatContributorsCount: 4 }}
      ${'duo_chat_usage_rate'}              | ${{ duoChatContributorsCount: 7, duoAssignedUsersCount: 8 }}
      ${'duo_chat_usage_rate'}              | ${{ duoChatContributorsCount: 0, duoAssignedUsersCount: 50 }}
      ${'duo_rca_usage_rate'}               | ${{ duoAssignedUsersCount: 3 }}
      ${'duo_rca_usage_rate'}               | ${{ rootCauseAnalysisUsersCount: 10 }}
      ${'duo_rca_usage_rate'}               | ${{ rootCauseAnalysisUsersCount: 5, duoAssignedUsersCount: 8 }}
      ${'duo_rca_usage_rate'}               | ${{ rootCauseAnalysisUsersCount: 0, duoAssignedUsersCount: 50 }}
    `('returns $identifier given $data', ({ identifier, data }) => {
      expect(extractGraphqlAiData(data)[identifier]).toMatchSnapshot();
    });
  });
});
