import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import getBillableMembersCountQuery from 'ee/subscriptions/graphql/queries/billable_members_count.query.graphql';
import SubscriptionSeatsStatisticsCard from 'ee/usage_quotas/seats/components/subscription_seats_statistics_card.vue';
import PublicNamespacePlanInfoCard from 'ee/usage_quotas/seats/components/public_namespace_plan_info_card.vue';
import StatisticsSeatsCard from 'ee/usage_quotas/seats/components/statistics_seats_card.vue';
import SubscriptionUpgradeInfoCard from 'ee/usage_quotas/seats/components/subscription_upgrade_info_card.vue';
import SubscriptionSeats from 'ee/usage_quotas/seats/components/subscription_seats.vue';
import SubscriptionUserList from 'ee/usage_quotas/seats/components/subscription_user_list.vue';
import { getMockSubscriptionData } from 'ee_jest/usage_quotas/seats/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

jest.mock('~/alert');

const providedFields = {
  explorePlansPath: '/groups/test_group/-/billings',
  hasNoSubscription: false,
  activeTrial: false,
  addSeatsHref: '/groups/test_group/-/seat_usage.csv',
};

Vue.use(VueApollo);

describe('Subscription Seats', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const fullPath = 'group-path';
  const { explorePlansPath, addSeatsHref } = providedFields;

  const defaultBillableMembersCountMockHandler = jest.fn().mockResolvedValue({
    data: {
      group: {
        id: 'gid://gitlab/Group/13',
        billableMembersCount: 2,
        enforceFreeUserCap: false,
      },
    },
  });

  const defaultSubscriptionPlanData = getMockSubscriptionData({
    code: 'ultimate',
    name: 'Ultimate',
    maxSeatsUsed: 3,
    seatsOwed: 1,
  }).subscription;

  const freeSubscriptionPlanData = getMockSubscriptionData({
    id: 2,
    code: 'free',
    name: 'Free',
  }).subscription;

  const createComponent = ({
    provide = {},
    subscriptionData = () => defaultSubscriptionPlanData,
  } = {}) => {
    const resolvers = {
      Query: {
        subscription: subscriptionData,
      },
    };

    const apolloProvider = createMockApollo(
      [[getBillableMembersCountQuery, defaultBillableMembersCountMockHandler]],
      resolvers,
    );

    wrapper = extendedWrapper(
      shallowMount(SubscriptionSeats, {
        apolloProvider,
        provide: {
          fullPath,
          isPublicNamespace: false,
          explorePlansPath,
          addSeatsHref,
          namespaceId: 1,
          hasNoSubscription: null,
          hasLimitedFreePlan: false,
          ...provide,
        },
      }),
    );

    return waitForPromises();
  };

  const findPublicNamespacePlanInfoCard = () => wrapper.findComponent(PublicNamespacePlanInfoCard);
  const findSubscriptionSeatsStatisticsCard = () =>
    wrapper.findComponent(SubscriptionSeatsStatisticsCard);
  const findStatisticsSeatsCard = () => wrapper.findComponent(StatisticsSeatsCard);
  const findSubscriptionUpgradeCard = () => wrapper.findComponent(SubscriptionUpgradeInfoCard);
  const findSubscriptionUserList = () => wrapper.findComponent(SubscriptionUserList);

  describe('actions', () => {
    it('calls createAlert when gitlab subscription query fails', async () => {
      createComponent({
        subscriptionData: () => new Error('Failed'),
      });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalled();
    });
  });

  describe('when is a public namespace', () => {
    beforeEach(() => {
      return createComponent({
        subscriptionData: () => freeSubscriptionPlanData,
        provide: {
          hasNoSubscription: true,
          isPublicNamespace: true,
        },
      });
    });

    it('renders <public-namespace-plan-info-card>', () => {
      expect(findPublicNamespacePlanInfoCard().exists()).toBe(true);
    });
  });

  describe('statistics', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('renders <subscription-seats-statistics-card> with the necessary props', () => {
      expect(findSubscriptionSeatsStatisticsCard().props()).toMatchObject({
        billableMembersCount: 2,
        seatsInSubscription: 0,
      });
    });

    it('renders <statistics-seats-card> with the necessary props', () => {
      const statisticsSeatsCard = findStatisticsSeatsCard();

      expect(findSubscriptionUpgradeCard().exists()).toBe(false);
      expect(statisticsSeatsCard.exists()).toBe(true);
      expect(statisticsSeatsCard.props()).toMatchObject({
        hasFreePlan: false,
        seatsOwed: 1,
        seatsUsed: 3,
      });
    });

    describe('when on free namespace', () => {
      beforeEach(() => {
        return createComponent({
          subscriptionData: () => freeSubscriptionPlanData,
        });
      });

      it('renders <statistics-seats-card> with hasFreePlan as true', () => {
        expect(findStatisticsSeatsCard().props('hasFreePlan')).toBe(true);
      });
    });

    describe('for free namespace with limit', () => {
      beforeEach(() => {
        return createComponent({
          provide: {
            hasNoSubscription: true,
            hasLimitedFreePlan: true,
          },
        });
      });

      it('renders <subscription-upgrade-info-card> with the necessary props', () => {
        const upgradeInfoCard = findSubscriptionUpgradeCard();

        expect(findStatisticsSeatsCard().exists()).toBe(false);
        expect(upgradeInfoCard.exists()).toBe(true);
        expect(upgradeInfoCard.props()).toMatchObject({
          explorePlansPath: providedFields.explorePlansPath,
          activeTrial: false,
        });
      });
    });
  });

  describe('subscription user list', () => {
    it('renders subscription users', async () => {
      await createComponent();

      expect(findSubscriptionUserList().exists()).toBe(true);
    });

    it('refetches data when findSubscriptionUserList emits refetchData', async () => {
      const subscriptionQueryHandler = jest.fn().mockResolvedValue(defaultSubscriptionPlanData);

      createComponent({ subscriptionData: subscriptionQueryHandler });

      await waitForPromises();

      // Initial queries should have been called once
      expect(subscriptionQueryHandler).toHaveBeenCalledTimes(1);
      expect(defaultBillableMembersCountMockHandler).toHaveBeenCalledTimes(1);

      await findSubscriptionUserList().vm.$emit('refetchData');

      // After refetch, queries should have been called twice more
      expect(subscriptionQueryHandler).toHaveBeenCalledTimes(2);
      expect(defaultBillableMembersCountMockHandler).toHaveBeenCalledTimes(2);
    });
  });
});
