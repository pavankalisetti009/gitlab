import { GlSkeletonLoader } from '@gitlab/ui';
import { GlSparklineChart } from '@gitlab/ui/dist/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TrendLine from 'ee/analytics/analytics_dashboards/components/visualizations/data_table/trend_line.vue';

describe('TrendLine', () => {
  let wrapper;
  const tooltipLabel = 'cool tooltip text';
  const data = [
    ['Jan', 20],
    ['Feb', 5],
    ['Mar', 4],
    ['Apr', 11],
    ['May', 13],
    ['Jun', 21],
  ];

  const findSparkline = () => wrapper.findComponent(GlSparklineChart);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  describe('default', () => {
    beforeEach(() => {
      wrapper = shallowMountExtended(TrendLine, {
        propsData: { data, tooltipLabel },
      });
    });

    it('renders the trend sparkline', () => {
      expect(findSparkline().props('data')).toEqual(data);
    });

    it('renders the default color gradient', () => {
      expect(findSparkline().props('gradient')).toEqual(['#499767', '#5252B5']);
    });

    it('passes the tooltipLabel to the sparkline', () => {
      expect(findSparkline().props('tooltipLabel')).toBe(tooltipLabel);
    });
  });

  describe('no data', () => {
    it('renders a loading state', () => {
      wrapper = shallowMountExtended(TrendLine, {
        propsData: { data: [] },
      });

      expect(findSparkline().exists()).toBe(false);
      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  describe('invertTrendColor = true', () => {
    beforeEach(() => {
      wrapper = shallowMountExtended(TrendLine, {
        propsData: { data, invertTrendColor: true },
      });
    });

    it('reverses the default color gradient', () => {
      expect(findSparkline().props('gradient')).toEqual(['#5252B5', '#499767']);
    });
  });
});
