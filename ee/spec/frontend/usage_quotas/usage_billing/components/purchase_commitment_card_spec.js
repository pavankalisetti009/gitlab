import { GlButton } from '@gitlab/ui';
import PurchaseCommitmentCard from 'ee/usage_quotas/usage_billing/components/purchase_commitment_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('PurchaseCommitmentCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(PurchaseCommitmentCard, {
      propsData: {
        purchaseCreditsPath: 'url-to-purchase-monthly-commitment',
        ...propsData,
      },
    });
  };

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent({ hasCommitment: true });
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('Purchase a monthly commitment');
    });

    it('renders card body', () => {
      expect(wrapper.find('p').text()).toBe(
        'You can increase your commitment amount to extend your monthly allocation of credits.',
      );
    });

    it('renders call to action button', () => {
      const button = wrapper.findComponent(GlButton);

      expect(button.props('href')).toBe('url-to-purchase-monthly-commitment');
      expect(button.text()).toBe('Increase monthly commitment');
    });
  });

  describe('no commitment state', () => {
    beforeEach(() => {
      createComponent({ hasCommitment: false });
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('Purchase a monthly commitment');
    });

    it('renders card body', () => {
      expect(wrapper.find('p').text()).toBe(
        'You can purchase a monthly allocation of GitLab Credits to be shared across users.',
      );
    });

    it('renders call to action button', () => {
      const button = wrapper.findComponent(GlButton);

      expect(button.props('href')).toBe('url-to-purchase-monthly-commitment');
      expect(button.text()).toBe('Purchase monthly commitment');
    });
  });
});
