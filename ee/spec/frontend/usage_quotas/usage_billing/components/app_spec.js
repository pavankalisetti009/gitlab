import { GlAlert, GlTab } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import UsageBillingApp from 'ee/usage_quotas/usage_billing/components/app.vue';
import UsageByUserTab from 'ee/usage_quotas/usage_billing/components/usage_by_user_tab.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import PurchaseCommitmentCard from 'ee/usage_quotas/usage_billing/components/purchase_commitment_card.vue';
import UsageTrendsChart from 'ee/usage_quotas/usage_billing/components/usage_trends_chart.vue';
import CurrentUsageCard from 'ee/usage_quotas/usage_billing/components/current_usage_card.vue';
import { mockUsageDataWithPool } from '../mock_data';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

describe('UsageBillingApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  /** @type { MockAdapter} */
  let mockAxios;

  const API_ENDPOINT = '/admin/gitlab_duo/usage/data';

  const createComponent = () => {
    wrapper = shallowMountExtended(UsageBillingApp);
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
      createComponent();
    });

    it('shows only a loading icon when fetching data', () => {
      expect(findSkeletonLoaders().exists()).toBe(true);
      expect(findTabs().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('rendering elements', () => {
    beforeEach(async () => {
      mockAxios.onGet(API_ENDPOINT).reply(200, mockUsageDataWithPool);
      createComponent();
      await waitForPromises();
    });

    // NOTE: this is a temporary placeholder until we start using fetched data
    it('shows debug information', () => {
      const debugPre = wrapper.find('pre');
      expect(debugPre.text()).toContain(
        JSON.stringify(mockUsageDataWithPool.subscription, null, 2),
      );
    });

    it('renders purchase-commitment-card', () => {
      expect(wrapper.findComponent(PurchaseCommitmentCard).exists()).toBe(true);
    });

    it('renders current-usage-card', () => {
      expect(wrapper.findComponent(CurrentUsageCard).props()).toMatchObject({
        currentOverage: 0,
        totalUnits: 300,
        totalUnitsUsed: 50,
        monthStartDate: '2024-01-01',
        monthEndDate: '2024-01-31',
      });
    });

    it('renders the correct tabs', () => {
      const tabs = findTabs();

      expect(tabs.at(0).attributes('title')).toBe('Usage trends');
      expect(tabs.at(1).attributes('title')).toBe('Usage by user');
    });

    it('renders usage trends chart with correct props', () => {
      expect(wrapper.findComponent(UsageTrendsChart).props()).toMatchObject({
        monthStartDate: '2024-01-01',
        monthEndDate: '2024-01-31',
        trend: 0.12,
      });
      expect(wrapper.findComponent(UsageTrendsChart).props('usageData')).toHaveLength(30);
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

  describe('rendering usage by user tab', () => {
    beforeEach(async () => {
      mockAxios.onGet(API_ENDPOINT).reply(200, mockUsageDataWithPool);
      createComponent();
      await waitForPromises();
    });

    it('renders the tab with correct props', () => {
      expect(wrapper.findComponent(UsageByUserTab).exists()).toBe(true);
      expect(wrapper.findComponent(UsageByUserTab).props('usersData')).toMatchObject({
        totalUsers: 50,
        totalUsersUsingAllocation: 35,
        totalUsersUsingPool: 15,
        totalUsersBlocked: 10,

        // per-user details
        users: expect.any(Array),
      });
    });
  });
});
