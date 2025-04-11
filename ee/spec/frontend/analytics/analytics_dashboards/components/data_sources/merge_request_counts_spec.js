import fetch from 'ee/analytics/analytics_dashboards/data_sources/merge_request_counts';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import * as utils from 'ee/analytics/analytics_dashboards/components/filters/utils';
import {
  DATE_RANGE_OPTION_LAST_60_DAYS,
  DATE_RANGE_OPTION_LAST_365_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

const mockMergeRequestsCountsResponseData = {
  mergeRequests: {
    count: 10,
    totalTimeToMerge: 86400,
  },
};

const defaultFilters = {
  labels: null,
  notLabels: null,
  sourceBranches: null,
  targetBranches: null,
};
const mockMRCountsResponse = [
  {
    data: [
      ['May 2020', 10],
      ['Jun 2020', 10],
      ['Jul 2020', 10],
    ],
    name: 'Merge Requests merged',
  },
];

const mockResolvedQuery = ({ mergeRequests = [] } = {}) =>
  jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: { project: { mergeRequests } } });

const expectQueryWithVariables = (variables) =>
  expect(defaultClient.query).toHaveBeenCalledWith(
    expect.objectContaining({
      variables: expect.objectContaining({
        ...defaultFilters,
        ...variables,
      }),
    }),
  );

describe('Merge request counts data source', () => {
  let mockSetVisualizationOverrides;
  let res;

  const namespace = 'test-namespace';
  const interval = 'MONTHLY';
  const defaultQueryParams = {
    dateRange: DATE_RANGE_OPTION_LAST_60_DAYS,
  };

  afterEach(() => {
    jest.clearAllMocks();
  });

  beforeEach(() => {
    mockSetVisualizationOverrides = jest.fn();
    jest.spyOn(utils, 'getStartDate').mockReturnValue(new Date('2020-05-13'));
  });

  it('can override default query parameters', async () => {
    jest.spyOn(utils, 'getStartDate').mockReturnValue(new Date('2019-08-07'));
    mockResolvedQuery();

    res = await fetch({
      setVisualizationOverrides: mockSetVisualizationOverrides,
      namespace,
      query: {
        ...defaultQueryParams,
        dateRange: DATE_RANGE_OPTION_LAST_365_DAYS,
      },
      queryOverrides: {
        labels: ['a', 'b'],
        milestoneTitle: '101',
        authorUsername: 'Dr. Gero',
      },
    });

    // Check the first and last time periods
    [
      { startDate: '2019-08-07', endDate: '2019-09-01' },
      { startDate: '2020-07-01', endDate: '2020-07-07' },
    ].forEach(({ startDate, endDate }) => {
      expectQueryWithVariables({
        fullPath: namespace,
        interval,
        startDate,
        endDate,
        labels: ['a', 'b'],
        milestoneTitle: '101',
        authorUsername: 'Dr. Gero',
      });
    });

    expect(defaultClient.query).toHaveBeenCalledTimes(12);
  });

  describe('with data available', () => {
    beforeEach(async () => {
      mockResolvedQuery(mockMergeRequestsCountsResponseData);

      res = await fetch({
        setVisualizationOverrides: mockSetVisualizationOverrides,
        namespace,
        query: defaultQueryParams,
      });
    });

    it('requests all the time intervals', () => {
      expect(defaultClient.query).toHaveBeenCalledTimes(3);
    });

    it('sets the start and end date for each interval in the date range', () => {
      [
        { startDate: '2020-05-13', endDate: '2020-06-01' },
        { startDate: '2020-06-01', endDate: '2020-07-01' },
        { startDate: '2020-07-01', endDate: '2020-07-07' },
      ].forEach((dateParams) => {
        expectQueryWithVariables({
          ...dateParams,
          fullPath: namespace,
          interval,
        });
      });
    });

    it('returns each interval in the result', () => {
      const intervalNames = res[0].data.map(([name]) => name);
      expect(intervalNames).toEqual(['May 2020', 'Jun 2020', 'Jul 2020']);
    });

    it('returns a data series for MR counts', () => {
      expect(res).toMatchObject(mockMRCountsResponse);
    });
  });

  describe('with no data available', () => {
    beforeEach(async () => {
      mockResolvedQuery();

      res = await fetch({
        setVisualizationOverrides: mockSetVisualizationOverrides,
        namespace,
        query: defaultQueryParams,
      });
    });

    it('returns a null value for each interval in the result', () => {
      const dataSeries = res[0].data;
      const intervalNames = dataSeries.map(([name]) => name);
      const values = dataSeries.map(([, v]) => v);

      expect(intervalNames).toEqual(['May 2020', 'Jun 2020', 'Jul 2020']);
      expect(values).toEqual([null, null, null]);
    });
  });
});
