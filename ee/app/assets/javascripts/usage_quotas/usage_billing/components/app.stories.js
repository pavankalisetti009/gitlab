import VueApollo from 'vue-apollo';
import {
  mockUsersUsageDataWithPool,
  mockUsersUsageDataWithoutPool,
  mockUsersUsageDataWithOverage,
  usageDataWithPool,
  usageDataNoPoolNoOverage,
  usageDataNoPoolWithOverage,
  usageDataWithPoolWithOverage,
  usageDataWithOtcCredits,
} from 'ee_jest/usage_quotas/usage_billing/mock_data';
import { createMockClient } from 'helpers/mock_apollo_helper';
import getSubscriptionUsersUsageQuery from '../graphql/get_subscription_users_usage.query.graphql';
import getSubscriptionUsageQuery from '../graphql/get_subscription_usage.query.graphql';
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
 * @param {Function} [config.getSubscriptionUsersUsageQueryHandler]
 * @param {Function} [config.getSubscriptionUsageQueryHandler]
 * @returns
 */
const createTemplate = (config = {}) => {
  let { getSubscriptionUsersUsageQueryHandler, getSubscriptionUsageQueryHandler } = config;

  // NOTE: currently we mock both, REST and GraphQL APIs, as we transition towards GraphQL API
  // Apollo
  let defaultClient = config.apollo?.defaultClient;
  if (!defaultClient) {
    if (!getSubscriptionUsersUsageQueryHandler) {
      getSubscriptionUsersUsageQueryHandler = () => Promise.resolve(mockUsersUsageDataWithPool);
    }
    if (!getSubscriptionUsageQueryHandler) {
      getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataWithPool);
    }

    const requestHandlers = [
      [getSubscriptionUsersUsageQuery, getSubscriptionUsersUsageQueryHandler],
      [getSubscriptionUsageQuery, getSubscriptionUsageQueryHandler],
    ];
    defaultClient = createMockClient(requestHandlers);
  }

  const apolloProvider = new VueApollo({
    defaultClient,
  });

  return (args, { argTypes }) => ({
    apolloProvider,
    components: {
      // NOTE: we have to make AdminUsageDashboardApp async,
      // to delay it's mounting, to have an opportunity to stub Axios
      UsageBillingApp: () => Promise.resolve(UsageBillingApp),
    },
    provide: {
      userUsagePath: '/gitlab_duo/users/:id',
    },
    props: Object.keys(argTypes),
    template: `<usage-billing-app />`,
  });
};

export const Default = {
  render: createTemplate(),
};

export const PoolWithOverage = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.resolve(mockUsersUsageDataWithOverage);
    const getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataWithPoolWithOverage);

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const NoPoolWithOverage = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.resolve(mockUsersUsageDataWithoutPool);

    const getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataNoPoolWithOverage);

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const NoPoolNoOverage = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.resolve(mockUsersUsageDataWithoutPool);

    const getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataNoPoolNoOverage);

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const WithOtcCredits = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () => Promise.resolve(usageDataWithOtcCredits);

    const getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataWithOtcCredits);

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const LoadingState = {
  render: (...args) => {
    // Never resolved
    const getSubscriptionUsersUsageQueryHandler = () => new Promise(() => {});

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
    })(...args);
  },
};

export const LoadingUsersUsageState = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () => new Promise(() => {});

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
    })(...args);
  },
};

export const ErrorState = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.reject(new Error('Failed to fetch usage data'));

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
    })(...args);
  },
};

export const ErrorUsersUsageState = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.reject(new Error('Failed to fetch usage data'));

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
    })(...args);
  },
};
