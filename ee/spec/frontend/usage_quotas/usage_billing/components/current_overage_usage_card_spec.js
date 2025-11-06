import { GlSprintf } from '@gitlab/ui';
import CurrentOverageUsageCard from 'ee/usage_quotas/usage_billing/components/current_overage_usage_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('CurrentOverageUsageCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    overageCreditsUsed: 1,
    monthlyWaiverCreditsUsed: 42,
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(CurrentOverageUsageCard, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findMonthlyWaiverCreditsUsed = () => wrapper.findByTestId('monthly-waiver-credits-used');

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('GitLab Credits - On Demand');
    });

    it('renders correct current overage value', () => {
      expect(wrapper.findByTestId('overage-credits-used').text()).toBe('1');
    });

    it('renders monthly waiver usage value', () => {
      const monthlyWaiverCreditsUsed = findMonthlyWaiverCreditsUsed();

      expect(monthlyWaiverCreditsUsed.exists()).toBe(true);
      expect(monthlyWaiverCreditsUsed.text()).toBe('42');
    });
  });

  describe('without monthly waiver', () => {
    beforeEach(() => {
      createComponent({
        monthlyWaiverCreditsUsed: null,
      });
    });

    it('renders monthly waiver usage value', () => {
      const monthlyWaiverCreditsUsed = findMonthlyWaiverCreditsUsed();

      expect(monthlyWaiverCreditsUsed.exists()).toBe(false);
    });
  });
});
