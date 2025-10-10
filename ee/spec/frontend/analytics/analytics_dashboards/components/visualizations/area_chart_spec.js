import { GlAreaChart } from '@gitlab/ui/src/charts';
import { shallowMount } from '@vue/test-utils';
import AreaChart from 'ee/analytics/analytics_dashboards/components/visualizations/area_chart.vue';

describe('AreaChart Visualization', () => {
  let wrapper;

  const findAreaChart = () => wrapper.findComponent(GlAreaChart);

  const createWrapper = ({ props = {} } = {}) => {
    wrapper = shallowMount(AreaChart, {
      propsData: {
        data: [],
        options: {},
        ...props,
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          data: [{ name: 'foo', data: ['bar', 1000] }],
          options: { yAxis: {}, xAxis: {} },
        },
      });
    });

    it('should render area chart with the provided data and default options', () => {
      expect(findAreaChart().props()).toMatchObject({
        data: [{ name: 'foo', data: ['bar', 1000] }],
      });

      expect(findAreaChart().attributes('responsive')).toBe('');
      expect(findAreaChart().props().includeLegendAvgMax).toBe(true);
      expect(findAreaChart().props().option).toMatchObject({
        yAxis: { type: 'value' },
        xAxis: { type: 'category' },
      });
    });

    it('can toggle legend average/max values', () => {
      createWrapper({ props: { options: { includeLegendAvgMax: false } } });

      expect(findAreaChart().props().includeLegendAvgMax).toBe(false);
    });
  });
});
