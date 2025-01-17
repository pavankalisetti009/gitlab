import { extractGraphqlAiData } from 'ee/analytics/dashboards/ai_impact/api';

describe('AI impact dashboard api', () => {
  describe('extractGraphqlAiData', () => {
    const buildResponse = (
      [codeSuggestionsContributorsCount, codeContributorsCount],
      [codeSuggestionsAcceptedCount, codeSuggestionsShownCount],
    ) => ({
      codeSuggestionsContributorsCount,
      codeContributorsCount,
      codeSuggestionsAcceptedCount,
      codeSuggestionsShownCount,
    });

    it.each([
      buildResponse([undefined, 5], [undefined, 4]),
      buildResponse([2, undefined], [3, undefined]),
      buildResponse([5, 10], [3, 4]),
      buildResponse([0, 10], [0, 20]),
    ])('extracts data correctly when response is %s', (response) => {
      expect(extractGraphqlAiData(response)).toMatchSnapshot();
    });
  });
});
