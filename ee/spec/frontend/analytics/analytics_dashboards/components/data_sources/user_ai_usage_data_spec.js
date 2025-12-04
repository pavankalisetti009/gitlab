import fetch from 'ee/analytics/analytics_dashboards/data_sources/user_ai_usage_data';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';

import {
  DATE_RANGE_OPTION_LAST_30_DAYS,
  DATE_RANGE_OPTION_LAST_60_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

const mockPageInfo = {
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: 'this-is-a-start-cursor',
  endCursor: 'this-is-an-end-cursor',
  __typename: 'PageInfo',
};

const mockUserOne = {
  id: 'gid://gitlab/User/106',
  name: 'P Dawn Turner',
  avatarUrl:
    'https://www.gravatar.com/avatar/3dd3516a13d37b25b66c7915ab9bedfe7b20ffaf32da3f50c3cb5ee9f3f8aba6?s=80\u0026d=identicon',
  username: 'p-user-dawn-turner-e5c194af9850',
  webUrl: 'http://gdk.test:3001/p-user-dawn-turner-e5c194af9850',
  lastDuoActivityOn: '2025-10-01',
  __typename: 'AddOnUser',
};

const mockUserTwo = {
  id: 'gid://gitlab/User/105',
  name: 'P Homer Hodkiewicz',
  avatarUrl:
    'https://www.gravatar.com/avatar/142fcdcab9580b9edd2b623335dde4e6559a628daea89773acf60ba419da66bb?s=80\u0026d=identicon',
  username: 'p-user-homer-hodkiewicz-e5c194af9850',
  webUrl: 'http://gdk.test:3001/p-user-homer-hodkiewicz-e5c194af9850',
  lastDuoActivityOn: '2025-10-04',
  __typename: 'AddOnUser',
};

const nullValueUser = {
  user: mockUserOne,
  codeReview: null,
  codeSuggestions: null,
  troubleshootJob: null,
  __typename: 'AiUserMetrics',
};

const zeroValueUser = {
  user: mockUserTwo,
  codeSuggestions: {
    codeSuggestionAcceptedInIdeEventCount: 0,
    codeSuggestionShownInIdeEventCount: 0,
    __typename: 'codeSuggestionsUserMetrics',
  },
  codeReview: {
    requestReviewDuoCodeReviewOnMrByAuthorEventCount: 0,
    reactThumbsDownOnDuoCodeReviewCommentEventCount: 0,
    reactThumbsUpOnDuoCodeReviewCommentEventCount: 0,
    __typename: 'codeReviewUserMetrics',
  },
  troubleshootJob: {
    troubleshootJobEventCount: 0,
    __typename: 'troubleshootJobUserMetrics',
  },
  __typename: 'AiUserMetrics',
};

const mockUserAiMetrics = [
  zeroValueUser,
  {
    user: mockUserOne,
    codeSuggestions: {
      codeSuggestionAcceptedInIdeEventCount: 1,
      codeSuggestionShownInIdeEventCount: 3,
      __typename: 'codeSuggestionsUserMetrics',
    },
    codeReview: {
      requestReviewDuoCodeReviewOnMrByAuthorEventCount: 10,
      reactThumbsDownOnDuoCodeReviewCommentEventCount: 5,
      reactThumbsUpOnDuoCodeReviewCommentEventCount: 3,
      __typename: 'codeReviewUserMetrics',
    },
    troubleshootJob: {
      troubleshootJobEventCount: 3,
      __typename: 'troubleshootJobUserMetrics',
    },
    __typename: 'AiUserMetrics',
  },
];

const mockUserAiMetricsMissingFields = [nullValueUser];

const mockUserAiUsageDataResponseData = (nodes = mockUserAiMetrics) => ({
  aiUserMetrics: {
    nodes,
    pageInfo: mockPageInfo,
  },
});

const mockResolvedQuery = ({ aiUserMetrics = [] } = {}) =>
  jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: { project: { aiUserMetrics } } });

const expectQueryWithVariables = (variables) =>
  expect(defaultClient.query).toHaveBeenCalledWith(
    expect.objectContaining({
      variables: expect.objectContaining({
        ...variables,
      }),
    }),
  );

describe('User ai usage data source', () => {
  let res;

  const namespace = 'test-namespace';
  const defaultQueryParams = {
    dateRange: DATE_RANGE_OPTION_LAST_30_DAYS,
  };

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('can override default query parameters', async () => {
    mockResolvedQuery();

    res = await fetch({
      namespace,
      query: {
        ...defaultQueryParams,
        dateRange: DATE_RANGE_OPTION_LAST_60_DAYS,
      },
    });

    expectQueryWithVariables({
      fullPath: namespace,
      startDate: new Date('2020-05-08'),
      endDate: new Date('2020-07-07'),
    });

    expect(defaultClient.query).toHaveBeenCalledTimes(1);
  });

  it('can override default pagination', async () => {
    mockResolvedQuery();

    res = await fetch({
      namespace,
      query: {
        ...defaultQueryParams,
      },
      queryOverrides: {
        pagination: { startCursor: 'start' },
      },
    });

    expectQueryWithVariables({
      fullPath: namespace,
      startDate: new Date('2020-06-07'),
      endDate: new Date('2020-07-07'),
      before: 'start',
    });

    expect(defaultClient.query).toHaveBeenCalledTimes(1);
  });

  describe('with data available', () => {
    beforeEach(async () => {
      mockResolvedQuery(mockUserAiUsageDataResponseData());

      res = await fetch({
        namespace,
        query: defaultQueryParams,
      });
    });

    it('sets the correct query parameters', () => {
      expectQueryWithVariables({
        fullPath: namespace,
        startDate: new Date('2020-06-07'),
        endDate: new Date('2020-07-07'),
      });

      expect(defaultClient.query).toHaveBeenCalledTimes(1);
    });

    it('returns data and pagination information', () => {
      expect(res).toMatchSnapshot();
    });
  });

  describe('with no data available', () => {
    beforeEach(async () => {
      mockResolvedQuery();

      res = await fetch({
        namespace,
        query: defaultQueryParams,
      });
    });

    it('returns an empty object', () => {
      expect(res).toEqual({});
    });
  });

  describe('when fields are not available', () => {
    it('correctly returns an empty object', async () => {
      mockResolvedQuery(mockUserAiUsageDataResponseData(mockUserAiMetricsMissingFields));

      res = await fetch({
        namespace,
        query: defaultQueryParams,
      });

      expect(res).toEqual({});
    });

    it('is not empty if the field is available in any of the nodes', async () => {
      mockResolvedQuery(
        mockUserAiUsageDataResponseData([...mockUserAiMetricsMissingFields, zeroValueUser]),
      );

      res = await fetch({
        namespace,
        query: defaultQueryParams,
      });

      expect(res.nodes).toMatchSnapshot();
    });
  });
});
