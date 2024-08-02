import { mockAiMetricsResponseData } from 'ee_jest/analytics/dashboards/ai_impact/mock_data';
import fetch from 'ee/analytics/analytics_dashboards/data_sources/ai_impact_over_time';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { LAST_WEEK, LAST_30_DAYS, LAST_180_DAYS } from 'ee/dora/components/static_data/shared';

describe('AI Impact Over Time Data Source', () => {
  let res;

  const query = { metric: 'code_suggestions_usage_rate', dateRange: LAST_30_DAYS };
  const namespace = 'cool namespace';
  const defaultParams = {
    namespace,
    query,
  };

  const mockResolvedQuery = (response = mockAiMetricsResponseData) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValueOnce({ data: { group: response } });

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining(variables),
      }),
    );

  describe('fetch', () => {
    describe('default', () => {
      beforeEach(async () => {
        mockResolvedQuery();
        res = await fetch({ namespace, query });
      });

      it('returns a single value', () => {
        expect(res).toBe('62.5');
      });

      it('correctly applies query parameters', () => {
        expectQueryWithVariables({
          startDate: new Date('2020-06-07'),
          endDate: new Date('2020-07-07'),
          fullPath: namespace,
        });
      });
    });

    describe('setVisualizationOverrides callback', () => {
      let mockSetVisualizationOverrides;

      beforeEach(async () => {
        mockSetVisualizationOverrides = jest.fn();

        mockResolvedQuery();
        res = await fetch({
          namespace,
          query,
          setVisualizationOverrides: mockSetVisualizationOverrides,
        });
      });

      it('will call the setVisualizationOverrides callback', () => {
        expect(mockSetVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: {
            title: 'Last 30 days',
            titleIcon: 'clock',
          },
        });
      });
    });

    describe('queryOverrides', () => {
      const mockQuery = (
        dateRange,
        {
          namespace: namespaceParam = 'cool namespace',
          metric = 'code_suggestions_usage_rate',
        } = {},
      ) => {
        mockResolvedQuery();

        return fetch({
          ...defaultParams,
          query: { ...defaultParams.query, metric },
          queryOverrides: { dateRange, namespace: namespaceParam },
        });
      };

      it('can override the date range', async () => {
        res = await mockQuery(LAST_WEEK);

        expectQueryWithVariables({
          startDate: new Date('2020-06-30'),
          endDate: new Date('2020-07-07'),
          fullPath: namespace,
        });
      });

      it('can override the metric queried', async () => {
        res = await mockQuery(LAST_WEEK, { metric: 'code_suggestions_acceptance_rate' });

        expectQueryWithVariables({
          startDate: new Date('2020-06-30'),
          endDate: new Date('2020-07-07'),
          fullPath: namespace,
        });

        expect(res).toBe('40.0');
      });

      it('can override the namespace', async () => {
        res = await mockQuery(LAST_WEEK, { namespace: 'cool-namespace/sub-namespace' });

        expectQueryWithVariables({
          startDate: new Date('2020-06-30'),
          endDate: new Date('2020-07-07'),
          fullPath: 'cool-namespace/sub-namespace',
        });
      });

      it('will default to LAST_180_DAYS when given an invalid dateRange', async () => {
        res = await mockQuery('LAST_45_DAYS');

        expectQueryWithVariables({
          startDate: new Date('2020-01-09'),
          endDate: new Date('2020-07-07'),
          fullPath: namespace,
        });

        const defaultRes = await mockQuery(LAST_180_DAYS);
        expect(defaultRes).toEqual(res);
      });
    });
  });
});
