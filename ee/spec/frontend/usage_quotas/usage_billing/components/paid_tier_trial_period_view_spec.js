import { GlButton, GlCard, GlLink, GlSprintf } from '@gitlab/ui';
import PaidTierTrialPeriodView from 'ee/usage_quotas/usage_billing/components/paid_tier_trial_period_view.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('PaidTierTrialPeriodView', () => {
  /** @type {import('@vue/test-utils').Wrapper} */
  let wrapper;

  const defaultProps = {
    customersUsageDashboardUrl: 'https://customers.gitlab.com/dashboard',
    purchaseCreditsUrl: 'https://customers.gitlab.com/purchase/credits',
  };

  const createComponent = ({ propsData = {}, slots = {} } = {}) => {
    wrapper = shallowMountExtended(PaidTierTrialPeriodView, {
      propsData: {
        ...defaultProps,
        ...propsData,
      },
      slots,
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('header', () => {
      const findHeaderCard = () => wrapper.findByTestId('paid-tier-trial-header-card');

      it('renders the alert with info variant', () => {
        const headerCard = findHeaderCard();

        expect(headerCard.exists()).toBe(true);
        expect(headerCard.text()).toContain('Your GitLab evaluation credits are active');
      });

      it('renders link to the Customers portal', () => {
        const headerCardPrimaryButton = findHeaderCard().findComponent(GlButton);

        expect(headerCardPrimaryButton.exists()).toBe(true);
        expect(headerCardPrimaryButton.props('href')).toBe(
          'https://customers.gitlab.com/dashboard',
        );
      });
    });

    describe('chart slot', () => {
      it('renders content passed to the chart slot', () => {
        createComponent({
          slots: {
            chart: '<div data-testid="chart-content">Chart Content</div>',
          },
        });

        expect(wrapper.findByTestId('chart-content').text()).toBe('Chart Content');
      });
    });

    describe('secondary cards', () => {
      const findSecondaryCardsSection = () => wrapper.findByTestId('paid-tier-trial-body');

      describe('continue after your evaluation card', () => {
        const findFirstCard = () => findSecondaryCardsSection().findAllComponents(GlCard).at(0);

        it('renders the card', () => {
          const card = findFirstCard();

          expect(card.exists()).toBe(true);
          expect(card.text()).toContain('Continue after your evaluation');
        });

        it('renders the link with the correct href', () => {
          const linkComponent = findFirstCard().findComponent(GlLink);

          expect(linkComponent.exists()).toBe(true);
          expect(linkComponent.attributes('href')).toBe(
            'https://customers.gitlab.com/purchase/credits',
          );
        });

        describe('when purchase flow is not available', () => {
          beforeEach(() => {
            createComponent({
              propsData: {
                purchaseCreditsUrl: null,
              },
            });
          });

          it('does not render the card', () => {
            const card = findFirstCard();

            expect(card.exists()).toBe(true);
            expect(card.text()).not.toContain('Continue after your evaluation');
          });
        });
      });
    });
  });
});
