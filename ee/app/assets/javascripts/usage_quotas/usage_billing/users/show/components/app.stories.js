import VueApollo from 'vue-apollo';
import { createMockClient } from 'helpers/mock_apollo_helper';
import {
  mockDataWithPool,
  mockDataWithoutPool,
  mockEmptyData,
} from 'ee_jest/usage_quotas/usage_billing/users/show/mock_data';
import getUserSubscriptionUsageQuery from '../graphql/get_user_subscription_usage.query.graphql';
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
  let { getUserSubscriptionUsageQueryHandler } = config;

  // Apollo
  let defaultClient = config.apollo?.defaultClient;
  if (!defaultClient) {
    if (!getUserSubscriptionUsageQueryHandler) {
      getUserSubscriptionUsageQueryHandler = () => Promise.resolve(mockDataWithPool);
    }

    const requestHandlers = [[getUserSubscriptionUsageQuery, getUserSubscriptionUsageQueryHandler]];
    defaultClient = createMockClient(requestHandlers);
  }

  const apolloProvider = new VueApollo({
    defaultClient,
  });

  return (args, { argTypes }) => ({
    components: {
      UsageBillingUserDashboardApp,
    },
    apolloProvider,
    provide: {
      username: 'john_doe',
      namespacePath: 'gitlab',
    },
    props: Object.keys(argTypes),
    template: `<usage-billing-user-dashboard-app />`,
  });
};

export const Default = {
  render: createTemplate(),
};

export const NoCommitment = {
  render: (...args) => {
    const getUserSubscriptionUsageQueryHandler = () => Promise.resolve(mockDataWithoutPool);

    return createTemplate({
      getUserSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const EmptyState = {
  render: (...args) => {
    const getUserSubscriptionUsageQueryHandler = () => Promise.resolve(mockEmptyData);

    return createTemplate({
      getUserSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const LoadingState = {
  render: (...args) => {
    // Never resolved
    const getUserSubscriptionUsageQueryHandler = () => new Promise(() => {});

    return createTemplate({
      getUserSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const ErrorState = {
  render: (...args) => {
    const getUserSubscriptionUsageQueryHandler = () =>
      Promise.reject(new Error('Failed to fetch usage data'));

    return createTemplate({
      getUserSubscriptionUsageQueryHandler,
    })(...args);
  },
};
