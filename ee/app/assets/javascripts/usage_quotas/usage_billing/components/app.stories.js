// eslint-disable-next-line import/no-extraneous-dependencies
import MockAdapter from 'axios-mock-adapter';
import {
  mockUsageDataWithPool,
  mockUsageDataWithoutPool,
} from 'ee_jest/usage_quotas/usage_billing/mock_data';
import axios from '~/lib/utils/axios_utils';
import UsageBillingApp from './app.vue';

const meta = {
  title: 'ee/usage_quotas/usage_billing/app',
  component: UsageBillingApp,
};

export default meta;

/**
 *
 * @param {Object} config
 * @param {Object} [config.provide]
 * @param {Function} [config.mockHandler]
 * @returns
 */
const createTemplate = (config = {}) => {
  let { mockHandler } = config;
  let mockAdapter;

  return (args, { argTypes }) => ({
    components: {
      // NOTE: we have to make AdminUsageDashboardApp async,
      // to delay it's mounting, to have an opportunity to stub Axios
      UsageBillingApp: () => Promise.resolve(UsageBillingApp),
    },
    provide: {
      purchaseCommitmentUrl: '/url-to-purchase-monthly/commitment',
    },
    props: Object.keys(argTypes),
    template: `<usage-billing-app />`,
    mounted() {
      mockAdapter = new MockAdapter(axios);
      mockHandler ??= () => Promise.resolve([200, mockUsageDataWithPool]);
      mockAdapter.onGet('/admin/gitlab_duo/usage/data').replyOnce(mockHandler);
    },
    destroyed() {
      mockAdapter.restore();
    },
  });
};

export const Default = {
  render: createTemplate(),
};

export const NoCommitment = {
  render: (...args) => {
    const mockHandler = () => Promise.resolve([200, mockUsageDataWithoutPool]);

    return createTemplate({
      mockHandler,
    })(...args);
  },
};

export const LoadingState = {
  render: (...args) => {
    // Never resolved
    const mockHandler = () => new Promise(() => {});

    return createTemplate({
      mockHandler,
    })(...args);
  },
};

export const ErrorState = {
  render: (...args) => {
    const mockHandler = () => Promise.reject(new Error('Failed to fetch usage data'));

    return createTemplate({
      mockHandler,
    })(...args);
  },
};
