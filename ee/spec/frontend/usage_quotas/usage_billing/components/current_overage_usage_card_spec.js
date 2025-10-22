import { GlSprintf } from '@gitlab/ui';
import CurrentOverageUsageCard from 'ee/usage_quotas/usage_billing/components/current_overage_usage_card.vue';
import HumanTimeframeWithDaysRemaining from 'ee/usage_quotas/usage_billing/components/human_timeframe_with_days_remaining.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('CurrentOverageUsageCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    overageCreditsUsed: 1,
    monthStartDate: '2025-09-01',
    monthEndDate: '2025-09-30',
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

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('On-demand credits used this billable month');
    });

    it('renders the formatted date range', () => {
      expect(wrapper.findComponent(HumanTimeframeWithDaysRemaining).props()).toMatchObject({
        monthStartDate: '2025-09-01',
        monthEndDate: '2025-09-30',
      });
    });

    it('renders correct current overage value', () => {
      expect(wrapper.findByTestId('overage-credits-used').text()).toBe('1');
    });
  });
});
