import { GlSprintf } from '@gitlab/ui';
import MonthlyWaiverCard from 'ee/usage_quotas/usage_billing/components/monthly_waiver_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('MonthlyWaiverCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    monthlyWaiverTotalCredits: 100_200.32,
    monthlyWaiverCreditsUsed: 1300.75,
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(MonthlyWaiverCard, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('GitLab Credits - Monthly Waiver');
    });

    it('renders monthly waiver credits used', () => {
      expect(wrapper.findByTestId('monthly-waiver-credits-used').text()).toBe('1.3k');
    });

    it('renders remaining credits', () => {
      expect(wrapper.findByTestId('monthly-waiver-remaining-credits').text()).toBe('98.9k');
    });
  });
});
