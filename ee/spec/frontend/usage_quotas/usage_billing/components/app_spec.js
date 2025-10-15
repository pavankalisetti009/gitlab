import Vue from 'vue';
import { GlAlert, GlTab } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import MockAdapter from 'axios-mock-adapter';
import CurrentUsageCard from 'ee/usage_quotas/usage_billing/components/current_usage_card.vue';
import CurrentUsageNoPoolCard from 'ee/usage_quotas/usage_billing/components/current_usage_no_pool_card.vue';
import PurchaseCommitmentCard from 'ee/usage_quotas/usage_billing/components/purchase_commitment_card.vue';
import getSubscriptionUsageQuery from 'ee/usage_quotas/usage_billing/graphql/get_subscription_usage.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import UsageBillingApp from 'ee/usage_quotas/usage_billing/components/app.vue';
import UsageByUserTab from 'ee/usage_quotas/usage_billing/components/usage_by_user_tab.vue';
import UsageTrendsChart from 'ee/usage_quotas/usage_billing/components/usage_trends_chart.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import {
  mockUsageDataWithoutPool,
  mockUsageDataWithPool,
  usageDataNoPoolNoOverage,
  usageDataNoPoolWithOverage,
  usageDataWithPool,
} from '../mock_data';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('UsageBillingApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  /** @type { MockAdapter} */
  let mockAxios;

  const API_ENDPOINT = '/admin/gitlab_duo/usage/data';

  const createComponent = ({
    mockQueryHandler = jest.fn().mockResolvedValue(usageDataWithPool),
  } = {}) => {
    wrapper = shallowMountExtended(UsageBillingApp, {
      apolloProvider: createMockApollo([[getSubscriptionUsageQuery, mockQueryHandler]]),
      provide: {
        fetchUsageDataApiUrl: '/admin/gitlab_duo/usage/data',
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findSkeletonLoaders = () => wrapper.findByTestId('skeleton-loaders');
  const findTabs = () => wrapper.findAllComponents(GlTab);

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  describe('loading state', () => {
    beforeEach(() => {
      const loadingQueryHandler = jest.fn().mockImplementation(() => new Promise(() => {}));

      createComponent({ mockQueryHandler: loadingQueryHandler });
    });

    it('shows only a loading icon when fetching data', () => {
      expect(findSkeletonLoaders().exists()).toBe(true);
      expect(findTabs().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('rendering elements', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders current-usage-card', () => {
      expect(wrapper.findComponent(CurrentUsageCard).props()).toMatchObject({
        poolCreditsUsed: 50,
        poolTotalCredits: 300,
        overageCreditsUsed: 0,
        monthStartDate: '2024-01-01',
        monthEndDate: '2024-01-31',
      });
    });

    it('renders purchase-commitment-card', () => {
      const purchaseCommitmentCard = wrapper.findComponent(PurchaseCommitmentCard);

      expect(purchaseCommitmentCard.exists()).toBe(true);
      expect(purchaseCommitmentCard.props('hasCommitment')).toBe(true);
    });

    it('renders the correct tabs', () => {
      const tabs = findTabs();

      expect(tabs.at(0).attributes('title')).toBe('Usage trends');
      expect(tabs.at(1).attributes('title')).toBe('Usage by user');
    });

    it('renders usage trends chart with correct props', () => {
      const usageTrendsChart = wrapper.findComponent(UsageTrendsChart);

      expect(usageTrendsChart.props()).toMatchObject({
        monthStartDate: '2024-01-01',
        monthEndDate: '2024-01-31',
        trend: 0.12,
        threshold: 300,
      });
      expect(usageTrendsChart.props('usageData')).toHaveLength(30);
    });

    it('renders users table tab with correct props', () => {
      const usageByUserTab = wrapper.findComponent(UsageByUserTab);

      expect(usageByUserTab.exists()).toBe(true);
      expect(usageByUserTab.props()).toMatchObject({
        hasCommitment: true,
      });
    });
  });

  describe('no pool with overage state', () => {
    beforeEach(async () => {
      mockAxios.onGet(API_ENDPOINT).reply(200, mockUsageDataWithPool);
      createComponent({
        mockQueryHandler: jest.fn().mockResolvedValue(usageDataNoPoolWithOverage),
      });
      await waitForPromises();
    });

    it('will not render current-usage-card', () => {
      const currentUsageCard = wrapper.findComponent(CurrentUsageCard);

      expect(currentUsageCard.exists()).toBe(false);
    });

    it('will render current_usage_no_pool summary card', () => {
      const currentUsageNoPoolCard = wrapper.findComponent(CurrentUsageNoPoolCard);

      expect(currentUsageNoPoolCard.exists()).toBe(true);
      expect(currentUsageNoPoolCard.props()).toMatchObject({
        // NOTE: this is a temporary disabled while we're stubbing `overage` field.
        // This should be enabled again once the field is added in https://gitlab.com/gitlab-org/gitlab/-/issues/567987
        // overageCreditsUsed: 50,
        monthStartDate: '2024-01-01',
        monthEndDate: '2024-01-31',
      });
    });

    it('will pass hasComitment to purchase-commitment-card', () => {
      const purchaseCommitmentCard = wrapper.findComponent(PurchaseCommitmentCard);

      expect(purchaseCommitmentCard.props('hasCommitment')).toBe(false);
    });

    it('will pass hasComitment to usage-by-user-tab', () => {
      const usageByUserTab = wrapper.findComponent(UsageByUserTab);

      expect(usageByUserTab.props('hasCommitment')).toBe(false);
    });
  });

  describe('no pool no overage state', () => {
    beforeEach(async () => {
      mockAxios.onGet(API_ENDPOINT).reply(200, mockUsageDataWithoutPool);
      createComponent({ mockQueryHandler: jest.fn().mockResolvedValue(usageDataNoPoolNoOverage) });
      await waitForPromises();
    });

    it('will not render current-usage-card', () => {
      const currentUsageCard = wrapper.findComponent(CurrentUsageCard);

      expect(currentUsageCard.exists()).toBe(false);
    });

    // NOTE: this is a temporary disabled while we're stubbing `overage` field.
    // This should be enabled again once the field is added in https://gitlab.com/gitlab-org/gitlab/-/issues/567987
    // eslint-disable-next-line jest/no-disabled-tests
    it.skip('will not render current-usage-no-pool-card', () => {
      const currentUsageCard = wrapper.findComponent(CurrentUsageNoPoolCard);

      expect(currentUsageCard.exists()).toBe(false);
    });

    it('will pass hasComitment to purchase-commitment-card', () => {
      const purchaseCommitmentCard = wrapper.findComponent(PurchaseCommitmentCard);

      expect(purchaseCommitmentCard.props('hasCommitment')).toBe(false);
    });

    it('will pass hasComitment to usage-by-user-tab', () => {
      const usageByUserTab = wrapper.findComponent(UsageByUserTab);

      expect(usageByUserTab.props('hasCommitment')).toBe(false);
    });
  });

  describe('error state', () => {
    const errorMessage = 'Network Error';

    beforeEach(async () => {
      mockAxios.onGet(API_ENDPOINT).reply(500, { message: errorMessage });
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
