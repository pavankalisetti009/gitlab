import { GlAlert, GlAvatar, GlLoadingIcon } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import UsageBillingUserDashboardApp from 'ee/usage_quotas/usage_billing/users/show/components/app.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { mockDataWithPool, mockDataWithoutPool } from '../mock_data';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

describe('UsageBillingUserDashboardApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  /** @type { MockAdapter } */
  let mockAxios;

  const MOCK_USAGE = mockDataWithPool.subscription.gitlabCreditsUsage.userUsage;
  const MOCK_USER = MOCK_USAGE.user;
  const USER_ID = MOCK_USER.id;
  const API_ENDPOINT = `/admin/gitlab_duo/usage/users/${USER_ID}/data`;

  const createComponent = () => {
    wrapper = shallowMountExtended(UsageBillingUserDashboardApp, {
      provide: {
        userId: USER_ID,
        fetchUserUsageDataApiUrl: API_ENDPOINT,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findUserAvatar = () => wrapper.findComponent(GlAvatar);
  const findMonthSummaryCard = () => wrapper.findByTestId('month-summary-card');
  const findMonthPoolCard = () => wrapper.findByTestId('month-pool-card');
  const findTotalUsageCard = () => wrapper.findByTestId('total-usage-card');

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
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('loaded state', () => {
    beforeEach(async () => {
      mockAxios.onGet(API_ENDPOINT).reply(200, mockDataWithPool);
      createComponent();
      await waitForPromises();
    });

    describe('header', () => {
      it('renders user avatar', () => {
        expect(findUserAvatar().exists()).toBe(true);
        expect(findUserAvatar().props('src')).toBe(MOCK_USER.avatar_url);
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
        expect(card.text()).toContain(
          `${MOCK_USAGE.allocationUsed} / ${MOCK_USAGE.allocationTotal}`,
        );
      });

      it('renders month pool card with correct values', () => {
        const card = findMonthPoolCard();
        expect(card.exists()).toBe(true);
        expect(card.text()).toContain(`${MOCK_USAGE.poolUsed}`);
      });

      it('renders total usage card with correct values', () => {
        const card = findTotalUsageCard();
        expect(card.exists()).toBe(true);
        expect(card.text()).toContain(`${MOCK_USAGE.totalCreditsUsed}`);
      });
    });
  });

  describe('no commitment state', () => {
    beforeEach(async () => {
      mockAxios.onGet(API_ENDPOINT).reply(200, mockDataWithoutPool);
      createComponent();
      await waitForPromises();
    });

    it('will not render the pool usage card', () => {
      const card = findMonthPoolCard();
      expect(card.exists()).toBe(false);
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
