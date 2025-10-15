import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import { useFakeDate } from 'helpers/fake_date';
import HumanTimeframeWithDaysRemaining from 'ee/usage_quotas/usage_billing/components/human_timeframe_with_days_remaining.vue';

describe('HumanTimeframeWithDaysRemaining', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  // October 13th, 2025
  useFakeDate(2025, 9, 13);

  const defaultProps = {
    monthStartDate: '2025-10-01',
    monthEndDate: '2025-10-31',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(HumanTimeframeWithDaysRemaining, {
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

  describe.each`
    scenario       | monthStartDate            | monthEndDate              | expectedText
    ${'default'}   | ${'2025-10-01T00:00:00Z'} | ${'2025-10-31T23:59:59Z'} | ${'Oct 1 – 31, 2025 - 18 days remaining'}
    ${'pastMonth'} | ${'2025-09-01T00:00:00Z'} | ${'2025-09-30T23:59:59Z'} | ${'Sep 1 – 30, 2025 - 0 days remaining'}
  `('$scenario', ({ monthStartDate, monthEndDate, expectedText }) => {
    it('renders the timeframe with days remainder', () => {
      createComponent({ monthStartDate, monthEndDate });

      expect(wrapper.text()).toMatchInterpolatedText(expectedText);
    });
  });
});
