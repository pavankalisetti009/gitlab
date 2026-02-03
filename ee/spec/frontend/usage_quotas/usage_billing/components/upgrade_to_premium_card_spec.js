import { GlButton, GlLink } from '@gitlab/ui';
import UpgradeToPremiumCard from 'ee/usage_quotas/usage_billing/components/upgrade_to_premium_card.vue';
import { PROMO_URL } from '~/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

describe('UpgradeToPremiumCard', () => {
  let wrapper;

  const createComponent = (propsData = {}, provide = {}) => {
    wrapper = mountExtended(UpgradeToPremiumCard, {
      propsData,
      provide: {
        isSaas: true,
        ...provide,
      },
    });
  };

  const findPricingLink = () => wrapper.findComponent(GlLink);
  const findUpgradeButton = () => wrapper.findComponent(GlButton);
  const findCardTitle = () => wrapper.find('h2');

  beforeEach(() => {
    window.gon = { subscriptions_url: 'https://subscriptions.example.com' };
  });

  describe('on SaaS (GitLab.com)', () => {
    beforeEach(() => {
      createComponent({}, { isSaas: true });
    });

    it('renders card title', () => {
      expect(findCardTitle().text()).toBe('Unlock more credits with Premium');
    });

    it('renders message with pricing link text', () => {
      expect(wrapper.text()).toContain('Upgrade to keep using GitLab Duo Agent Platform');
      expect(wrapper.text()).toContain('access a broad credit allocation');
      expect(wrapper.text()).toContain('GitLab Credit pricing');
    });

    it('renders pricing link with correct href for SaaS', () => {
      expect(findPricingLink().props('href')).toBe(`${PROMO_URL}/pricing`);
      expect(findPricingLink().props('target')).toBe('_blank');
    });

    it('renders call to action button with subscriptions URL', () => {
      expect(findUpgradeButton().props('href')).toBe('https://subscriptions.example.com');
      expect(findUpgradeButton().props('variant')).toBe('confirm');
      expect(findUpgradeButton().text()).toBe('Upgrade to Premium');
    });

    describe('tracking', () => {
      useMockInternalEventsTracking();

      it('has correct tracking attributes on pricing link', () => {
        expect(findPricingLink().attributes()).toMatchObject({
          'data-event-action': 'click_link',
          'data-event-label': 'gitlab_credit_pricing',
          'data-event-property': 'upgrade_to_premium_card',
        });
      });

      it('has correct tracking attributes on upgrade button', () => {
        expect(findUpgradeButton().attributes()).toMatchObject({
          'data-event-action': 'click_CTA',
          'data-event-label': 'upgrade_to_premium',
          'data-event-property': 'upgrade_to_premium_card',
        });
      });
    });
  });

  describe('on self-managed', () => {
    beforeEach(() => {
      createComponent({}, { isSaas: false });
    });

    it('renders card title', () => {
      expect(findCardTitle().text()).toBe('Unlock more credits with Premium');
    });

    it('renders message with pricing link text', () => {
      expect(wrapper.text()).toContain('Upgrade to keep using GitLab Duo Agent Platform');
      expect(wrapper.text()).toContain('access a broad credit allocation');
      expect(wrapper.text()).toContain('GitLab Credit pricing');
    });

    it('renders pricing link with self-managed deployment parameter', () => {
      expect(findPricingLink().props('href')).toBe(
        `${PROMO_URL}/pricing?deployment=self-managed-deployment`,
      );
      expect(findPricingLink().props('target')).toBe('_blank');
    });

    it('renders call to action button with subscriptions URL', () => {
      expect(findUpgradeButton().props('href')).toBe('https://subscriptions.example.com');
      expect(findUpgradeButton().props('variant')).toBe('confirm');
      expect(findUpgradeButton().text()).toBe('Upgrade to Premium');
    });

    describe('tracking', () => {
      useMockInternalEventsTracking();

      it('has correct tracking attributes on pricing link', () => {
        expect(findPricingLink().attributes()).toMatchObject({
          'data-event-action': 'click_link',
          'data-event-label': 'gitlab_credit_pricing',
          'data-event-property': 'upgrade_to_premium_card',
        });
      });

      it('has correct tracking attributes on upgrade button', () => {
        expect(findUpgradeButton().attributes()).toMatchObject({
          'data-event-action': 'click_CTA',
          'data-event-label': 'upgrade_to_premium',
          'data-event-property': 'upgrade_to_premium_card',
        });
      });
    });
  });
});
