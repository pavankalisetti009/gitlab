import Vue from 'vue';
import { GlAlert } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import CurrentUsageCard from 'ee/usage_quotas/usage_billing/components/current_usage_card.vue';
import CurrentOverageUsageCard from 'ee/usage_quotas/usage_billing/components/current_overage_usage_card.vue';
import MonthlyWaiverCard from 'ee/usage_quotas/usage_billing/components/monthly_waiver_card.vue';
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
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import {
  usageDataNoCommitmentNoMonthlyWaiverNoOverage,
  usageDataNoCommitmentWithOverage,
  usageDataWithCommitment,
  usageDataWithoutLastEventTransactionAt,
  usageDataCommitmentWithMonthlyWaiver,
  usageDataCommitmentWithMonthlyWaiverWithOverage,
} from '../mock_data';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('UsageBillingApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = ({
    mockQueryHandler = jest.fn().mockResolvedValue(usageDataWithCommitment),
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

    describe('page header', () => {
      it('renders the page title with its description', () => {
        const pageHeading = findPageHeading();

        expect(pageHeading.text()).toContain('Usage Billing');
      });

      it('renders the page billing period subtitle', () => {
        const pageHeading = findPageHeading();

        expect(pageHeading.text()).toContain('Billing period:');
        expect(pageHeading.findComponent(HumanTimeframe).exists()).toBe(true);
        expect(pageHeading.findComponent(HumanTimeframe).props()).toEqual({
          from: '2025-10-01',
          till: '2025-10-31',
        });
      });

      it('renders last event transaction at', () => {
        const pageHeading = findPageHeading();

        expect(pageHeading.text()).toContain('Last event transaction at:');
        expect(pageHeading.findComponent(UserDate).exists()).toBe(true);
        expect(pageHeading.findComponent(UserDate).props('date')).toBe('2025-10-14T07:41:59Z');
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

    describe('without lastEventTransactionAt', () => {
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

    describe('without purchaseCreditsPath', () => {
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
  });

  describe('summary cards visibility', () => {
    describe.each`
      scenario                                                      | currentUsageCard | monthlyWaiverCard | currentOverageUsageCard | monthlyCommitment                        | monthlyWaiver                              | overage
      ${'monthly commitment'}                                       | ${true}          | ${false}          | ${false}                | ${{ creditsUsed: 10, totalCredits: 24 }} | ${null}                                    | ${{ isAllowed: false, creditsUsed: 0 }}
      ${'monthly commitment with monthly waiver'}                   | ${true}          | ${true}           | ${false}                | ${{ creditsUsed: 10, totalCredits: 24 }} | ${{ creditsUsed: 50, totalCredits: 100 }}  | ${{ isAllowed: false, creditsUsed: 0 }}
      ${'monthly commitment with monthly waiver and empty overage'} | ${true}          | ${true}           | ${false}                | ${{ creditsUsed: 10, totalCredits: 24 }} | ${{ creditsUsed: 50, totalCredits: 100 }}  | ${{ isAllowed: true, creditsUsed: 0 }}
      ${'monthly commitment with monthly waiver and overage'}       | ${true}          | ${false}          | ${true}                 | ${{ creditsUsed: 10, totalCredits: 24 }} | ${{ creditsUsed: 100, totalCredits: 100 }} | ${{ isAllowed: true, creditsUsed: 100 }}
      ${'monthly commitment with overage'}                          | ${true}          | ${false}          | ${true}                 | ${{ creditsUsed: 10, totalCredits: 24 }} | ${null}                                    | ${{ isAllowed: true, creditsUsed: 100 }}
      ${'no commitment no monthly waiver no overage'}               | ${false}         | ${false}          | ${false}                | ${null}                                  | ${null}                                    | ${{ isAllowed: false, creditsUsed: 0 }}
      ${'monthly waiver'}                                           | ${false}         | ${true}           | ${false}                | ${null}                                  | ${{ creditsUsed: 50, totalCredits: 100 }}  | ${{ isAllowed: false, creditsUsed: 0 }}
      ${'monthly waiver with empty overage'}                        | ${false}         | ${true}           | ${false}                | ${null}                                  | ${{ creditsUsed: 100, totalCredits: 100 }} | ${{ isAllowed: true, creditsUsed: 0 }}
      ${'monthly waiver with overage'}                              | ${false}         | ${false}          | ${true}                 | ${null}                                  | ${{ creditsUsed: 100, totalCredits: 100 }} | ${{ isAllowed: true, creditsUsed: 100 }}
      ${'overage'}                                                  | ${false}         | ${false}          | ${true}                 | ${null}                                  | ${null}                                    | ${{ isAllowed: true, creditsUsed: 100 }}
    `(
      'scenario: $scenario',
      ({
        monthlyCommitment,
        monthlyWaiver,
        overage,
        currentUsageCard,
        monthlyWaiverCard,
        currentOverageUsageCard,
      }) => {
        beforeEach(async () => {
          createComponent({
            mockQueryHandler: jest.fn().mockResolvedValue({
              data: {
                subscriptionUsage: {
                  ...usageDataNoCommitmentNoMonthlyWaiverNoOverage.data.subscriptionUsage,
                  monthlyCommitment,
                  monthlyWaiver,
                  overage,
                },
              },
            }),
          });
          await waitForPromises();
        });

        it(`will switch CurrentUsageCard visibility: ${currentUsageCard}`, () => {
          expect(wrapper.findComponent(CurrentUsageCard).exists()).toBe(currentUsageCard);
        });

        it(`will switch MonthlyWaiverCard visibility: ${monthlyWaiverCard}`, () => {
          expect(wrapper.findComponent(MonthlyWaiverCard).exists()).toBe(monthlyWaiverCard);
        });

        it(`will switch CurrentOverageUsageCard visibility: ${currentOverageUsageCard}`, () => {
          expect(wrapper.findComponent(CurrentOverageUsageCard).exists()).toBe(
            currentOverageUsageCard,
          );
        });
      },
    );
  });

  describe('monthly commitment', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders current-usage-card', () => {
      expect(wrapper.findComponent(CurrentUsageCard).props()).toMatchObject({
        poolCreditsUsed: 50,
        poolTotalCredits: 300,
        monthEndDate: '2025-10-31',
      });
    });

    it('does not render monthly-waiver-card', () => {
      expect(wrapper.findComponent(MonthlyWaiverCard).exists()).toBe(false);
    });
  });

  describe('monthly commitment with monthly waiver credits', () => {
    beforeEach(async () => {
      const mockQueryHandler = jest.fn().mockResolvedValue(usageDataCommitmentWithMonthlyWaiver);

      createComponent({ mockQueryHandler });
      await waitForPromises();
    });

    it('renders monthly-waiver-card', () => {
      expect(wrapper.findComponent(MonthlyWaiverCard).props()).toMatchObject({
        monthlyWaiverTotalCredits: 1000,
        monthlyWaiverCreditsUsed: 750,
      });
    });
  });

  describe('monthly commitment with monthly waiver with overage', () => {
    beforeEach(async () => {
      const mockQueryHandler = jest
        .fn()
        .mockResolvedValue(usageDataCommitmentWithMonthlyWaiverWithOverage);

      createComponent({ mockQueryHandler });
      await waitForPromises();
    });

    it('renders current-overage-usage-card', () => {
      expect(wrapper.findComponent(CurrentOverageUsageCard).exists()).toBe(true);
      expect(wrapper.findComponent(CurrentOverageUsageCard).props()).toMatchObject({
        overageCreditsUsed: 100,
        monthlyWaiverCreditsUsed: 1000,
      });
    });
  });

  describe('no monthly commitment with overage', () => {
    beforeEach(async () => {
      createComponent({
        mockQueryHandler: jest.fn().mockResolvedValue(usageDataNoCommitmentWithOverage),
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
        monthlyWaiverCreditsUsed: 0,
      });
    });

    it('will pass hasComitment to purchase-commitment-card', () => {
      const purchaseCommitmentCard = wrapper.findComponent(PurchaseCommitmentCard);

      expect(purchaseCommitmentCard.props('hasCommitment')).toBe(false);
    });
  });

  describe('no monthly commitment no monthly waiver no overage', () => {
    beforeEach(async () => {
      createComponent({
        mockQueryHandler: jest
          .fn()
          .mockResolvedValue(usageDataNoCommitmentNoMonthlyWaiverNoOverage),
      });
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
