import Vue from 'vue';
import { GlAlert } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import CurrentUsageCard from 'ee/usage_quotas/usage_billing/components/current_usage_card.vue';
import CurrentOverageUsageCard from 'ee/usage_quotas/usage_billing/components/current_overage_usage_card.vue';
import OneTimeCreditsCard from 'ee/usage_quotas/usage_billing/components/one_time_credits_card.vue';
import PurchaseCommitmentCard from 'ee/usage_quotas/usage_billing/components/purchase_commitment_card.vue';
import getSubscriptionUsageQuery from 'ee/usage_quotas/usage_billing/graphql/get_subscription_usage.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import UsageBillingApp from 'ee/usage_quotas/usage_billing/components/app.vue';
import UsageByUserTab from 'ee/usage_quotas/usage_billing/components/usage_by_user_tab.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import {
  usageDataNoPoolNoOverage,
  usageDataNoPoolWithOverage,
  usageDataWithPool,
  usageDataWithoutLastEventTransactionAt,
  usageDataWithOtcCredits,
} from '../mock_data';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('UsageBillingApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = ({
    mockQueryHandler = jest.fn().mockResolvedValue(usageDataWithPool),
  } = {}) => {
    wrapper = shallowMountExtended(UsageBillingApp, {
      apolloProvider: createMockApollo([[getSubscriptionUsageQuery, mockQueryHandler]]),
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findSkeletonLoaders = () => wrapper.findByTestId('skeleton-loaders');
  const findUsageByUserTab = () => wrapper.findComponent(UsageByUserTab);
  const findPageHeading = () => wrapper.findComponent(PageHeading);

  describe('loading state', () => {
    beforeEach(() => {
      const loadingQueryHandler = jest.fn().mockImplementation(() => new Promise(() => {}));

      createComponent({ mockQueryHandler: loadingQueryHandler });
    });

    it('shows only a loading icon when fetching data', () => {
      expect(findSkeletonLoaders().exists()).toBe(true);
      expect(findUsageByUserTab().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('rendering elements', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the page title with its description', () => {
      const pageHeading = findPageHeading();
      expect(pageHeading.text()).toContain('Usage Billing');
      expect(pageHeading.text()).toContain('Last updated:');
      expect(pageHeading.findComponent(UserDate).exists()).toBe(true);
    });

    it('renders current-usage-card', () => {
      expect(wrapper.findComponent(CurrentUsageCard).props()).toMatchObject({
        poolCreditsUsed: 50,
        poolTotalCredits: 300,
        monthStartDate: '2025-10-01',
        monthEndDate: '2025-10-31',
      });
    });

    it('renders purchase-commitment-card', () => {
      const purchaseCommitmentCard = wrapper.findComponent(PurchaseCommitmentCard);

      expect(purchaseCommitmentCard.exists()).toBe(true);
      expect(purchaseCommitmentCard.props('hasCommitment')).toBe(true);
    });

    it('renders usage by user tab', () => {
      expect(findUsageByUserTab().exists()).toBe(true);
    });

    describe('when lastEventTransactionAt is not provided', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue(usageDataWithoutLastEventTransactionAt),
        });
        await waitForPromises();
      });

      it('does not render the page heading description', () => {
        expect(findPageHeading().text()).not.toContain('Last updated:');
        expect(findPageHeading().findComponent(UserDate).exists()).toBe(false);
      });
    });

    describe('without purchase-credits-path', () => {
      beforeEach(async () => {
        const usageDataWithoutPurchaseCreditsPath = {
          data: {
            subscriptionUsage: {
              purchaseCreditsPath: null,
            },
          },
        };

        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue(usageDataWithoutPurchaseCreditsPath),
        });
        await waitForPromises();
      });

      it('does not render purchase-commitment-card', () => {
        expect(wrapper.findComponent(PurchaseCommitmentCard).exists()).toBe(false);
      });
    });

    it('does not render one-time-credits-card', () => {
      expect(wrapper.findComponent(OneTimeCreditsCard).exists()).toBe(false);
    });

    describe('with one-time credits data', () => {
      beforeEach(async () => {
        const mockQueryHandler = jest.fn().mockResolvedValue(usageDataWithOtcCredits);

        createComponent({ mockQueryHandler });
        await waitForPromises();
      });

      it('renders one-time-credits-card', () => {
        expect(wrapper.findComponent(OneTimeCreditsCard).props()).toMatchObject({
          remainingCredits: 500,
          usedCredits: 2500,
        });
      });
    });
  });

  describe('no pool with overage state', () => {
    beforeEach(async () => {
      createComponent({
        mockQueryHandler: jest.fn().mockResolvedValue(usageDataNoPoolWithOverage),
      });
      await waitForPromises();
    });

    it('will not render current-usage-card', () => {
      const currentUsageCard = wrapper.findComponent(CurrentUsageCard);

      expect(currentUsageCard.exists()).toBe(false);
    });

    it('will render current overage usage card', () => {
      const currentOverageUsageCard = wrapper.findComponent(CurrentOverageUsageCard);

      expect(currentOverageUsageCard.exists()).toBe(true);
      expect(currentOverageUsageCard.props()).toMatchObject({
        overageCreditsUsed: 50,
        monthStartDate: '2025-10-01',
        monthEndDate: '2025-10-31',
      });
    });

    it('will pass hasComitment to purchase-commitment-card', () => {
      const purchaseCommitmentCard = wrapper.findComponent(PurchaseCommitmentCard);

      expect(purchaseCommitmentCard.props('hasCommitment')).toBe(false);
    });
  });

  describe('no pool no overage state', () => {
    beforeEach(async () => {
      createComponent({ mockQueryHandler: jest.fn().mockResolvedValue(usageDataNoPoolNoOverage) });
      await waitForPromises();
    });

    it('will not render current-usage-card', () => {
      const currentUsageCard = wrapper.findComponent(CurrentUsageCard);

      expect(currentUsageCard.exists()).toBe(false);
    });

    it('will not render render current overage usage card', () => {
      const currentOverageUsageCard = wrapper.findComponent(CurrentOverageUsageCard);

      expect(currentOverageUsageCard.exists()).toBe(false);
    });

    it('will pass hasCommitment to purchase-commitment-card', () => {
      const purchaseCommitmentCard = wrapper.findComponent(PurchaseCommitmentCard);

      expect(purchaseCommitmentCard.props('hasCommitment')).toBe(false);
    });
  });

  describe('error state', () => {
    beforeEach(async () => {
      createComponent({
        mockQueryHandler: jest.fn().mockRejectedValue(new Error('Failed to fetch data from CDot')),
      });
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
