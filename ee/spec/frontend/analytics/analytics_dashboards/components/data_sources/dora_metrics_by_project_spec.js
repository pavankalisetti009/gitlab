import fetch from 'ee/analytics/analytics_dashboards/data_sources/dora_metrics_by_project';
import { mockDataSourceResponse } from 'ee_jest/analytics/dashboards/dora_projects_comparison/mock_data';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';

describe('Dora Metrics by project Data Source', () => {
  let res;

  describe('fetch', () => {
    beforeEach(async () => {
      jest.spyOn(defaultClient, 'query').mockResolvedValueOnce(mockDataSourceResponse);
      res = await fetch({ namespace: 'cool namespace' });
    });

    it('formats the DORA metrics for the list of projects', () => {
      expect(res).toMatchSnapshot();
    });
  });
});
