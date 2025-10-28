import { GlDisclosureDropdownGroup, GlIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import UserMenuUpgradeSubscription from 'ee/super_sidebar/components/user_menu_upgrade_subscription.vue';

describe('UserMenuUpgradeSubscription component', () => {
  let wrapper;

  const createWrapper = (upgradeUrl = null) => {
    wrapper = mountExtended(UserMenuUpgradeSubscription, {
      propsData: {
        upgradeUrl,
      },
    });
  };

  const findUpgradeSubscriptionGroup = () => wrapper.findComponent(GlDisclosureDropdownGroup);
  const findUpgradeSubscriptionItem = () => wrapper.findByTestId('upgrade-subscription-item');

  describe('when upgrade subscription is available', () => {
    beforeEach(() => {
      createWrapper('/groups/test-group/-/billings');
    });

    it('renders the upgrade subscription group', () => {
      expect(findUpgradeSubscriptionGroup().exists()).toBe(true);
    });

    it('renders the upgrade subscription menu item', () => {
      expect(findUpgradeSubscriptionItem().exists()).toBe(true);
    });

    it('should render a link to upgrade subscription with correct URL', () => {
      expect(findUpgradeSubscriptionItem().text()).toBe('Upgrade subscription');
      expect(findUpgradeSubscriptionItem().find('a').attributes('href')).toBe(
        '/groups/test-group/-/billings',
      );
    });

    it('has Snowplow tracking attributes', () => {
      expect(findUpgradeSubscriptionItem().find('a').attributes()).toMatchObject({
        'data-track-property': 'nav_user_menu',
        'data-track-action': 'click_link',
        'data-track-label': 'upgrade_subscription',
      });
    });

    it('renders with license icon', () => {
      const icon = findUpgradeSubscriptionItem().findComponent(GlIcon);

      expect(icon.exists()).toBe(true);
      expect(icon.props('name')).toBe('license');
    });

    it('renders with hotspot styling', () => {
      const hotspotElement = findUpgradeSubscriptionItem().find('.hotspot-pulse');

      expect(hotspotElement.exists()).toBe(true);
    });
  });
});
