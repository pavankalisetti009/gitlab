import { GlBadge, GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import UltimatePlanBillingHeader from 'ee/groups/billing/components/ultimate_plan_billing_header.vue';
import { mockBillingPageAttributes } from '../../mock_data';

describe('UltimatePlanBillingHeader', () => {
  let wrapper;

  const ctaLabel = '__ctaLabel__';
  const findGlBadge = () => wrapper.findComponent(GlBadge);
  const findGlButton = () => wrapper.findComponent(GlButton);

  const createComponent = (props = {}) => {
    wrapper = shallowMount(UltimatePlanBillingHeader, {
      propsData: { ...mockBillingPageAttributes, ...props, ctaLabel },
    });
  };

  it('renders badge', () => {
    createComponent();

    const cta = findGlButton();

    expect(cta.props('href')).toBe(mockBillingPageAttributes.upgradeToUltimateUrl);
    expect(cta.text()).toBe(ctaLabel);
    expect(findGlBadge().exists()).toBe(false);
  });

  describe('when trial is active', () => {
    it('does not render badge', () => {
      createComponent({ trialActive: true });

      expect(findGlBadge().text()).toBe('Currently trialing');
    });
  });
});
