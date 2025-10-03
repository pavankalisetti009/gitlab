import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import PremiumPlanHeader from 'ee/groups/billing/components/premium_plan_header.vue';
import { mockBillingPageAttributes } from '../../mock_data';

describe('PremiumPlanHeader', () => {
  let wrapper;

  const findGlButton = () => wrapper.findComponent(GlButton);
  const content = () => wrapper.text().replace(/\s+/g, ' ');

  const createComponent = (props = {}) => {
    wrapper = shallowMount(PremiumPlanHeader, {
      propsData: { ...mockBillingPageAttributes, ...props },
    });
  };

  it('renders component', () => {
    createComponent();

    expect(content()).toContain('Get the most out of GitLab with Ultimate');
    expect(content()).toContain('Start an Ultimate trial with GitLab Duo Enterprise');
    expect(content()).toContain('No credit card required');

    const cta = findGlButton();

    expect(cta.attributes('data-event-tracking')).toBe('click_duo_enterprise_trial_billing_page');
    expect(cta.attributes('data-event-label')).toBe('ultimate_and_duo_enterprise_trial');
    expect(cta.props('href')).toBe(mockBillingPageAttributes.startTrialPath);
    expect(cta.text()).toBe('Start free trial');
  });

  describe('when trial is active', () => {
    it('does not render badge', () => {
      createComponent({ trialActive: true });

      expect(content()).toContain('Level up with Premium');
      expect(content()).toContain("Don't lose access to advanced features");
      expect(content()).toContain('Team Project Management');

      const cta = findGlButton();

      expect(cta.attributes('data-track-action')).toBe('click_button');
      expect(cta.attributes('data-track-label')).toBe('plan_cta');
      expect(cta.attributes('data-track-property')).toBe('premium');
      expect(cta.props('href')).toBe(mockBillingPageAttributes.upgradeToPremiumUrl);
      expect(cta.text()).toBe('Choose Premium');
    });
  });

  describe('when trial is expired', () => {
    it('does not render badge', () => {
      createComponent({ trialExpired: true });

      expect(content()).toContain('Level up with Premium');
      expect(content()).toContain('Upgrade and unlock advanced features');
      expect(content()).toContain('Team Project Management');

      const cta = findGlButton();

      expect(cta.attributes('data-track-action')).toBe('click_button');
      expect(cta.attributes('data-track-label')).toBe('plan_cta');
      expect(cta.attributes('data-track-property')).toBe('premium');
      expect(cta.props('href')).toBe(mockBillingPageAttributes.upgradeToPremiumUrl);
      expect(cta.text()).toBe('Upgrade to Premium');
    });
  });
});
