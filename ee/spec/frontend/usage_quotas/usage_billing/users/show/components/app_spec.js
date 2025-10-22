import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlKeysetPagination, GlAlert, GlAvatar, GlLoadingIcon } from '@gitlab/ui';
import UsageBillingUserDashboardApp from 'ee/usage_quotas/usage_billing/users/show/components/app.vue';
import EventsTable from 'ee/usage_quotas/usage_billing/users/show/components/events_table.vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import getUserSubscriptionUsageQuery from 'ee/usage_quotas/usage_billing/users/show/graphql/get_user_subscription_usage.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockDataWithPool, mockDataWithoutPool } from '../mock_data';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const PAGE_SIZE = 20;

describe('UsageBillingUserDashboardApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  /** @type { MockAdapter } */

  const MOCK_USER = mockDataWithPool.data.subscriptionUsage.usersUsage.users.nodes[0];
  const MOCK_USAGE = MOCK_USER.usage;
  const USER_ID = MOCK_USER.id;

  /** @type {jest.Mock} */
  let mockQueryHandler;

  const createComponent = ({ mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(UsageBillingUserDashboardApp, {
      apolloProvider: createMockApollo([[getUserSubscriptionUsageQuery, mockQueryHandler]]),
      provide: {
        userId: USER_ID,
        namespacePath: null,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findUserAvatar = () => wrapper.findComponent(GlAvatar);
  const findMonthSummaryCard = () => wrapper.findByTestId('month-summary-card');
  const findMonthPoolCard = () => wrapper.findByTestId('month-pool-card');
  const findTotalUsageCard = () => wrapper.findByTestId('total-usage-card');
  const findEventsTable = () => wrapper.findComponent(EventsTable);

  beforeEach(() => {
    mockQueryHandler = jest.fn();
  });

  describe('loading state', () => {
    beforeEach(async () => {
      mockQueryHandler.mockImplementation(() => new Promise(() => {}));
      createComponent();
      await waitForPromises();
    });

    it('shows only a loading icon when fetching data', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('loaded state', () => {
    beforeEach(async () => {
      mockQueryHandler.mockResolvedValue(mockDataWithPool);
      createComponent();
      await waitForPromises();
    });

    it('calls the API with username', () => {
      expect(mockQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          username: USER_ID,
          first: PAGE_SIZE,
          last: null,
          after: null,
          before: null,
        }),
      );
    });

    describe('header', () => {
      it('renders user avatar', () => {
        expect(findUserAvatar().exists()).toBe(true);
        expect(findUserAvatar().props('src')).toBe(MOCK_USER.avatarUrl);
      });

      it('renders user info', () => {
        expect(wrapper.text()).toContain(MOCK_USER.name);
        expect(wrapper.text()).toContain(`@${MOCK_USER.username}`);
      });
    });

    describe('usage cards', () => {
      it('renders month summary card with correct values', () => {
        const card = findMonthSummaryCard();
        expect(card.exists()).toBe(true);
        expect(card.text()).toContain(`${MOCK_USAGE.creditsUsed} / ${MOCK_USAGE.totalCredits}`);
      });

      it('renders month pool card with correct values', () => {
        const card = findMonthPoolCard();
        expect(card.exists()).toBe(true);
        expect(card.text()).toContain(`${MOCK_USAGE.poolCreditsUsed}`);
      });

      it('renders total usage card with correct values', () => {
        const card = findTotalUsageCard();
        const totalCreditsUsed =
          MOCK_USAGE.creditsUsed + MOCK_USAGE.overageCreditsUsed + MOCK_USAGE.poolCreditsUsed;

        expect(card.exists()).toBe(true);
        expect(card.text()).toContain(`${totalCreditsUsed}`);
      });
    });

    // NOTE: temporarily disabling specs for we don't have events field yet
    // eslint-disable-next-line jest/no-disabled-tests
    describe.skip('events', () => {
      it('renders the events table', () => {
        const eventsTable = findEventsTable();

        expect(eventsTable.exists()).toBe(true);
        expect(eventsTable.props('events')).toStrictEqual(MOCK_USER.events.nodes);
      });

      describe('pagination', () => {
        const findPagination = () => wrapper.findComponent(GlKeysetPagination);

        beforeEach(async () => {
          createComponent({ mountFn: mountExtended });
          await waitForPromises();
        });

        it('calls the graphql query on load', () => {
          expect(mockQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({
              after: null,
              before: null,
              first: PAGE_SIZE,
              last: null,
            }),
          );
        });

        it('will render the pagination', () => {
          const { hasNextPage, hasPreviousPage, startCursor, endCursor } =
            MOCK_USER.events.pageInfo;

          expect(findPagination().exists()).toBe(true);
          expect(findPagination().props()).toEqual(
            expect.objectContaining({
              hasNextPage,
              hasPreviousPage,
              startCursor,
              endCursor,
            }),
          );
        });

        it('navigates to next page', async () => {
          mockQueryHandler.mockClear();

          findPagination().vm.$emit('next', '42');
          await nextTick();

          expect(mockQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({
              after: '42',
              before: null,
              first: PAGE_SIZE,
              last: null,
            }),
          );
        });

        it('navigates to prev page', async () => {
          mockQueryHandler.mockClear();

          findPagination().vm.$emit('prev', '37');
          await nextTick();

          expect(mockQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({
              after: null,
              before: '37',
              first: null,
              last: PAGE_SIZE,
            }),
          );
        });
      });
    });
  });

  describe('no commitment state', () => {
    beforeEach(async () => {
      mockQueryHandler.mockResolvedValue(mockDataWithoutPool);
      createComponent();
      await waitForPromises();
    });

    it('will not render the pool usage card', () => {
      const card = findMonthPoolCard();
      expect(card.exists()).toBe(false);
    });
  });

  describe('error state', () => {
    beforeEach(async () => {
      mockQueryHandler.mockRejectedValue(new Error('Network Error'));
      createComponent();
      await waitForPromises();
    });

    it('shows error alert when API request fails', () => {
      const alert = findAlert();
      expect(alert.text()).toBe('An error occurred while fetching data');
    });

    it('logs the error to console and Sentry', () => {
      expect(logError).toHaveBeenCalledWith(expect.any(Error));
      expect(captureException).toHaveBeenCalledWith(expect.any(Error));
    });
  });
});
