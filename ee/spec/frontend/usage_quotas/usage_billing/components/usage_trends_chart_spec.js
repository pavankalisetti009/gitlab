import { GlAreaChart } from '@gitlab/ui/src/charts';
import { GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UsageTrendsChart from 'ee/usage_quotas/usage_billing/components/usage_trends_chart.vue';

describe('UsageTrendsChart', () => {
  let wrapper;

  const defaultProps = {
    usageData: [
      ['2025-07-01', '1000'],
      ['2025-07-02', '200'],
    ],
    monthStartDate: '2025-07-01',
    monthEndDate: '2025-07-31',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(UsageTrendsChart, {
      propsData: { ...defaultProps, ...props },
    });
  };

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders formatted month date range', () => {
      expect(wrapper.findByTestId('chart-heading').text()).toBe('Jul 1 – 31, 2025');
    });

    it('passes the correct `option` prop to the gl-area-chart', () => {
      expect(wrapper.findComponent(GlAreaChart).props('option')).toMatchObject({
        xAxis: { name: 'Date', type: 'category' },
        yAxis: { name: 'Tokens' },
      });
    });

    it('passes the correct chartData to the gl-area-chart', () => {
      expect(wrapper.findComponent(GlAreaChart).props('data')).toMatchObject([
        {
          name: 'Daily usage',
          data: [
            ['2025-07-01', '1000'],
            ['2025-07-02', '200'],
          ],
        },
      ]);
    });
  });

  describe('trend changes', () => {
    it.each`
      trend  | badgeVariant | badgeIcon
      ${0.9} | ${'success'} | ${'trend-up'}
      ${0}   | ${'danger'}  | ${'trend-down'}
      ${0.2} | ${'neutral'} | ${'trend-static'}
    `(
      'pass the correct variant and icon to the badge when trend = $trend',
      ({ trend, badgeVariant, badgeIcon }) => {
        createComponent({ trend });

        expect(wrapper.findComponent(GlBadge).props()).toMatchObject({
          variant: badgeVariant,
          icon: badgeIcon,
        });
      },
    );

    it.each`
      trend  | className
      ${0.9} | ${'gl-text-green-500'}
      ${0}   | ${'gl-text-red-500'}
      ${0.2} | ${''}
    `(
      'pass the correct class to the usage trend title when trend = $trend',
      ({ trend, className }) => {
        createComponent({ trend });

        const title = wrapper.findByTestId('usage-trend-title');
        expect(title.attributes('class')).toContain(className);
      },
    );
  });
});
