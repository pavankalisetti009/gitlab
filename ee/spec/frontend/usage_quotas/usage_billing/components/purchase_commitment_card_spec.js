import { GlButton } from '@gitlab/ui';
import PurchaseCommitmentCard from 'ee/usage_quotas/usage_billing/components/purchase_commitment_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('PurchaseCommitmentCard', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(PurchaseCommitmentCard, {
      provide: {
        purchaseCommitmentUrl: 'url-to-purchase-monthly-commitment',
      },
    });
  };

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('Purchase a monthly commitment');
    });

    it('renders card body', () => {
      expect(wrapper.find('p').text()).toBe(
        'You can increase your commitment amount to extend your monthly allocation of tokens.',
      );
    });

    it('renders call to action button', () => {
      const button = wrapper.findComponent(GlButton);

      expect(button.props('href')).toBe('url-to-purchase-monthly-commitment');
      expect(button.text()).toBe('Increase monthly commitment');
    });
  });
});
