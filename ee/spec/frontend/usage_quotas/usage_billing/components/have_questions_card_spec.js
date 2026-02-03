import { GlButton } from '@gitlab/ui';
import HaveQuestionsCard from 'ee/usage_quotas/usage_billing/components/have_questions_card.vue';
import { PROMO_URL } from '~/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

describe('HaveQuestionsCard', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = mountExtended(HaveQuestionsCard);
  };

  const findCardTitle = () => wrapper.find('h2');
  const findContactSalesButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    createComponent();
  });

  it('renders card title', () => {
    expect(findCardTitle().text()).toBe('Have questions?');
  });

  it('renders card description', () => {
    expect(wrapper.text()).toContain(
      'Learn more about the upgrade process and Credits pricing options by talking to sales.',
    );
  });

  it('renders contact sales button', () => {
    expect(findContactSalesButton().exists()).toBe(true);
    expect(findContactSalesButton().text()).toBe('Contact sales');
  });

  it('renders button with correct href', () => {
    expect(findContactSalesButton().props('href')).toBe(`${PROMO_URL}/sales`);
  });

  it('renders button with secondary variant', () => {
    expect(findContactSalesButton().props('category')).toBe('secondary');
  });

  describe('tracking', () => {
    useMockInternalEventsTracking();

    it('has correct tracking attributes on contact sales button', () => {
      expect(findContactSalesButton().attributes()).toMatchObject({
        'data-event-action': 'click_CTA',
        'data-event-label': 'contact_sales',
        'data-event-property': 'have_questions_card',
      });
    });
  });
});
