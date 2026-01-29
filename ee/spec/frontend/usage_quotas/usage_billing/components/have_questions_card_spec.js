import { GlButton } from '@gitlab/ui';
import HaveQuestionsCard from 'ee/usage_quotas/usage_billing/components/have_questions_card.vue';
import { PROMO_URL } from '~/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';

describe('HaveQuestionsCard', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = mountExtended(HaveQuestionsCard);
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders card title', () => {
    expect(wrapper.find('h2').text()).toBe('Have questions?');
  });

  it('renders card description', () => {
    expect(wrapper.text()).toContain(
      'Learn more about the upgrade process and Credits pricing options by talking to sales.',
    );
  });

  it('renders contact sales button', () => {
    const button = wrapper.findComponent(GlButton);
    expect(button.exists()).toBe(true);
    expect(button.text()).toBe('Contact sales');
  });

  it('renders button with correct href', () => {
    const button = wrapper.findComponent(GlButton);
    expect(button.props('href')).toBe(`${PROMO_URL}/sales`);
  });

  it('renders button with secondary variant', () => {
    const button = wrapper.findComponent(GlButton);
    expect(button.props('category')).toBe('secondary');
  });
});
