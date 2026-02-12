import Vue from 'vue';
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import CurrentUsageCard from 'ee/usage_quotas/usage_billing/components/current_usage_card.vue';
import CurrentOverageUsageCard from 'ee/usage_quotas/usage_billing/components/current_overage_usage_card.vue';
import MonthlyWaiverCard from 'ee/usage_quotas/usage_billing/components/monthly_waiver_card.vue';
import PurchaseCommitmentCard from 'ee/usage_quotas/usage_billing/components/purchase_commitment_card.vue';
import OverageOptInCard from 'ee/usage_quotas/usage_billing/components/overage_opt_in_card.vue';
import getSubscriptionUsageQuery from 'ee/usage_quotas/usage_billing/graphql/get_subscription_usage.query.graphql';
import PaidTierTrialPeriodView from 'ee/usage_quotas/usage_billing/components/paid_tier_trial_period_view.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import UsageBillingApp from 'ee/usage_quotas/usage_billing/components/app.vue';
import UsageByUserTab from 'ee/usage_quotas/usage_billing/components/usage_by_user_tab.vue';
import UsageTrendsChart from 'ee/usage_quotas/usage_billing/components/usage_trends_chart.vue';
import UsageOverviewChart from 'ee/usage_quotas/usage_billing/components/usage_overview_chart.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import {
  usageDataNoCommitmentWithOverage,
  usageDataWithCommitment,
  mockUsageDataBase,
  usageDataWithCommitmentWithMonthlyWaiver,
  usageDataCommitmentWithMonthlyWaiverWithOverage,
  usageDataWithOutdatedClient,
  usageDataWithoutPurchaseCreditsPath,
  usageDataWithDisabledState,
  usageDataOnPaidTierTrial,
} from '../mock_data';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('UsageBillingApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = ({
    mockQueryHandler = jest.fn().mockResolvedValue(usageDataWithCommitment),
    provide = {},
  } = {}) => {
    wrapper = shallowMountExtended(UsageBillingApp, {
      apolloProvider: createMockApollo([[getSubscriptionUsageQuery, mockQueryHandler]]),
      stubs: {
        GlSprintf,
      },
      provide: {
        customersUsageDashboardPath: 'https://gitlab.com/dummy-usage-dashboard-path',
        isFree: false,
        trialStartDate: undefined,
        trialEndDate: undefined,
        ...provide,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findSkeletonLoaders = () => wrapper.findByTestId('skeleton-loaders');
  const findUsageByUserTab = () => wrapper.findComponent(UsageByUserTab);
  const findUsageTrendsChart = () => wrapper.findComponent(UsageTrendsChart);
  const findUsageOverviewChart = () => wrapper.findComponent(UsageOverviewChart);
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findOutdatedClientAlert = () => wrapper.findByTestId('outdated-client-alert');
  const findDisabledStateAlert = () => wrapper.findByTestId('usage-billing-disabled-alert');
  const findUserDataDisabledAlert = () => wrapper.findByTestId('user-data-disabled-alert');
  const findCurrentUsageCard = () => wrapper.findComponent(CurrentUsageCard);
  const findCurrentOverageUsageCard = () => wrapper.findComponent(CurrentOverageUsageCard);
  const findMonthlyWaiverCard = () => wrapper.findComponent(MonthlyWaiverCard);
  const findPurchaseCommitmentCard = () => wrapper.findComponent(PurchaseCommitmentCard);
  const findOverageOptInCard = () => wrapper.findComponent(OverageOptInCard);
  const findUsageBillingCardsRow = () => wrapper.findByTestId('usage-billing-cards-row');

  beforeEach(() => {
    window.gon = {
      display_gitlab_credits_user_data: true,
      subscriptions_url: 'https://customers.gitlab.com/',
    };
  });

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
        expect(findPageHeading().text()).toContain('GitLab Credits');
      });

      it('renders the page month subtitle', () => {
        expect(findPageHeading().text()).toContain('Usage period:');
        expect(findPageHeading().findComponent(HumanTimeframe).exists()).toBe(true);
        expect(findPageHeading().findComponent(HumanTimeframe).props()).toEqual({
          from: '2025-10-01',
          till: '2025-10-31',
        });
      });

      it('renders last event transaction at', () => {
        expect(findPageHeading().text()).toContain('Last event transaction at:');
        expect(findPageHeading().findComponent(UserDate).exists()).toBe(true);
        expect(findPageHeading().findComponent(UserDate).props('date')).toBe(
          '2025-10-11T03:00:00Z',
        );
      });

      describe('outdated client alert', () => {
        it('does not render alert if isOutdatedClient is false', () => {
          expect(findOutdatedClientAlert().exists()).toBe(false);
        });

        it('renders outdated client with correct message when isOutdatedClient is true', async () => {
          createComponent({
            mockQueryHandler: jest.fn().mockResolvedValue(usageDataWithOutdatedClient),
          });

          await waitForPromises();

          expect(findOutdatedClientAlert().text()).toBe(
            'This dashboard may not display all current subscription data. For complete visibility, please upgrade to the latest version of GitLab or visit the Customer Portal.',
          );
        });
      });

      describe('disabled state alert', () => {
        describe('when Usage Billing is available', () => {
          it('does not render alert if enabled is true', () => {
            expect(findDisabledStateAlert().exists()).toBe(false);
          });

          it('displays all other elements', () => {
            expect(findUsageBillingCardsRow().exists()).toBe(true);
            expect(findUsageByUserTab().exists()).toBe(true);
          });
        });

        describe('when Usage Billing is disabled', () => {
          beforeEach(async () => {
            createComponent({
              mockQueryHandler: jest.fn().mockResolvedValue(usageDataWithDisabledState),
            });

            await waitForPromises();
          });

          it('renders disable state alert', () => {
            expect(findDisabledStateAlert().exists()).toBe(true);
          });

          it('hides all other components', () => {
            expect(findUsageBillingCardsRow().exists()).toBe(false);
            expect(findUsageByUserTab().exists()).toBe(false);
          });
        });
      });
    });

    it('renders purchase-commitment-card', () => {
      const purchaseCommitmentCard = wrapper.findComponent(PurchaseCommitmentCard);

      expect(purchaseCommitmentCard.exists()).toBe(true);
      expect(purchaseCommitmentCard.props('hasCommitment')).toBe(true);
      expect(purchaseCommitmentCard.props('purchaseCreditsUrl')).toBe(
        'https://customers.gitlab.com/purchase-credits-path',
      );
    });

    describe.each`
      scenario                                                                | canAcceptOverageTerms | cardVisible
      ${'renders overage opt-in card if canAcceptOverageTerms=true'}          | ${true}               | ${true}
      ${'does not render overage opt-in card if canAcceptOverageTerms=false'} | ${false}              | ${false}
    `('$scenario', ({ canAcceptOverageTerms, cardVisible }) => {
      beforeEach(async () => {
        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue({
            data: {
              subscriptionUsage: {
                ...mockUsageDataBase.data.subscriptionUsage,
                canAcceptOverageTerms,
              },
            },
          }),
        });
        await waitForPromises();
      });

      it(`will set overageOptInCard visibility to: ${cardVisible}`, () => {
        expect(findOverageOptInCard().exists()).toBe(cardVisible);
      });
    });

    it('renders usage by user tab', () => {
      expect(findUsageByUserTab().exists()).toBe(true);
    });

    describe('without lastEventTransactionAt', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue(mockUsageDataBase),
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
        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue(usageDataWithoutPurchaseCreditsPath),
        });
        await waitForPromises();
      });

      it('does not render purchase-commitment-card', () => {
        expect(findPurchaseCommitmentCard().exists()).toBe(false);
      });
    });
  });

  describe('summary cards visibility', () => {
    describe.each`
      scenario                                                      | currentUsageCard | monthlyWaiverCard | currentOverageUsageCard | usageTrendsChart | monthlyCommitment                                        | monthlyWaiver                                              | overage
      ${'monthly commitment'}                                       | ${true}          | ${false}          | ${false}                | ${true}          | ${{ creditsUsed: 10, totalCredits: 24, dailyUsage: [] }} | ${null}                                                    | ${{ isAllowed: false, creditsUsed: 0, dailyUsage: [] }}
      ${'monthly commitment with monthly waiver'}                   | ${true}          | ${true}           | ${false}                | ${true}          | ${{ creditsUsed: 10, totalCredits: 24, dailyUsage: [] }} | ${{ creditsUsed: 50, totalCredits: 100, dailyUsage: [] }}  | ${{ isAllowed: false, creditsUsed: 0, dailyUsage: [] }}
      ${'monthly commitment with monthly waiver and empty overage'} | ${true}          | ${true}           | ${false}                | ${true}          | ${{ creditsUsed: 10, totalCredits: 24, dailyUsage: [] }} | ${{ creditsUsed: 50, totalCredits: 100, dailyUsage: [] }}  | ${{ isAllowed: true, creditsUsed: 0, dailyUsage: [] }}
      ${'monthly commitment with monthly waiver and overage'}       | ${true}          | ${false}          | ${true}                 | ${true}          | ${{ creditsUsed: 10, totalCredits: 24, dailyUsage: [] }} | ${{ creditsUsed: 100, totalCredits: 100, dailyUsage: [] }} | ${{ isAllowed: true, creditsUsed: 100, dailyUsage: [] }}
      ${'monthly commitment with overage'}                          | ${true}          | ${false}          | ${true}                 | ${true}          | ${{ creditsUsed: 10, totalCredits: 24, dailyUsage: [] }} | ${null}                                                    | ${{ isAllowed: true, creditsUsed: 100, dailyUsage: [] }}
      ${'no commitment no monthly waiver no overage'}               | ${false}         | ${false}          | ${false}                | ${false}         | ${null}                                                  | ${null}                                                    | ${{ isAllowed: false, creditsUsed: 0, dailyUsage: [] }}
      ${'monthly waiver'}                                           | ${false}         | ${true}           | ${false}                | ${true}          | ${null}                                                  | ${{ creditsUsed: 50, totalCredits: 100, dailyUsage: [] }}  | ${{ isAllowed: false, creditsUsed: 0, dailyUsage: [] }}
      ${'monthly waiver with empty overage'}                        | ${false}         | ${true}           | ${false}                | ${true}          | ${null}                                                  | ${{ creditsUsed: 100, totalCredits: 100, dailyUsage: [] }} | ${{ isAllowed: true, creditsUsed: 0, dailyUsage: [] }}
      ${'monthly waiver with overage'}                              | ${false}         | ${false}          | ${true}                 | ${true}          | ${null}                                                  | ${{ creditsUsed: 100, totalCredits: 100, dailyUsage: [] }} | ${{ isAllowed: true, creditsUsed: 100, dailyUsage: [] }}
      ${'overage'}                                                  | ${false}         | ${false}          | ${true}                 | ${true}          | ${null}                                                  | ${null}                                                    | ${{ isAllowed: true, creditsUsed: 100, dailyUsage: [] }}
      ${'overage present, but not allowed'}                         | ${false}         | ${false}          | ${true}                 | ${false}         | ${null}                                                  | ${null}                                                    | ${{ isAllowed: false, creditsUsed: 100, dailyUsage: [] }}
    `(
      'scenario: $scenario',
      ({
        monthlyCommitment,
        monthlyWaiver,
        overage,
        currentUsageCard,
        monthlyWaiverCard,
        currentOverageUsageCard,
        usageTrendsChart,
      }) => {
        beforeEach(async () => {
          createComponent({
            mockQueryHandler: jest.fn().mockResolvedValue({
              data: {
                subscriptionUsage: {
                  ...mockUsageDataBase.data.subscriptionUsage,
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
          expect(findCurrentUsageCard().exists()).toBe(currentUsageCard);
        });

        it(`will switch MonthlyWaiverCard visibility: ${monthlyWaiverCard}`, () => {
          expect(findMonthlyWaiverCard().exists()).toBe(monthlyWaiverCard);
        });

        it(`will switch CurrentOverageUsageCard visibility: ${currentOverageUsageCard}`, () => {
          expect(findCurrentOverageUsageCard().exists()).toBe(currentOverageUsageCard);
        });

        it(`will switch UsageTrendsChart visibility: ${usageTrendsChart}`, () => {
          expect(findUsageTrendsChart().exists()).toBe(usageTrendsChart);
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
      expect(findCurrentUsageCard().props()).toMatchObject({
        poolCreditsUsed: 50.333,
        poolTotalCredits: 100,
        monthEndDate: '2025-10-31',
      });
    });

    it('does not render monthly-waiver-card', () => {
      expect(findMonthlyWaiverCard().exists()).toBe(false);
    });
  });

  describe('monthly commitment with monthly waiver credits', () => {
    beforeEach(async () => {
      const mockQueryHandler = jest
        .fn()
        .mockResolvedValue(usageDataWithCommitmentWithMonthlyWaiver);

      createComponent({ mockQueryHandler });
      await waitForPromises();
    });

    it('renders monthly-waiver-card', () => {
      expect(findMonthlyWaiverCard().props()).toMatchObject({
        monthlyWaiverTotalCredits: 100,
        monthlyWaiverCreditsUsed: 75,
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
      expect(findCurrentOverageUsageCard().exists()).toBe(true);
      expect(findCurrentOverageUsageCard().props()).toMatchObject({
        overageCreditsUsed: 24,
        monthlyWaiverCreditsUsed: 100,
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
      expect(findCurrentUsageCard().exists()).toBe(false);
    });

    it('will render current overage usage card', () => {
      expect(findCurrentOverageUsageCard().exists()).toBe(true);
      expect(findCurrentOverageUsageCard().props()).toMatchObject({
        overageCreditsUsed: 50,
        monthlyWaiverCreditsUsed: 0,
      });
    });

    it('will pass hasComitment to purchase-commitment-card', () => {
      expect(findPurchaseCommitmentCard().props('hasCommitment')).toBe(false);
    });
  });

  describe('no monthly commitment no monthly waiver no overage', () => {
    beforeEach(async () => {
      createComponent({
        mockQueryHandler: jest.fn().mockResolvedValue(mockUsageDataBase),
      });
      await waitForPromises();
    });

    it('will not render current-usage-card', () => {
      expect(findCurrentUsageCard().exists()).toBe(false);
    });

    it('will not render render current overage usage card', () => {
      expect(findCurrentOverageUsageCard().exists()).toBe(false);
    });

    it('will pass hasCommitment to purchase-commitment-card', () => {
      expect(findPurchaseCommitmentCard().props('hasCommitment')).toBe(false);
    });
  });

  describe('tabs', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    describe('UsageOverviewChart', () => {
      it('passes daily usage data to UsageOverviewChart', () => {
        expect(findUsageOverviewChart().exists()).toBe(true);
        expect(findUsageOverviewChart().props()).toMatchObject({
          monthStartDate: '2025-10-01',
          monthEndDate: '2025-10-31',
          commitmentDailyUsage: [
            { creditsUsed: 5, date: '2025-10-06' },
            { creditsUsed: 12, date: '2025-10-07' },
            { creditsUsed: 18, date: '2025-10-10' },
            { creditsUsed: 15.333, date: '2025-10-11' },
          ],
          waiverDailyUsage: [],
          overageDailyUsage: [],
          paidTierTrialDailyUsage: [],
          usersUsageDailyUsage: [
            { creditsUsed: 5, date: '2025-10-01' },
            { creditsUsed: 4, date: '2025-10-02' },
            { creditsUsed: 6, date: '2025-10-03' },
            { creditsUsed: 5.5, date: '2025-10-04' },
            { creditsUsed: 4.5, date: '2025-10-05' },
          ],
        });
      });
    });

    describe('UsageTrendsChart', () => {
      it('passes correct props to UsageTrendsChart', () => {
        expect(findUsageTrendsChart().exists()).toBe(true);
        expect(findUsageTrendsChart().props()).toMatchObject({
          monthStartDate: '2025-10-01',
          monthEndDate: '2025-10-31',
          monthlyCommitmentIsAvailable: true,
          monthlyCommitmentTotalCredits: 100,
          monthlyCommitmentDailyUsage: [
            { creditsUsed: 5, date: '2025-10-06' },
            { creditsUsed: 12, date: '2025-10-07' },
            { creditsUsed: 18, date: '2025-10-10' },
            { creditsUsed: 15.333, date: '2025-10-11' },
          ],
          monthlyWaiverIsAvailable: false,
          monthlyWaiverTotalCredits: 0,
          monthlyWaiverDailyUsage: [],
          overageIsAllowed: true,
          overageDailyUsage: [],
        });
      });
    });

    describe('UsageByUserTab', () => {
      it('renders UsageByUserTab component', () => {
        expect(findUsageByUserTab().exists()).toBe(true);
      });

      describe('when display_gitlab_credits_user_data feature flag is false', () => {
        beforeEach(() => {
          window.gon = { display_gitlab_credits_user_data: false };
          createComponent();
          return waitForPromises();
        });

        afterAll(() => {
          delete window.gon;
        });

        it('does not render UsageByUserTab component if display_gitlab_credits_user_data is false', () => {
          expect(findUsageByUserTab().exists()).toBe(false);
        });

        it('renders alert with help link', () => {
          expect(findUserDataDisabledAlert().text()).toBe(
            'Displaying user data is disabled. Learn how to enable it.',
          );

          expect(findUserDataDisabledAlert().findComponent(GlLink).attributes('href')).toBe(
            '/help/user/group/manage#display-gitlab-credits-user-data',
          );
        });
      });
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
      expect(findAlert().text()).toBe('An error occurred while fetching data');
    });

    it('logs the error to console and Sentry', () => {
      expect(logError).toHaveBeenCalledWith(expect.any(Error));
      expect(captureException).toHaveBeenCalledWith(expect.any(Error));
    });
  });

  describe('tracking', () => {
    useMockInternalEventsTracking();

    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('tracks pageview on component mount', () => {
      expect(wrapper.vm.$options.mixins).toContainEqual(
        expect.objectContaining({
          methods: expect.objectContaining({
            trackEvent: expect.any(Function),
          }),
        }),
      );
    });

    it('uses InternalEvents mixin for tracking', () => {
      expect(wrapper.vm.$options.mixins).toContainEqual(
        expect.objectContaining({
          methods: expect.objectContaining({
            trackEvent: expect.any(Function),
          }),
        }),
      );
    });
  });

  describe('paid tier trial', () => {
    describe('when on trial', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue(usageDataOnPaidTierTrial),
        });
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

      it('renders UsageOverviewChart within trial view slot', () => {
        expect(findUsageOverviewChart().exists()).toBe(true);
        expect(findUsageOverviewChart().props()).toMatchObject({
          monthStartDate: '2025-10-01',
          monthEndDate: '2025-10-31',
          paidTierTrialDailyUsage: [
            { creditsUsed: 15, date: '2025-10-05' },
            { creditsUsed: 18, date: '2025-10-06' },
            { creditsUsed: 20, date: '2025-10-07' },
            { creditsUsed: 17, date: '2025-10-08' },
          ],
          usersUsageDailyUsage: [
            { creditsUsed: 5, date: '2025-10-01' },
            { creditsUsed: 4, date: '2025-10-02' },
            { creditsUsed: 6, date: '2025-10-03' },
            { creditsUsed: 5.5, date: '2025-10-04' },
            { creditsUsed: 4.5, date: '2025-10-05' },
          ],
        });
      });

      it('wont render other cards', () => {
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

  describe('usage period dates', () => {
    describe('when trial dates are provided', () => {
      beforeEach(async () => {
        createComponent({
          provide: {
            trialStartDate: '2025-09-01',
            trialEndDate: '2025-09-30',
          },
        });
        await waitForPromises();
      });

      it('uses trial dates for the usage period', () => {
        expect(findPageHeading().findComponent(HumanTimeframe).props()).toEqual({
          from: '2025-09-01',
          till: '2025-09-30',
        });
      });
    });

    describe('when trial dates are not provided', () => {
      beforeEach(async () => {
        createComponent({
          provide: {
            trialStartDate: '',
            trialEndDate: '',
          },
        });
        await waitForPromises();
      });

      it('uses subscription dates for the usage period', () => {
        expect(findPageHeading().findComponent(HumanTimeframe).props()).toEqual({
          from: '2025-10-01',
          till: '2025-10-31',
        });
      });
    });
  });

  describe('inTrial computed property', () => {
    it('returns true when trialStartDate is provided', async () => {
      createComponent({
        provide: {
          trialStartDate: '2025-09-01',
          trialEndDate: '2025-09-30',
        },
      });
      await waitForPromises();

      expect(wrapper.vm.inTrial).toBe(true);
    });

    it('returns false when trialStartDate is empty', async () => {
      createComponent({
        provide: {
          trialStartDate: '',
          trialEndDate: '',
        },
      });
      await waitForPromises();

      expect(wrapper.vm.inTrial).toBe(false);
    });
  });

  describe('isUsageBillingDisabled computed property', () => {
    it('returns false when inTrial is true', async () => {
      createComponent({
        provide: {
          trialStartDate: '2025-09-01',
          trialEndDate: '2025-09-30',
        },
      });
      await waitForPromises();

      expect(wrapper.vm.isUsageBillingDisabled).toBe(false);
    });

    it('returns false when subscriptionUsage.enabled is true', async () => {
      createComponent({
        mockQueryHandler: jest.fn().mockResolvedValue(usageDataWithCommitment),
        provide: {
          trialStartDate: '',
        },
      });
      await waitForPromises();

      expect(wrapper.vm.isUsageBillingDisabled).toBe(false);
    });

    it('returns true when subscriptionUsage.enabled is false and not in trial', async () => {
      createComponent({
        mockQueryHandler: jest.fn().mockResolvedValue(usageDataWithDisabledState),
        provide: {
          trialStartDate: '',
        },
      });
      await waitForPromises();

      expect(wrapper.vm.isUsageBillingDisabled).toBe(true);
    });
  });
});
