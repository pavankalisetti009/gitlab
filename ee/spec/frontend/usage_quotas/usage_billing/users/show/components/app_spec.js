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
import PaidTierTrialPeriodView from 'ee/usage_quotas/usage_billing/components/paid_tier_trial_period_view.vue';
import {
  mockDataWithPool,
  mockDataWithoutPool,
  mockDisabledStateData,
  mockPaidTierTrialData,
} from '../mock_data';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const PAGE_SIZE = 20;

describe('UsageBillingUserDashboardApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  /** @type { MockAdapter } */

  const MOCK_USER = mockDataWithPool.data.subscriptionUsage.usersUsage.users.nodes[0];
  const USERNAME = MOCK_USER.username;

  /** @type {jest.Mock} */
  let mockQueryHandler;

  const createComponent = ({ mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(UsageBillingUserDashboardApp, {
      apolloProvider: createMockApollo([[getUserSubscriptionUsageQuery, mockQueryHandler]]),
      provide: {
        username: USERNAME,
        namespacePath: null,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findUserAvatar = () => wrapper.findComponent(GlAvatar);
  const findIncludedCreditsCard = () => wrapper.findByTestId('included-credits-card');
  const findTotalUsageCard = () => wrapper.findByTestId('total-usage-card');
  const findEventsTable = () => wrapper.findComponent(EventsTable);
  const findDisabledStateAlert = () => wrapper.findByTestId('usage-billing-disabled-alert');

  beforeEach(() => {
    window.gon = {
      display_gitlab_credits_user_data: true,
      subscriptions_url: 'https://customers.gitlab.com/',
    };
  });

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
          username: USERNAME,
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
        expect(wrapper.text()).toContain(`@${USERNAME}`);
      });
    });

    describe('usage cards', () => {
      it('renders included credits card with correct values', () => {
        const card = findIncludedCreditsCard();

        expect(card.exists()).toBe(true);
        expect(card.text()).toMatchInterpolatedText(`1k / 1k included credits used this month`);
      });

      it('total usage card summarizes all credits usage', () => {
        const card = findTotalUsageCard();

        expect(card.exists()).toBe(true);
        expect(card.text()).toContain(`1.8k`);
      });
    });

    describe('events', () => {
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
  });

  describe('paid tier trial', () => {
    describe('when trial is active', () => {
      beforeEach(async () => {
        mockQueryHandler.mockResolvedValue(mockPaidTierTrialData);
        createComponent();
        await waitForPromises();
      });

      it('will render trial card', () => {
        const trialView = wrapper.findComponent(PaidTierTrialPeriodView);

        expect(trialView.exists()).toBe(true);
        expect(trialView.props()).toEqual({
          customersUsageDashboardUrl: 'https://customers.gitlab.com/subscriptions/A-S042/usage',
          purchaseCreditsUrl: 'https://customers.gitlab.com/purchase-credits-path',
        });
      });

      it('will not render other cards', () => {
        const usageBillingSection = wrapper.findByTestId('usage-billing-cards-row');

        expect(usageBillingSection.exists()).toBe(false);
      });
    });

    describe('when not on trial', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('will not render trial card', () => {
        const trialView = wrapper.findComponent(PaidTierTrialPeriodView);

        expect(trialView.exists()).toBe(false);
      });
    });
  });

  describe('disabled state alert', () => {
    describe('when Usage Billing is available', () => {
      beforeEach(async () => {
        mockQueryHandler.mockResolvedValue(mockDataWithoutPool);
        createComponent();
        await waitForPromises();
      });

      it('does not render alert if enabled is true', () => {
        expect(findDisabledStateAlert().exists()).toBe(false);
      });

      it('displays all other elements', () => {
        expect(wrapper.findByTestId('usage-billing-user-header').exists()).toBe(true);
        expect(wrapper.findByTestId('usage-billing-user-cards-row').exists()).toBe(true);
        expect(wrapper.findByTestId('usage-billing-user-events-list').exists()).toBe(true);
      });
    });

    describe('when Usage Billing is disabled', () => {
      beforeEach(async () => {
        mockQueryHandler.mockResolvedValue(mockDisabledStateData);
        createComponent();
        await waitForPromises();
      });

      it('renders disabled state alert', () => {
        expect(findDisabledStateAlert().exists()).toBe(true);
      });

      it('hides all other components', () => {
        expect(wrapper.findByTestId('usage-billing-user-header').exists()).toBe(false);
        expect(wrapper.findByTestId('usage-billing-user-cards-row').exists()).toBe(false);
        expect(wrapper.findByTestId('usage-billing-user-events-list').exists()).toBe(false);
      });
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
