import VueApollo from 'vue-apollo';
import {
  mockUsersUsageDataWithPool,
  mockUsersUsageDataWithoutPool,
  usageDataCommitmentWithOtcWithOverage,
  usageDataWithCommitment,
  usageDataNoCommitmentNoOtcNoOverage,
  usageDataNoCommitmentWithOverage,
  usageDataWithCommitmentWithOverage,
  usageDataCommitmentWithOtc,
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

  let defaultClient = config.apollo?.defaultClient;
  if (!defaultClient) {
    if (!getSubscriptionUsersUsageQueryHandler) {
      getSubscriptionUsersUsageQueryHandler = () => Promise.resolve(mockUsersUsageDataWithPool);
    }
    if (!getSubscriptionUsageQueryHandler) {
      getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataWithCommitment);
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
      UsageBillingApp,
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

export const CommitmentWithOtcCredits = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataCommitmentWithOtc);

    return createTemplate({
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const CommitmentWithOtcWithOverage = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () =>
      Promise.resolve(usageDataCommitmentWithOtcWithOverage);

    return createTemplate({
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const CommitmentWithOverage = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () =>
      Promise.resolve(usageDataWithCommitmentWithOverage);

    return createTemplate({
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const NoCommitmentWithOverage = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.resolve(mockUsersUsageDataWithoutPool);

    const getSubscriptionUsageQueryHandler = () =>
      Promise.resolve(usageDataNoCommitmentWithOverage);

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const NoCommitmentNoOtcNoOverage = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.resolve(mockUsersUsageDataWithoutPool);

    const getSubscriptionUsageQueryHandler = () =>
      Promise.resolve(usageDataNoCommitmentNoOtcNoOverage);

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const LoadingState = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () => new Promise(() => {});
    const getSubscriptionUsersUsageQueryHandler = () => new Promise(() => {});

    return createTemplate({
      getSubscriptionUsageQueryHandler,
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
    const getSubscriptionUsageQueryHandler = () =>
      Promise.reject(new Error('Failed to fetch usage data'));

    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.reject(new Error('Failed to fetch usage data'));

    return createTemplate({
      getSubscriptionUsageQueryHandler,
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
