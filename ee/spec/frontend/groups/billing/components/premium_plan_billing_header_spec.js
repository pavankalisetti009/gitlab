import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import PremiumPlanBillingHeader from 'ee/groups/billing/components/premium_plan_billing_header.vue';
import { mockBillingPageAttributes } from '../../mock_data';

describe('PremiumPlanBillingHeader', () => {
  let wrapper;

  const ctaLabel = '__ctaLabel__';
  const findGlButton = () => wrapper.findComponent(GlButton);

  const createComponent = () => {
    wrapper = shallowMount(PremiumPlanBillingHeader, {
      propsData: { ...mockBillingPageAttributes, ctaLabel },
    });
  };

  it('renders component', () => {
    createComponent();

    const cta = findGlButton();

    expect(cta.props('href')).toBe(mockBillingPageAttributes.upgradeToPremiumUrl);
    expect(cta.text()).toBe(ctaLabel);
  });
});
