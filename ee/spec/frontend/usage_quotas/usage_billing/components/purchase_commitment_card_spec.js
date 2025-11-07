import { GlButton, GlSprintf } from '@gitlab/ui';
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
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent({ hasCommitment: true });
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('Increase monthly credit commitment');
    });

    it('renders card body', () => {
      expect(wrapper.find('p').text()).toMatchInterpolatedText(
        'Unlock more discounts for your GitLab usage. Pool GitLab Credits across your namespace for flexibility and predictable monthly costs. GitLab Credit pricing.',
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
      expect(wrapper.find('h2').text()).toBe('Save on GitLab Credits with monthly commitment');
    });

    it('renders card body', () => {
      expect(wrapper.find('p').text()).toMatchInterpolatedText(
        'Monthly commitments offer significant discounts off list price. Share GitLab Credits across your namespace for flexibility and predictable monthly costs. Learn more about GitLab Credit pricing.',
      );
    });

    it('renders call to action button', () => {
      const button = wrapper.findComponent(GlButton);

      expect(button.props('href')).toBe('url-to-purchase-monthly-commitment');
      expect(button.text()).toBe('Purchase monthly commitment');
    });
  });
});
