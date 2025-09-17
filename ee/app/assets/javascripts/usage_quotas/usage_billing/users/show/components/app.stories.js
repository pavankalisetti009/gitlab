// eslint-disable-next-line import/no-extraneous-dependencies
import MockAdapter from 'axios-mock-adapter';
import { mockData, mockEmptyData } from 'ee_jest/usage_quotas/usage_billing/users/show/mock_data';
import axios from '~/lib/utils/axios_utils';
import UsageBillingUserDashboardApp from './app.vue';

const meta = {
  title: 'ee/usage_quotas/usage_billing/users/show/app',
  component: UsageBillingUserDashboardApp,
};

export default meta;

/**
 * @param {Object} config
 * @param {Object} [config.provide]
 * @param {Function} [config.mockHandler]
 */
const createTemplate = (config = {}) => {
  let { mockHandler } = config;
  let mockAdapter;

  return (args, { argTypes }) => ({
    components: {
      // NOTE: we have to make the component async,
      // to delay it's mounting, to have an opportunity to stub Axios
      UsageBillingUserDashboardApp: () => Promise.resolve(UsageBillingUserDashboardApp),
    },
    provide: {
      userId: '42',
    },
    props: Object.keys(argTypes),
    template: `<usage-billing-user-dashboard-app />`,
    mounted() {
      mockAdapter = new MockAdapter(axios);
      mockHandler ??= () => Promise.resolve([200, mockData]);
      mockAdapter.onGet('/admin/gitlab_duo/usage/users/42/data').replyOnce(mockHandler);
    },
    destroyed() {
      mockAdapter.restore();
    },
  });
};

export const Default = {
  render: createTemplate(),
};

export const EmptyState = {
  render: (...args) => {
    const mockHandler = () => Promise.resolve([200, mockEmptyData]);

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
