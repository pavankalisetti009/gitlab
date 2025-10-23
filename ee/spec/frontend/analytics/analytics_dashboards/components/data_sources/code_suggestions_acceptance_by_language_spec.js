import codeSuggestionsAcceptanceRateByLanguage from 'ee/analytics/analytics_dashboards/data_sources/code_suggestions_acceptance_by_language';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { LAST_180_DAYS, LAST_90_DAYS } from 'ee/analytics/dora/components/static_data/shared';

const mockCodeSuggestionsResponse = (response = {}) => ({
  data: {
    group: {
      aiMetrics: {
        codeSuggestions: { ...response, __typename: 'codeSuggestionMetrics' },
        __typename: 'AiMetrics',
      },
      __typename: 'Group',
    },
  },
});

const defaultParams = {
  namespace: 'test-namespace',
  query: { dateRange: LAST_90_DAYS },
};

describe('`Code suggestion acceptance rate by language` Data Source', () => {
  let res;

  const setAlerts = jest.fn();
  const setVisualizationOverrides = jest.fn();

  const fetch = async (args) => {
    res = await codeSuggestionsAcceptanceRateByLanguage({
      setAlerts,
      setVisualizationOverrides,
      ...defaultParams,
      ...args,
    });
  };

  const mockCodeSuggestionsLanguages = ['', 'js', 'ruby'];

  const mockResolvedCodeSuggestionsLanguagesQuery = (response = mockCodeSuggestionsLanguages) =>
    jest
      .spyOn(defaultClient, 'query')
      .mockResolvedValueOnce(mockCodeSuggestionsResponse({ languages: response }));

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining(variables),
      }),
    );

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('fetch', () => {
    describe('with data available', () => {
      beforeEach(() => {
        mockResolvedCodeSuggestionsLanguagesQuery()
          .mockResolvedValueOnce(
            mockCodeSuggestionsResponse({ acceptedCount: 3, shownCount: 4, languages: ['js'] }),
          )
          .mockResolvedValueOnce(
            mockCodeSuggestionsResponse({ acceptedCount: 5, shownCount: 10, languages: ['ruby'] }),
          );

        return fetch();
      });

      it('fetches metrics for valid requested code suggestion languages', () => {
        const variables = {
          fullPath: 'test-namespace',
          startDate: new Date('2020-04-08'),
          endDate: new Date('2020-07-07'),
        };

        expect(defaultClient.query).toHaveBeenCalledTimes(3);
        expectQueryWithVariables(variables);
        expectQueryWithVariables({ ...variables, languages: 'js' });
        expectQueryWithVariables({ ...variables, languages: 'ruby' });
      });

      it('returns code suggestion acceptance metrics by language in ascending order', () => {
        expect(res).toEqual({
          'Acceptance rate': [
            [0.5, 'Ruby'],
            [0.75, 'JavaScript'],
          ],
          contextualData: {
            JavaScript: { acceptedCount: 3, shownCount: 4 },
            Ruby: { acceptedCount: 5, shownCount: 10 },
          },
        });
      });

      it('calls `setVisualizationOverrides` with correct visualization title and chart options', () => {
        expect(setVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: expect.objectContaining({
            yAxis: {
              axisLabel: {
                formatter: expect.any(Function),
              },
            },
            xAxis: {
              axisLabel: {
                formatter: expect.any(Function),
              },
            },
          }),
        });
      });
    });

    describe('with no data available', () => {
      it('returns empty object when there are no code suggestion languages', async () => {
        mockResolvedCodeSuggestionsLanguagesQuery([]);

        await fetch();

        expect(defaultClient.query).toHaveBeenCalledTimes(1);
        expect(res).toEqual({});
      });

      it.each([0, null])(
        'returns empty object when all code suggestion metrics are `%s`',
        async (value) => {
          const metrics = { acceptedCount: value, shownCount: value };

          mockResolvedCodeSuggestionsLanguagesQuery(['ts', 'php'])
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({
                ...metrics,
                languages: ['ts'],
              }),
            )
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({
                ...metrics,
                languages: ['php'],
              }),
            );

          await fetch();

          expect(res).toEqual({});
        },
      );
    });

    describe('with invalid data', () => {
      it('filters out `null` acceptance rate when `shownCount` is 0', async () => {
        mockResolvedCodeSuggestionsLanguagesQuery(['ts', 'cpp'])
          .mockResolvedValueOnce(
            mockCodeSuggestionsResponse({ acceptedCount: 1, shownCount: 0, languages: ['ts'] }),
          )
          .mockResolvedValueOnce(
            mockCodeSuggestionsResponse({
              acceptedCount: 50,
              shownCount: 100,
              languages: ['cpp'],
            }),
          );

        await fetch();

        expect(res).toEqual({
          'Acceptance rate': [[0.5, 'C++']],
          contextualData: {
            'C++': { acceptedCount: 50, shownCount: 100 },
          },
        });
      });
    });

    describe('with unsupported date range', () => {
      it('falls back to fetching data for `LAST_30_DAYS`', async () => {
        mockResolvedCodeSuggestionsLanguagesQuery();

        await fetch({
          query: { dateRange: 'last_century' },
        });

        expectQueryWithVariables({
          fullPath: 'test-namespace',
          startDate: new Date('2020-06-07'),
          endDate: new Date('2020-07-07'),
        });
      });
    });

    describe('queryOverrides', () => {
      it('can override the date range', async () => {
        mockResolvedCodeSuggestionsLanguagesQuery();

        await fetch({
          queryOverrides: { dateRange: LAST_180_DAYS },
        });

        expectQueryWithVariables({
          fullPath: 'test-namespace',
          startDate: new Date('2020-01-09'),
          endDate: new Date('2020-07-07'),
        });
      });

      it('can override the namespace', async () => {
        mockResolvedCodeSuggestionsLanguagesQuery();

        await fetch({
          queryOverrides: { namespace: 'cool-namespace' },
        });

        expectQueryWithVariables({
          fullPath: 'cool-namespace',
          startDate: new Date('2020-04-08'),
          endDate: new Date('2020-07-07'),
        });
      });
    });

    describe('errors', () => {
      describe('fails to fetch some code suggestion metrics', () => {
        beforeEach(() => {
          mockResolvedCodeSuggestionsLanguagesQuery(['rust', 'cpp', 'sql', 'python'])
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({ acceptedCount: 1, shownCount: 5, languages: ['rust'] }),
            )
            .mockRejectedValueOnce({})
            .mockRejectedValueOnce({})
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({
                acceptedCount: 3,
                shownCount: 10,
                languages: ['python'],
              }),
            );

          return fetch();
        });

        it('returns partial code suggestion acceptance rates by language', () => {
          expect(res).toEqual({
            'Acceptance rate': [
              [0.2, 'Rust'],
              [0.3, 'Python'],
            ],
            contextualData: {
              Rust: { acceptedCount: 1, shownCount: 5 },
              Python: { acceptedCount: 3, shownCount: 10 },
            },
          });
        });

        it('calls `setAlerts` and passes list of failed languages to warnings', () => {
          expect(setAlerts).toHaveBeenCalledWith({
            canRetry: true,
            warnings: expect.arrayContaining(['Failed to load metrics for: C++, SQL']),
          });
        });
      });

      describe('fails to fetch any code suggestion metrics', () => {
        beforeEach(() => {
          mockResolvedCodeSuggestionsLanguagesQuery().mockRejectedValue(new Error());

          return fetch();
        });

        it('returns empty object', () => {
          expect(res).toEqual({});
        });
      });
    });
  });
});
