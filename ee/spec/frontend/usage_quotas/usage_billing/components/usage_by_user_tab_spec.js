import { GlTable, GlCard } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UsageByUserTab from 'ee/usage_quotas/usage_billing/components/usage_by_user_tab.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { mockUsageDataWithPool } from '../mock_data';

describe('UsageByUserTab', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  const usersData = mockUsageDataWithPool.subscription.gitlabUnitsUsage.usersUsage;

  const createComponent = (mountFn = shallowMountExtended) => {
    wrapper = mountFn(UsageByUserTab, {
      propsData: { usersData },
      provide: {
        userUsagePath: '/path/to/user/:id',
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findCards = () => wrapper.findAllComponents(GlCard);

  describe('rendering cards', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders total users card', () => {
      const cards = findCards();

      expect(cards.at(0).text()).toMatchInterpolatedText('50 Total users (active users)');
      expect(cards.at(1).text()).toMatchInterpolatedText('35 Users using allocation');
      expect(cards.at(2).text()).toMatchInterpolatedText('10 Users blocked');
    });
  });

  describe('rendering table', () => {
    beforeEach(() => {
      createComponent(mountExtended);
    });

    it('renders the table with correct props', () => {
      expect(findTable().props('fields')).toEqual([
        {
          key: 'user',
          label: 'User',
          sortable: true,
        },
        {
          key: 'allocationUsed',
          label: 'Allocation used',
          sortable: true,
        },
        {
          key: 'poolUsed',
          label: 'Pool used',
          sortable: true,
        },
        {
          key: 'totalUnitsUsed',
          label: 'Total units used',
          sortable: true,
        },
        {
          key: 'status',
          label: 'Status',
          sortable: true,
        },
      ]);
    });

    it('renders the table with user avatar pointing to the correct path', () => {
      const userAvatars = findTable().findAllComponents(UserAvatarLink);

      expect(userAvatars).toHaveLength(8);

      // testing the first two instances
      expect(userAvatars.at(0).props('linkHref')).toBe('/path/to/user/1');
      expect(userAvatars.at(1).props('linkHref')).toBe('/path/to/user/2');
    });
  });
});
