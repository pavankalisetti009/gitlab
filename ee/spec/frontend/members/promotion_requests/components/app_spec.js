import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlKeysetPagination, GlTable } from '@gitlab/ui';
import PromotionRequestsApp from 'ee/members/promotion_requests/components/app.vue';
import GroupPendingMemberApprovalsQuery from 'ee/members/promotion_requests/graphql/group_pending_member_approvals.query.graphql';
import ProjectPendingMemberApprovalsQuery from 'ee/members/promotion_requests/graphql/project_pending_member_approvals.query.graphql';
import { CONTEXT_TYPE } from 'ee/members/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { DEFAULT_PER_PAGE } from '~/api';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import UserDate from '~/vue_shared/components/user_date.vue';
import * as PromotionRequestListInvalidationService from 'ee/members/promotion_requests/services/promotion_request_list_invalidation_service';
import {
  groupDefaultProvide,
  groupPendingMemberApprovalsQueryMockData,
  projectDefaultProvide,
  projectPendingMemberApprovalsQueryMockData,
} from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('ee/members/promotion_requests/services/promotion_request_list_invalidation_service');

describe('PromotionRequestsApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findGlTable = () => wrapper.findComponent(GlTable);
  const findGlKeysetPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findGlAlert = () => wrapper.findComponent(GlAlert);

  const pendingMemberApprovalsQueryHandler = jest.fn();

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = mountExtended(PromotionRequestsApp, {
      provide: {
        ...provide,
      },
      apolloProvider: createMockApollo([
        [GroupPendingMemberApprovalsQuery, pendingMemberApprovalsQueryHandler],
        [ProjectPendingMemberApprovalsQuery, pendingMemberApprovalsQueryHandler],
      ]),
    });

    return nextTick();
  };

  const findTable = () => wrapper.findComponent(GlTable);

  beforeEach(() => {
    pendingMemberApprovalsQueryHandler.mockReset();
  });

  describe('mounted', () => {
    jest.spyOn(PromotionRequestListInvalidationService, 'subscribe');

    it('will subscribe to the invalidation service', async () => {
      await createComponent({ provide: groupDefaultProvide });
      expect(PromotionRequestListInvalidationService.subscribe).toHaveBeenCalledTimes(1);
    });

    it('will invalidate the pagination and refetch the store', async () => {
      pendingMemberApprovalsQueryHandler.mockResolvedValue(
        groupPendingMemberApprovalsQueryMockData,
      );

      await createComponent({ provide: groupDefaultProvide });
      await waitForPromises();

      expect(pendingMemberApprovalsQueryHandler).toHaveBeenCalledTimes(1);
      PromotionRequestListInvalidationService.subscribe.mock.calls[0][0]();
      expect(pendingMemberApprovalsQueryHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe.each([
    {
      context: CONTEXT_TYPE.GROUP,
      provide: groupDefaultProvide,
      mockData: groupPendingMemberApprovalsQueryMockData,
      result: groupPendingMemberApprovalsQueryMockData.data.group.pendingMemberApprovals,
    },
    {
      context: CONTEXT_TYPE.PROJECT,
      provide: projectDefaultProvide,
      mockData: projectPendingMemberApprovalsQueryMockData,
      result: projectPendingMemberApprovalsQueryMockData.data.project.pendingMemberApprovals,
    },
  ])('$context promotion requests', ({ provide, mockData, result }) => {
    beforeEach(async () => {
      pendingMemberApprovalsQueryHandler.mockResolvedValue(mockData);
      await createComponent({ provide });
      await waitForPromises();
    });

    describe('Pending promotion requests table', () => {
      it('renders the table with rows corresponding to mocked data', () => {
        expect(findTable().exists()).toBe(true);

        expect(findTable().findAll('tbody > tr').length).toEqual(result.nodes.length);
      });

      it('renders the mocked data properly inside a row', () => {
        const firstRowCells = findTable().findAll('tbody > tr').at(0).findAll('td');
        expect(firstRowCells.at(0).text()).toContain(result.nodes[0].user.name);
        expect(firstRowCells.at(1).text()).toBe(result.nodes[0].newAccessLevel.stringValue);
        expect(firstRowCells.at(2).text()).toBe(result.nodes[0].requestedBy.name);
        expect(firstRowCells.at(3).findComponent(UserDate).exists()).toBe(true);
        expect(firstRowCells.at(3).findComponent(UserDate).props('date')).toBe(
          result.nodes[0].createdAt,
        );
      });
    });

    describe('pagination', () => {
      it('will display the pagination', () => {
        const pagination = findGlKeysetPagination();
        const { endCursor, hasNextPage, hasPreviousPage, startCursor } = result.pageInfo;

        expect(pagination.props()).toEqual(
          expect.objectContaining({ endCursor, hasNextPage, hasPreviousPage, startCursor }),
        );
      });

      it('will emit pagination', async () => {
        const pagination = findGlKeysetPagination();
        const after = result.pageInfo.endCursor;
        pagination.vm.$emit('next', after);
        await waitForPromises();
        expect(pendingMemberApprovalsQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after,
            first: null,
            last: DEFAULT_PER_PAGE,
          }),
        );
      });
    });

    describe('Loading state', () => {
      beforeEach(async () => {
        pendingMemberApprovalsQueryHandler.mockReturnValue(new Promise(() => {}));
        createComponent({ provide });
        await waitForPromises();
      });

      it('will set :busy on the GlTable', () => {
        const table = findGlTable();
        expect(table.attributes()).toEqual(expect.objectContaining({ 'aria-busy': 'true' }));
      });

      it('will set disabled on the GlKeysetPagination props', () => {
        const pagination = findGlKeysetPagination();
        expect(pagination.props()).toEqual(expect.objectContaining({ disabled: true }));
      });
    });

    describe('Error state', () => {
      beforeEach(async () => {
        jest.spyOn(Sentry, 'captureException');
        pendingMemberApprovalsQueryHandler.mockRejectedValue({ error: Error('Error') });
        createComponent({ provide });
        await waitForPromises();
      });

      afterEach(() => {
        Sentry.captureException.mockRestore();
      });

      it('will display an error alert', () => {
        expect(findGlAlert().exists()).toBe(true);
      });

      it('will report the error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
      });
    });
  });
});
