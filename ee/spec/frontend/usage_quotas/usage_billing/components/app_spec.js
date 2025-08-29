import { GlTab } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UsageBillingApp from 'ee/usage_quotas/usage_billing/components/app.vue';
import PurchaseCommitmentCard from 'ee/usage_quotas/usage_billing/components/purchase_commitment_card.vue';

describe('UsageBillingApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(UsageBillingApp);
  };

  const findTabs = () => wrapper.findAllComponents(GlTab);

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders purchase-commitment-card', () => {
      expect(wrapper.findComponent(PurchaseCommitmentCard).exists()).toBe(true);
    });

    it('renders the correct tabs', () => {
      const tabs = findTabs();

      expect(tabs.at(0).attributes('title')).toBe('Usage trends');
      expect(tabs.at(1).attributes('title')).toBe('Usage by user');
    });
  });
});
