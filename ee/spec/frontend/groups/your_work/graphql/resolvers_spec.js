import MockAdapter from 'axios-mock-adapter';
import dashboardGroupsResponse from 'test_fixtures/groups/dashboard/index.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import { resolvers } from '~/groups/your_work/graphql/resolvers';
import memberGroupsQuery from '~/groups/your_work/graphql/queries/member_groups.query.graphql';
import axios from '~/lib/utils/axios_utils';

describe('your work groups resolver', () => {
  let mockApollo;
  let mockAxios;

  const endpoint = '/dashboard/groups.json';

  const makeQuery = () => {
    return mockApollo.clients.defaultClient.query({
      query: memberGroupsQuery,
      variables: { search: 'foo', sort: 'created_desc' },
    });
  };

  beforeEach(() => {
    mockApollo = createMockApollo([], resolvers(endpoint));

    mockAxios = new MockAdapter(axios);
    mockAxios.onGet(endpoint).reply(200, dashboardGroupsResponse);
  });

  afterEach(() => {
    mockApollo = null;
  });

  it('returns API call response correctly formatted for GraphQL', async () => {
    const {
      data: {
        groups: { nodes },
      },
    } = await makeQuery();

    expect(nodes[1]).toMatchObject({
      markedForDeletionOn: null,
      isAdjournedDeletionEnabled: false,
      permanentDeletionDate: null,
    });
  });
});
