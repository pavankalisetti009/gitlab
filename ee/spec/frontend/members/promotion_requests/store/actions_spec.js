import {
  invalidatePromotionRequestsData,
  refetchPromotionRequestsCount,
} from 'ee/members/promotion_requests/store/actions';
import * as listInvalidationService from 'ee/members/promotion_requests/services/promotion_request_list_invalidation_service';
import * as types from 'ee/members/promotion_requests/store/mutation_types';
import testAction from 'helpers/vuex_action_helper';
import { createMockClient } from 'helpers/mock_apollo_helper';
import graphqlClientModule from '~/members/graphql_client';
import GroupPendingMemberApprovalsQuery from 'ee/members/promotion_requests/graphql/group_pending_member_approvals.query.graphql';
import ProjectPendingMemberApprovalsQuery from 'ee/members/promotion_requests/graphql/project_pending_member_approvals.query.graphql';
import {
  groupDefaultProvide,
  groupPendingMemberApprovalsQueryMockData,
  projectDefaultProvide,
  projectPendingMemberApprovalsQueryMockData,
} from '../mock_data';

jest.mock('ee/members/promotion_requests/services/promotion_request_list_invalidation_service');
jest.mock('~/members/graphql_client', () => ({}));

describe('Actions', () => {
  let state;

  beforeEach(() => {
    state = {};
    jest.spyOn(listInvalidationService, 'invalidate');
  });

  describe('invalidatePromotionRequestsData', () => {
    it('will dispatch refetchPromotionRequestsCount', () => {
      const { group, project } = groupDefaultProvide;
      testAction(
        invalidatePromotionRequestsData,
        { group, project },
        state,
        [],
        [{ type: 'refetchPromotionRequestsCount', payload: { group, project } }],
      );
      expect(listInvalidationService.invalidate).toHaveBeenCalled();
    });
  });

  describe('refetchPromotionRequestsCount', () => {
    describe('Group context', () => {
      /** @type {jest.Mock} */
      let groupHandler;

      beforeEach(() => {
        groupHandler = jest.fn();
        const requestHandlers = [[GroupPendingMemberApprovalsQuery, groupHandler]];
        // eslint-disable-next-line import/no-named-as-default-member
        graphqlClientModule.graphqlClient = createMockClient(requestHandlers);
      });

      it('will reset the counter', async () => {
        groupHandler.mockResolvedValue(groupPendingMemberApprovalsQueryMockData);
        const { group, project } = groupDefaultProvide;

        await testAction(
          refetchPromotionRequestsCount,
          { group, project },
          state,
          [{ type: types.UPDATE_TOTAL_ITEMS, payload: 2 }],
          [],
        );
      });
    });

    describe('Project context', () => {
      /** @type {jest.Mock} */
      let projectHandler;

      beforeEach(() => {
        projectHandler = jest.fn();
        const requestHandlers = [[ProjectPendingMemberApprovalsQuery, projectHandler]];
        // eslint-disable-next-line import/no-named-as-default-member
        graphqlClientModule.graphqlClient = createMockClient(requestHandlers);
      });

      it('will reset the counter', async () => {
        const { group, project } = projectDefaultProvide;

        projectHandler.mockResolvedValue(projectPendingMemberApprovalsQueryMockData);

        await testAction(
          refetchPromotionRequestsCount,
          { group, project },
          state,
          [{ type: types.UPDATE_TOTAL_ITEMS, payload: 2 }],
          [],
        );
      });
    });
  });
});
