import VueApollo from 'vue-apollo';
import SubscriptionSeatsApp from 'ee/usage_quotas/seats/components/subscription_seats.vue';
import { createMockClient } from 'helpers/mock_apollo_helper';
import getBillableMembersCountQuery from 'ee/subscriptions/graphql/queries/billable_members_count.query.graphql';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { getMockSubscriptionData, mockTableItems } from 'ee_jest/usage_quotas/seats/mock_data';

export default {
  component: SubscriptionSeatsApp,
  title: 'ee/usage_quotas/seats/subscription_seats',
};

const defaultProvide = {
  fullPath: 'group-path',
  isPublicNamespace: false,
  namespaceId: 1,
  namespaceName: 'Group Name',
  maxFreeNamespaceSeats: 5,
  hasLimitedFreePlan: false,
  explorePlansPath: '/groups/test_group/-/billings',
  addSeatsHref: '/groups/test_group/-/seat_usage.csv',
  subscriptionHistoryHref: '/groups/my-group/-/usage_quotas/subscription_history.csv',
  seatUsageExportPath: '/groups/test_group/-/seat_usage.csv',
};
const defaultMockSubscriptionResponse = Promise.resolve(
  getMockSubscriptionData({
    code: 'ultimate',
    name: 'Ultimate',
    maxSeatsUsed: 3,
    seatsInSubscription: 2,
    seatsOwed: 1,
  }).subscription,
);
const defaultMockBillableMembersResponse = Promise.resolve({
  total: mockTableItems.length,
  page: 1,
  perPage: 5,
  members: mockTableItems.map((member) => ({
    ...member,
    avatar_url: '/assets/images/logo.svg',
  })),
});
const defaultMockSubscriptionPermissionResponse = Promise.resolve({
  data: {
    subscription: {
      canAddSeats: true,
      canRenew: true,
      communityPlan: false,
      canAddDuoProSeats: true,
    },
    userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
  },
});
const defaultMockBillableMembersCountResponse = Promise.resolve({
  data: {
    group: {
      id: 'gid://gitlab/Group/13',
      billableMembersCount: 2,
      enforceFreeUserCap: false,
    },
  },
});

const createTemplate = ({
  provide = {},
  mockSubscriptionResponse = defaultMockSubscriptionResponse,
  mockBillableMembersResponse = defaultMockBillableMembersResponse,
  mockSubscriptionPermissionResponse = defaultMockSubscriptionPermissionResponse,
  mockBillableMembersCountResponse = defaultMockBillableMembersCountResponse,
} = {}) => {
  const resolvers = {
    Query: {
      subscription: () => mockSubscriptionResponse,
      billableMembers: () => mockBillableMembersResponse,
    },
  };
  const mockCustomersDotClient = createMockClient([
    [getSubscriptionPermissionsData, () => mockSubscriptionPermissionResponse],
  ]);
  const mockGitlabClient = createMockClient(
    [[getBillableMembersCountQuery, () => mockBillableMembersCountResponse]],
    resolvers,
  );
  const apolloProvider = new VueApollo({
    defaultClient: mockGitlabClient,
    clients: { customersDotClient: mockCustomersDotClient, gitlabClient: mockGitlabClient },
  });

  return () => ({
    components: { SubscriptionSeatsApp },
    apolloProvider,
    provide: {
      ...defaultProvide,
      ...provide,
    },
    template: '<subscription-seats-app />',
  });
};

export const SaasWithPaidPlan = createTemplate();

export const SaasWithFreeUnlimited = createTemplate({
  mockSubscriptionResponse: Promise.resolve(
    getMockSubscriptionData({
      code: 'free',
      name: 'Free',
    }).subscription,
  ),
});

export const SaasWithFreeUserCapEnabled = createTemplate({
  provide: {
    hasLimitedFreePlan: true,
  },
});

export const SaasWithFreePublicNamespace = createTemplate({
  provide: {
    isPublicNamespace: true,
  },
  mockSubscriptionResponse: Promise.resolve(
    getMockSubscriptionData({
      code: 'free',
      name: 'Free',
    }).subscription,
  ),
});

export const SaasWithTrialPlan = createTemplate({
  mockSubscriptionResponse: Promise.resolve(
    getMockSubscriptionData({
      code: 'ultimate',
      name: 'Ultimate',
      trial: true,
      trialEndsOn: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(), // 30 days from now
    }).subscription,
  ),
});

export const SaasWithCommunityPlan = createTemplate({
  mockSubscriptionPermissionResponse: Promise.resolve({
    data: {
      subscription: {
        canAddSeats: true,
        canRenew: true,
        communityPlan: true,
        canAddDuoProSeats: true,
      },
      userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
    },
  }),
});

export const Loading = createTemplate({
  mockSubscriptionPermissionResponse: new Promise(() => {}),
  mockBillableMembersCountResponse: new Promise(() => {}),
  mockBillableMembersResponse: new Promise(() => {}),
});
