import codeSuggestionsAcceptanceByLanguage from 'ee/analytics/analytics_dashboards/data_sources/code_suggestions_acceptance_by_language';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  DATE_RANGE_OPTION_LAST_90_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

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
  query: { dateRange: DATE_RANGE_OPTION_LAST_90_DAYS },
};

describe('`Code suggestion acceptance by language` Data Source', () => {
  let res;

  const setAlerts = jest.fn();
  const setVisualizationOverrides = jest.fn();

  const fetch = async (args) => {
    res = await codeSuggestionsAcceptanceByLanguage({
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
          startDate: '2020-04-07',
          endDate: '2020-07-06',
        };

        expect(defaultClient.query).toHaveBeenCalledTimes(3);
        expectQueryWithVariables(variables);
        expectQueryWithVariables({ ...variables, languages: 'js' });
        expectQueryWithVariables({ ...variables, languages: 'ruby' });
      });

      it('returns code suggestion acceptance metrics by language in ascending order', () => {
        expect(res).toEqual({
          'Suggestions accepted': [
            [3, 'JavaScript'],
            [5, 'Ruby'],
          ],
          contextualData: {
            JavaScript: { acceptanceRate: 0.75, shownCount: 4 },
            Ruby: { acceptanceRate: 0.5, shownCount: 10 },
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
          }),
        });
      });

      describe('with multiple language variants', () => {
        it('should merge metrics for language variants into single entry and sum counts', async () => {
          mockResolvedCodeSuggestionsLanguagesQuery(['js', 'javascript', 'php'])
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({ acceptedCount: 4, shownCount: 8, languages: ['js'] }),
            )
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({
                acceptedCount: 12,
                shownCount: 24,
                languages: ['javascript'],
              }),
            )
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({
                acceptedCount: 4,
                shownCount: 10,
                languages: ['php'],
              }),
            );

          await fetch();

          expect(res).toEqual({
            'Suggestions accepted': [
              [4, 'PHP'],
              [16, 'JavaScript'],
            ],
            contextualData: {
              JavaScript: {
                acceptanceRate: 0.5,
                shownCount: 32,
              },
              PHP: {
                acceptanceRate: 0.4,
                shownCount: 10,
              },
            },
          });
        });

        it('should exclude variants with a null count', async () => {
          mockResolvedCodeSuggestionsLanguagesQuery(['kt', 'kts', 'cpp', 'cc'])
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({ acceptedCount: 3, shownCount: 12, languages: ['kt'] }),
            )
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({
                acceptedCount: null,
                shownCount: 18,
                languages: ['kts'],
              }),
            )
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({ acceptedCount: 5, shownCount: 10, languages: ['cpp'] }),
            )
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({
                acceptedCount: null,
                shownCount: null,
                languages: ['cc'],
              }),
            );

          await fetch();

          expect(res).toEqual({
            'Suggestions accepted': [
              [3, 'Kotlin'],
              [5, 'C++'],
            ],
            contextualData: {
              'C++': {
                acceptanceRate: 0.5,
                shownCount: 10,
              },
              Kotlin: {
                acceptanceRate: 0.25,
                shownCount: 12,
              },
            },
          });
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
          'Suggestions accepted': [[50, 'C++']],
          contextualData: {
            'C++': { acceptanceRate: 0.5, shownCount: 100 },
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
          startDate: '2020-06-06',
          endDate: '2020-07-06',
        });
      });
    });

    describe('queryOverrides', () => {
      it('can override the date range', async () => {
        mockResolvedCodeSuggestionsLanguagesQuery();

        await fetch({
          queryOverrides: { dateRange: DATE_RANGE_OPTION_LAST_180_DAYS },
        });

        expectQueryWithVariables({
          fullPath: 'test-namespace',
          startDate: '2020-01-08',
          endDate: '2020-07-06',
        });
      });

      it('can override the namespace', async () => {
        mockResolvedCodeSuggestionsLanguagesQuery();

        await fetch({
          queryOverrides: { namespace: 'cool-namespace' },
        });

        expectQueryWithVariables({
          fullPath: 'cool-namespace',
          startDate: '2020-04-07',
          endDate: '2020-07-06',
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

        it('returns partial code suggestion acceptance metrics by language', () => {
          expect(res).toEqual({
            'Suggestions accepted': [
              [1, 'Rust'],
              [3, 'Python'],
            ],
            contextualData: {
              Rust: { acceptanceRate: 0.2, shownCount: 5 },
              Python: { acceptanceRate: 0.3, shownCount: 10 },
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

        it('calls `setAlerts` with generic error', () => {
          expect(setAlerts).toHaveBeenCalledWith({
            title: 'Failed to load dashboard panel.',
            errors: expect.arrayContaining(['Failed to load code suggestions data by language.']),
          });
        });

        it('returns empty object', () => {
          expect(res).toEqual({});
        });
      });
    });
  });
});
