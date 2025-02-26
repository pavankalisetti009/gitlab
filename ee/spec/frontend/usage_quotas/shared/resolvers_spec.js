import { resolvers } from 'ee/usage_quotas/shared/resolvers';
import Api from 'ee/api';
import * as GroupsApi from 'ee/api/groups_api';
import { mockMemberDetails } from 'ee_jest/usage_quotas/seats/mock_data';

jest.mock('ee/api', () => {
  return {
    userSubscription: jest.fn(),
  };
});

jest.mock('ee/api/groups_api');

const subscriptionMockData = {
  billing: {
    subscription_end_date: '2024-12-31',
    subscription_start_date: '2024-01-01',
    trial_ends_on: null,
  },
  plan: {
    code: 'premium',
    name: 'Premium',
    trial: false,
    auto_renew: true,
    upgradable: true,
    exclude_guests: false,
  },
  usage: {
    seats_in_subscription: 10,
    seats_in_use: 8,
    max_seats_used: 9,
    seats_owed: 0,
  },
};

const subscriptionMockDataWithEmptyFields = {
  billing: {
    subscription_end_date: '2024-12-31',
    subscription_start_date: '2024-01-01',
  },
  plan: {
    code: 'premium',
    name: 'Premium',
  },
};

describe('resolvers', () => {
  describe('Query', () => {
    describe('subscription', () => {
      const namespaceId = 1;

      let subscriptionTestResult;

      beforeEach(async () => {
        jest.spyOn(Api, 'userSubscription').mockResolvedValue({ data: subscriptionMockData });
        subscriptionTestResult = await resolvers.Query.subscription(null, { namespaceId });
      });

      it('calls userSubscription API with correct namespace ID', () => {
        expect(Api.userSubscription).toHaveBeenCalledWith(namespaceId);
      });

      it('transforms API response into expected format', () => {
        expect(subscriptionTestResult).toEqual({
          id: namespaceId,
          endDate: '2024-12-31',
          startDate: '2024-01-01',
          plan: {
            code: 'premium',
            name: 'Premium',
            trial: false,
            auto_renew: true,
            upgradable: true,
            exclude_guests: false,
          },
          usage: {
            seats_in_subscription: 10,
            seats_in_use: 8,
            max_seats_used: 9,
            seats_owed: 0,
          },
          billing: {
            subscription_start_date: '2024-01-01',
            subscription_end_date: '2024-12-31',
          },
        });
      });

      describe('when response does not include all data', () => {
        beforeEach(async () => {
          jest
            .spyOn(Api, 'userSubscription')
            .mockResolvedValue({ data: subscriptionMockDataWithEmptyFields });
          subscriptionTestResult = await resolvers.Query.subscription(null, { namespaceId });
        });

        it('provides default values for undefined fields', () => {
          expect(subscriptionTestResult).toEqual({
            id: namespaceId,
            endDate: '2024-12-31',
            startDate: '2024-01-01',
            plan: {
              code: 'premium',
              name: 'Premium',
              trial: false,
              auto_renew: false,
              upgradable: false,
              exclude_guests: false,
            },
            usage: {
              seats_in_subscription: 0,
              seats_in_use: 0,
              max_seats_used: 0,
              seats_owed: 0,
            },
            billing: {
              subscription_start_date: '2024-01-01',
              subscription_end_date: '2024-12-31',
            },
          });
        });
      });
    });

    describe('billableMemberDetails', () => {
      let billableMemberDetailsResult;

      beforeEach(async () => {
        GroupsApi.fetchBillableGroupMemberMemberships.mockResolvedValueOnce({
          data: mockMemberDetails,
        });
        GroupsApi.fetchBillableGroupMemberIndirectMemberships.mockResolvedValueOnce({
          data: mockMemberDetails,
        });
        billableMemberDetailsResult = await resolvers.Query.billableMemberDetails(null, {
          namespaceId: 1,
          memberId: 2,
        });
      });

      it('calls fetchBillableGroupMemberMemberships and fetchBillableGroupMemberIndirectMemberships endpoints', () => {
        expect(GroupsApi.fetchBillableGroupMemberMemberships).toHaveBeenCalledWith(1, 2);
        expect(GroupsApi.fetchBillableGroupMemberIndirectMemberships).toHaveBeenCalledWith(1, 2);

        expect(billableMemberDetailsResult).toMatchObject({
          hasIndirectMembership: false,
          memberships: [
            {
              id: 173,
              source_id: 155,
              source_full_name: 'group_with_ultimate_plan / subgroup',
              created_at: '2021-02-25T08:21:32.257Z',
              expires_at: null,
              access_level: { string_value: 'Owner', integer_value: 50 },
            },
          ],
        });
      });
    });
  });
});
