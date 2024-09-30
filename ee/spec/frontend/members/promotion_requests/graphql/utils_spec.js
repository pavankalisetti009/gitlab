import GroupPendingMemberApprovalsQuery from 'ee/members/promotion_requests/graphql/group_pending_member_approvals.query.graphql';
import ProjectPendingMemberApprovalsQuery from 'ee/members/promotion_requests/graphql/project_pending_member_approvals.query.graphql';
import { evictCache, fetchCount } from 'ee/members/promotion_requests/graphql/utils';
import { createMockClient } from 'helpers/mock_apollo_helper';
import graphqlClientModule from '~/members/graphql_client';
import {
  groupDefaultProvide,
  groupPendingMemberApprovalsQueryMockData,
  projectDefaultProvide,
  projectPendingMemberApprovalsQueryMockData,
} from '../mock_data';

jest.mock('~/members/graphql_client', () => ({}));

describe('Utils', () => {
  /** @type {jest.Mock} */
  let groupHandler;
  /** @type {jest.Mock} */
  let projectHandler;

  beforeEach(() => {
    groupHandler = jest.fn();
    projectHandler = jest.fn();
    const requestHandlers = [
      [GroupPendingMemberApprovalsQuery, groupHandler],
      [ProjectPendingMemberApprovalsQuery, projectHandler],
    ];
    // eslint-disable-next-line import/no-named-as-default-member
    graphqlClientModule.graphqlClient = createMockClient(requestHandlers);
  });

  describe('evictCache', () => {
    beforeEach(() => {
      groupHandler.mockResolvedValue(groupPendingMemberApprovalsQueryMockData);
    });

    const makeAQuery = () => {
      // eslint-disable-next-line import/no-named-as-default-member
      return graphqlClientModule.graphqlClient.query({
        query: GroupPendingMemberApprovalsQuery,
        variables: {
          fullPath: 'any-path',
          first: 0,
        },
      });
    };

    it('will evict cache for a group', async () => {
      // first request uses the resolver fn
      await makeAQuery();
      expect(groupHandler).toHaveBeenCalledTimes(1);

      // second request uses the cached result
      await makeAQuery();
      expect(groupHandler).toHaveBeenCalledTimes(1);

      // after cache eviction we should use the resolver fn again
      const { context, group, project } = groupDefaultProvide;
      evictCache({ context, group, project });
      await makeAQuery();
      expect(groupHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('fetchCount', () => {
    describe('Group context', () => {
      it('will fetch the count', async () => {
        groupHandler.mockResolvedValue(groupPendingMemberApprovalsQueryMockData);
        const { context, group, project } = groupDefaultProvide;
        const count = await fetchCount({ context, group, project });
        expect(count).toBe(
          groupPendingMemberApprovalsQueryMockData.data.group.pendingMemberApprovals.count,
        );
      });
    });

    describe('Project context', () => {
      it('will fetch the count', async () => {
        projectHandler.mockResolvedValue(projectPendingMemberApprovalsQueryMockData);
        const { context, group, project } = projectDefaultProvide;
        const count = await fetchCount({ context, group, project });
        expect(count).toBe(
          projectPendingMemberApprovalsQueryMockData.data.project.pendingMemberApprovals.count,
        );
      });
    });
  });
});
