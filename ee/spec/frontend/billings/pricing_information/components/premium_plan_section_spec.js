import { shallowMount } from '@vue/test-utils';
import { GlIcon, GlLink } from '@gitlab/ui';
import PremiumPlanSection from 'ee/billings/pricing_information/components/premium_plan_section.vue';

describe('PremiumPlanSection', () => {
  let wrapper;

  const defaultProps = {
    groupId: 123,
    groupBillingHref: '/groups/test-group/-/billings',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(PremiumPlanSection, {
      propsData: { ...defaultProps, ...props },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('displays the correct content', () => {
    const text = wrapper.text();

    expect(text).toContain('Premium');
    expect(text).toContain('$29 per user/month');
    expect(text).toContain('Everything from Free, plus:');
    expect(text).toContain('AI Chat in the IDE');
    expect(text).toContain('AI Code Suggestions in the IDE');
    expect(text).toContain('Release Controls');
    expect(text).toContain('Team Project Management');
    expect(text).toContain('Priority Support');
    expect(text).toContain('10,000 compute minutes per month');
    expect(text).toContain('Unlimited licensed users');
    expect(text).toContain('See all features and compare plans');
  });

  it('renders the compare plans link with correct props', () => {
    const link = wrapper.findComponent(GlLink);

    expect(link.exists()).toBe(true);
    expect(link.props('href')).toBe('/groups/test-group/-/billings');
    expect(link.attributes('data-event-tracking')).toBe('click_link_compare_plans');
    expect(link.attributes('data-event-property')).toBe('123');
  });

  it('renders check icons for all features', () => {
    const icons = wrapper.findAllComponents(GlIcon);

    expect(icons).toHaveLength(7);
    icons.wrappers.forEach((icon) => {
      expect(icon.props('name')).toBe('check');
    });
  });
});
