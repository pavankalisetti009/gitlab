import doraMetricsByProject from 'ee/analytics/analytics_dashboards/data_sources/dora_metrics_by_project';
import {
  mockDataSourceResponses,
  mockLegacyDataSourceResponses,
} from 'ee_jest/analytics/dashboards/dora_projects_comparison/mock_data';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';

describe('Dora Metrics by project Data Source', () => {
  const setAlerts = jest.fn();

  let res;

  const fetch = async (args) => {
    res = await doraMetricsByProject({
      namespace: 'cool namespace',
      isProject: false,
      setAlerts,
      ...args,
    });
  };

  describe('for group', () => {
    describe.each`
      doraProjectsComparisonSubgroups | responses
      ${true}                         | ${mockDataSourceResponses}
      ${false}                        | ${mockLegacyDataSourceResponses}
    `(
      'when doraProjectsComparisonSubgroups=$doraProjectsComparisonSubgroups',
      ({ doraProjectsComparisonSubgroups, responses }) => {
        beforeEach(() => {
          gon.features = { doraProjectsComparisonSubgroups };
          jest
            .spyOn(defaultClient, 'query')
            .mockResolvedValueOnce(responses[0])
            .mockResolvedValueOnce(responses[1]);
          return fetch();
        });

        it('requests data until pagination completes', () => {
          const variables = {
            startDate: '2020-05-01',
            endDate: '2020-06-30',
            fullPath: 'cool namespace',
            interval: 'MONTHLY',
          };

          expect(defaultClient.query).toHaveBeenCalledTimes(2);
          expect(defaultClient.query).toHaveBeenCalledWith(expect.objectContaining({ variables }));
          expect(defaultClient.query).toHaveBeenCalledWith(
            expect.objectContaining({
              variables: {
                ...variables,
                after: 'page1',
              },
            }),
          );
        });

        it('formats the DORA metrics for the list of projects', () => {
          expect(res).toMatchSnapshot();
        });
      },
    );
  });

  describe('for project', () => {
    beforeEach(() => {
      return fetch({ isProject: true });
    });

    it('calls setAlerts with an error', () => {
      expect(setAlerts).toHaveBeenCalledWith({
        canRetry: false,
        title: 'Failed to load dashboard panel.',
        errors: expect.arrayContaining([
          'This visualization is not supported for project namespaces.',
        ]),
      });
    });

    it('returns undefined', () => {
      expect(res).toBeUndefined();
    });
  });
});
