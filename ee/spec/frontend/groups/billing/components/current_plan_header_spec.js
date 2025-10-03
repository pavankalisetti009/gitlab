import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import CurrentPlanHeader from 'ee/groups/billing/components/current_plan_header.vue';
import { mockBillingPageAttributes } from '../../mock_data';

describe('CurrentPlanHeader', () => {
  let wrapper;

  const findGlButton = () => wrapper.findComponent(GlButton);
  const content = () => wrapper.text().replace(/\s+/g, ' ');

  const createComponent = (props = {}) => {
    wrapper = shallowMount(CurrentPlanHeader, {
      propsData: { ...mockBillingPageAttributes, ...props },
    });
  };

  it('renders component', () => {
    createComponent();

    expect(content()).toContain('Your group is on GitLab Free');
    expect(content()).toMatch('1/5 Seats in use');
    expect(findGlButton().props('href')).toBe(mockBillingPageAttributes.manageSeatsPath);
  });

  describe('when total seats is 0', () => {
    it('renders components', () => {
      createComponent({ totalSeats: 0 });

      expect(content()).toMatch('1/Unlimited Seats in use');
    });
  });

  describe('when trial is active', () => {
    it('renders components', () => {
      createComponent({ trialActive: true });

      expect(content()).toContain('Your group is on a trial of Ultimate + Duo Enterprise');
      expect(content()).toMatch('1 Seats in use');
    });
  });
});
