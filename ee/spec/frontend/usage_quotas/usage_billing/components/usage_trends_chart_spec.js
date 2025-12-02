import { GlAreaChart } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UsageTrendsChart from 'ee/usage_quotas/usage_billing/components/usage_trends_chart.vue';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';

describe('UsageTrendsChart', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    monthStartDate: '2025-10-01',
    monthEndDate: '2025-10-31',
    monthlyCommitmentDailyUsage: [
      { date: '2025-10-06', creditsUsed: 1 },
      { date: '2025-10-07', creditsUsed: 1.5 },
      { date: '2025-10-10', creditsUsed: 2 },
    ],
    monthlyWaiverDailyUsage: [
      { date: '2025-10-12', creditsUsed: 5 },
      { date: '2025-10-14', creditsUsed: 7.5 },
      { date: '2025-10-15', creditsUsed: 10 },
    ],
    overageDailyUsage: [
      { date: '2025-10-15', creditsUsed: 12.5 },
      { date: '2025-10-16', creditsUsed: 13 },
      { date: '2025-10-18', creditsUsed: 15.5 },
    ],
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(UsageTrendsChart, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findGlAreaChart = () => wrapper.findComponent(GlAreaChart);
  const findHumanTimeframe = () => wrapper.findComponent(HumanTimeframe);

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders chart heading', () => {
      expect(wrapper.find('h2').text()).toBe('GitLab Credits usage');
    });

    it('renders HumanTimeframe with correct props', () => {
      expect(findHumanTimeframe().exists()).toBe(true);
      expect(findHumanTimeframe().props()).toMatchObject({
        from: '2025-10-01',
        till: '2025-10-31',
      });
    });

    describe('GlAreaChart props', () => {
      it('passes the correct `option` prop to GlAreaChart', () => {
        expect(findGlAreaChart().props('option')).toMatchObject({
          xAxis: { name: 'Date', type: 'category' },
          yAxis: { name: 'Credits' },
        });
      });

      it('converts and passes data correctly', () => {
        const chartData = findGlAreaChart().props('data');

        expect(chartData).toEqual([
          {
            name: 'Monthly commitment',
            stack: 'daily',
            data: [
              ['2025-10-06', 1],
              ['2025-10-07', 1.5],
              ['2025-10-10', 2],
            ],
          },
          {
            name: 'Monthly waiver',
            stack: 'daily',
            data: [
              ['2025-10-12', 5],
              ['2025-10-14', 7.5],
              ['2025-10-15', 10],
            ],
          },
          {
            name: 'On-demand',
            stack: 'daily',
            data: [
              ['2025-10-15', 12.5],
              ['2025-10-16', 13],
              ['2025-10-18', 15.5],
            ],
          },
        ]);
      });
    });
  });
});
