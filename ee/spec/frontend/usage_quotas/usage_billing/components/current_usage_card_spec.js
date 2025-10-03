import { GlProgressBar, GlSprintf } from '@gitlab/ui';
import CurrentUsageCard from 'ee/usage_quotas/usage_billing/components/current_usage_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import { useFakeDate } from 'helpers/fake_date';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';

describe('CurrentUsageCard', () => {
  let wrapper;

  // September 7th, 2025
  useFakeDate(2025, 8, 7);
  const defaultProps = {
    currentOverage: 1,
    totalCreditsUsed: 7800,
    totalCredits: 10000,
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
        HumanTimeframe,
      },
    });
  };

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('Current month usage');
    });

    it('renders formatted total credits used', () => {
      expect(wrapper.findByTestId('total-credits-used').text()).toBe('7.8k');
    });

    it('renders formatted total credits', () => {
      expect(wrapper.findByTestId('total-credits').text()).toMatchInterpolatedText('/ 10k');
    });

    it('renders the formatted date range', () => {
      expect(wrapper.findByTestId('date-range').text()).toMatchInterpolatedText(
        'Sep 1 – 30, 2025 - 23 days remaining',
      );
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
        (variant, totalCreditsUsed, totalCredits) => {
          createComponent({ totalCreditsUsed, totalCredits });

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

    it('renders correct pool credits remaining', () => {
      expect(wrapper.findByTestId('pool-credits-remaining').text()).toBe(
        '2.2k pool credits remaining',
      );
    });

    it('renders correct current overage value', () => {
      expect(wrapper.findByTestId('current-overage').text()).toBe('Current overage 1');
    });
  });

  describe('when total credits is 0', () => {
    beforeEach(() => {
      createComponent({ totalCredits: 0 });
    });

    it('renders correct utilized credits percentage', () => {
      expect(wrapper.findByTestId('percentage-utilized').text()).toBe('0% utilized');
    });

    it('passes 0 as gl-progress-bar value', () => {
      expect(wrapper.findComponent(GlProgressBar).props('value')).toBe(0);
    });
  });
});
