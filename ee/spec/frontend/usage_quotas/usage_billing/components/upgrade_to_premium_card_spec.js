import { GlButton, GlLink } from '@gitlab/ui';
import UpgradeToPremiumCard from 'ee/usage_quotas/usage_billing/components/upgrade_to_premium_card.vue';
import { PROMO_URL } from '~/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';

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

  beforeEach(() => {
    window.gon = { subscriptions_url: 'https://subscriptions.example.com' };
  });

  describe('on SaaS (GitLab.com)', () => {
    beforeEach(() => {
      createComponent({}, { isSaas: true });
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('Unlock more credits with Premium');
    });

    it('renders message with pricing link text', () => {
      expect(wrapper.text()).toContain(
        'Upgrade to keep using GitLab Duo Agent Platform and access a broad credit allocation. Learn more about GitLab Credit pricing.',
      );
    });

    it('renders pricing link with correct href for SaaS', () => {
      const link = wrapper.findComponent(GlLink);
      expect(link.props('href')).toBe(`${PROMO_URL}/pricing`);
      expect(link.props('target')).toBe('_blank');
    });

    it('renders call to action button with subscriptions URL', () => {
      const button = wrapper.findComponent(GlButton);
      expect(button.props('href')).toBe('https://subscriptions.example.com');
      expect(button.props('variant')).toBe('confirm');
      expect(button.text()).toBe('Upgrade to Premium');
    });
  });

  describe('on self-managed', () => {
    beforeEach(() => {
      createComponent({}, { isSaas: false });
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('Unlock more credits with Premium');
    });

    it('renders message with pricing link text', () => {
      expect(wrapper.text()).toContain(
        'Upgrade to keep using GitLab Duo Agent Platform and access a broad credit allocation. Learn more about GitLab Credit pricing.',
      );
    });

    it('renders pricing link with self-managed deployment parameter', () => {
      const link = wrapper.findComponent(GlLink);
      expect(link.props('href')).toBe(`${PROMO_URL}/pricing?deployment=self-managed-deployment`);
      expect(link.props('target')).toBe('_blank');
    });

    it('renders call to action button with subscriptions URL', () => {
      const button = wrapper.findComponent(GlButton);
      expect(button.props('href')).toBe('https://subscriptions.example.com');
      expect(button.props('variant')).toBe('confirm');
      expect(button.text()).toBe('Upgrade to Premium');
    });
  });
});
