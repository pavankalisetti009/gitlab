import { GlProgressBar, GlSprintf } from '@gitlab/ui';
import CurrentUsageCard from 'ee/usage_quotas/usage_billing/components/current_usage_card.vue';
import HumanTimeframeWithDaysRemaining from 'ee/usage_quotas/usage_billing/components/human_timeframe_with_days_remaining.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('CurrentUsageCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    poolCreditsUsed: 7800,
    poolTotalCredits: 10000,
    monthStartDate: '2025-09-01',
    monthEndDate: '2025-09-30',
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(CurrentUsageCard, {
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
      expect(wrapper.find('h2').text()).toBe('GitLab Credits - Monthly committed pool');
    });

    it('renders formatted total credits used', () => {
      expect(wrapper.findByTestId('total-credits-used').text()).toBe('7.8k');
    });

    it('renders formatted total credits', () => {
      expect(wrapper.findByTestId('pool-total-credits').text()).toMatchInterpolatedText('/ 10k');
    });

    it('renders the formatted date range', () => {
      expect(wrapper.findComponent(HumanTimeframeWithDaysRemaining).props()).toMatchObject({
        monthStartDate: '2025-09-01',
        monthEndDate: '2025-09-30',
      });
    });
  });

  describe('gl-progress-bar', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders gl-progress-bar with correct credits', () => {
      const progressBar = wrapper.findComponent(GlProgressBar);

      expect(progressBar.props()).toMatchObject({ max: 100, value: '78.0' });
    });

    describe('progress bar variants', () => {
      it.each([
        ['primary', 78, 100],
        ['warning', 81, 100],
        ['danger', 120, 100],
      ])(
        'renders progress bar with "%s" variant when usagePercentage is %d',
        (variant, poolCreditsUsed, poolTotalCredits) => {
          createComponent({ poolCreditsUsed, poolTotalCredits });

          const progressBar = wrapper.findComponent(GlProgressBar);

          expect(progressBar.props('variant')).toBe(variant);
        },
      );
    });
  });

  describe('rendering credits percentages', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders correct utilized credits percentage', () => {
      expect(wrapper.findByTestId('percentage-utilized').text()).toBe('78.0% utilized');
    });

    it('renders correct credits remaining', () => {
      expect(wrapper.findByTestId('pool-credits-remaining').text()).toBe('2.2k credits remaining');
    });
  });

  describe('when total credits is 0', () => {
    beforeEach(() => {
      createComponent({ poolTotalCredits: 0 });
    });

    it('renders correct utilized credits percentage', () => {
      expect(wrapper.findByTestId('percentage-utilized').text()).toBe('0% utilized');
    });

    it('passes 0 as gl-progress-bar value', () => {
      expect(wrapper.findComponent(GlProgressBar).props('value')).toBe(0);
    });
  });
});
