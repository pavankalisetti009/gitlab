import codeSuggestionsAcceptanceRateByIde from 'ee/analytics/analytics_dashboards/data_sources/code_suggestions_acceptance_by_ide';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  DATE_RANGE_OPTION_LAST_90_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

const INVALID_DATE_RANGE = 'invalid-range';
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

describe('`Code suggestion acceptance rate by IDE` Data Source', () => {
  let res;

  const setAlerts = jest.fn();
  const setVisualizationOverrides = jest.fn();

  const fetch = async (args) => {
    res = await codeSuggestionsAcceptanceRateByIde({
      setAlerts,
      setVisualizationOverrides,
      ...defaultParams,
      ...args,
    });
  };

  const mockCodeSuggestionsIdeNames = ['', 'RubyMine', 'PyCharm'];

  const mockResolvedCodeSuggestionsByIdeQuery = (response = mockCodeSuggestionsIdeNames) =>
    jest
      .spyOn(defaultClient, 'query')
      .mockResolvedValueOnce(mockCodeSuggestionsResponse({ ideNames: response }));

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
        mockResolvedCodeSuggestionsByIdeQuery()
          .mockResolvedValueOnce(
            mockCodeSuggestionsResponse({
              acceptedCount: 3,
              shownCount: 4,
              ideNames: ['RubyMine'],
            }),
          )
          .mockResolvedValueOnce(
            mockCodeSuggestionsResponse({
              acceptedCount: 0,
              shownCount: 10,
              ideNames: ['PyCharm'],
            }),
          );

        return fetch();
      });

      it('fetches metrics for valid requested code suggestion IDEs', () => {
        const variables = {
          fullPath: 'test-namespace',
          startDate: '2020-04-07',
          endDate: '2020-07-06',
        };

        expect(defaultClient.query).toHaveBeenCalledTimes(3);
        expectQueryWithVariables(variables);
        expectQueryWithVariables({ ...variables, ideNames: 'RubyMine' });
        expectQueryWithVariables({ ...variables, ideNames: 'PyCharm' });
      });

      it('returns code suggestion acceptance metrics by IDE in ascending order', () => {
        expect(res).toEqual({
          'Suggestions accepted': [
            [0, 'PyCharm'],
            [3, 'RubyMine'],
          ],
          contextualData: {
            PyCharm: { acceptanceRate: 0, shownCount: 10 },
            RubyMine: { acceptanceRate: 0.75, shownCount: 4 },
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
    });

    describe('with no data available', () => {
      it('returns empty object when there are no code suggestion IDE names', async () => {
        mockResolvedCodeSuggestionsByIdeQuery([]);

        await fetch();

        expect(defaultClient.query).toHaveBeenCalledTimes(1);
        expect(res).toEqual({});
      });

      it.each([0, null])(
        'returns empty object when all code suggestion metrics are `%s`',
        async (value) => {
          const metrics = { acceptedCount: value, shownCount: value };

          mockResolvedCodeSuggestionsByIdeQuery(['VS Code', 'Neovim'])
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({
                ...metrics,
                ideNames: ['VS Code'],
              }),
            )
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({
                ...metrics,
                ideNames: ['Neovim'],
              }),
            );

          await fetch();

          expect(res).toEqual({});
        },
      );
    });

    describe('with invalid data', () => {
      it('filters out `null` acceptance rate when `shownCount` is 0', async () => {
        mockResolvedCodeSuggestionsByIdeQuery(['Neovim', 'Intellij'])
          .mockResolvedValueOnce(
            mockCodeSuggestionsResponse({
              acceptedCount: 1,
              shownCount: 0,
              ideNames: ['Intellij'],
            }),
          )
          .mockResolvedValueOnce(
            mockCodeSuggestionsResponse({
              acceptedCount: 50,
              shownCount: 100,
              ideNames: ['Intellij'],
            }),
          );

        await fetch();

        expect(res).toEqual({
          'Suggestions accepted': [[50, 'Intellij']],
          contextualData: {
            Intellij: { acceptanceRate: 0.5, shownCount: 100 },
          },
        });
      });
    });

    describe('with unsupported date range', () => {
      it('falls back to fetching data for `DATE_RANGE_OPTION_LAST_30_DAYS`', async () => {
        mockResolvedCodeSuggestionsByIdeQuery();

        await fetch({
          query: { dateRange: INVALID_DATE_RANGE },
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
        mockResolvedCodeSuggestionsByIdeQuery();

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
        mockResolvedCodeSuggestionsByIdeQuery();

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
          mockResolvedCodeSuggestionsByIdeQuery([
            'Visual Studio Code',
            'GitLab Web IDE',
            'RubyMine',
            'PyCharm',
          ])
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({
                acceptedCount: 1,
                shownCount: 5,
                ideNames: ['Visual Studio Code'],
              }),
            )
            .mockRejectedValueOnce({})
            .mockRejectedValueOnce({})
            .mockResolvedValueOnce(
              mockCodeSuggestionsResponse({
                acceptedCount: 3,
                shownCount: 10,
                ideNames: ['PyCharm'],
              }),
            );

          return fetch();
        });

        it('returns partial code suggestion acceptance by IDE', () => {
          expect(res).toEqual({
            'Suggestions accepted': [
              [1, 'Visual Studio Code'],
              [3, 'PyCharm'],
            ],
            contextualData: {
              'Visual Studio Code': { acceptanceRate: 0.2, shownCount: 5 },
              PyCharm: { acceptanceRate: 0.3, shownCount: 10 },
            },
          });
        });

        it('calls `setAlerts` and passes list of failed IDE names to warnings', () => {
          expect(setAlerts).toHaveBeenCalledWith({
            canRetry: true,
            warnings: expect.arrayContaining([
              'Failed to load metrics for: GitLab Web IDE, RubyMine',
            ]),
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
      });

      describe('fails to fetch any code suggestion metrics', () => {
        beforeEach(() => {
          mockResolvedCodeSuggestionsByIdeQuery().mockRejectedValue(new Error());

          return fetch();
        });

        it('calls `setAlerts` with generic error', () => {
          expect(setAlerts).toHaveBeenCalledWith({
            title: 'Failed to load dashboard panel.',
            errors: expect.arrayContaining(['Failed to load code suggestions data by IDE.']),
          });
        });

        it('returns empty object', () => {
          expect(res).toEqual({});
        });
      });
    });
  });
});
