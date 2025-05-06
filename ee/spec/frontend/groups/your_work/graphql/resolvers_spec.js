import MockAdapter from 'axios-mock-adapter';
import dashboardGroupsWithChildrenResponse from 'test_fixtures/groups/dashboard/index_with_children.json';
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
    mockAxios.onGet(endpoint).reply(200, dashboardGroupsWithChildrenResponse);
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

    expect(nodes[0]).toMatchObject({
      isAdjournedDeletionEnabled: false,
      permanentDeletionDate: null,
      children: [
        {
          isAdjournedDeletionEnabled: false,
          permanentDeletionDate: null,
          children: [
            {
              isAdjournedDeletionEnabled: false,
              permanentDeletionDate: null,
            },
          ],
        },
      ],
    });
  });
});
