import { GlBadge } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import FreePlanBillingHeader from 'ee/groups/billing/components/free_plan_billing_header.vue';
import { mockBillingPageAttributes } from '../../mock_data';

describe('FreePlanBillingHeader', () => {
  let wrapper;

  const findGlBadge = () => wrapper.findComponent(GlBadge);

  const createComponent = (props = {}) => {
    wrapper = shallowMount(FreePlanBillingHeader, {
      propsData: { ...mockBillingPageAttributes, ...props },
    });
  };

  it('renders badge', () => {
    createComponent();

    expect(findGlBadge().text()).toBe('Current subscription');
  });

  describe('when trial is active', () => {
    it('does not render badge', () => {
      createComponent({ trialActive: true });

      expect(findGlBadge().exists()).toBe(false);
    });
  });
});
