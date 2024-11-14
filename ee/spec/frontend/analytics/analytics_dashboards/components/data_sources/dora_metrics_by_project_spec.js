import doraMetricsByProject from 'ee/analytics/analytics_dashboards/data_sources/dora_metrics_by_project';
import { mockDataSourceResponse } from 'ee_jest/analytics/dashboards/dora_projects_comparison/mock_data';
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
    beforeEach(() => {
      jest.spyOn(defaultClient, 'query').mockResolvedValueOnce(mockDataSourceResponse);
      return fetch();
    });

    it('formats the DORA metrics for the list of projects', () => {
      expect(res).toMatchSnapshot();
    });
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
