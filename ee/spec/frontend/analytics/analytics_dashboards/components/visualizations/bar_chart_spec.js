import { GlBarChart } from '@gitlab/ui/src/charts';
import { shallowMount } from '@vue/test-utils';
import BarChart from 'ee/analytics/analytics_dashboards/components/visualizations/bar_chart.vue';

describe('BarChart Visualization', () => {
  /** @type {import('@vue/test-utils').Wrapper} */
  let wrapper;

  const findBarChart = () => wrapper.findComponent(GlBarChart);

  const createWrapper = ({ propsData = {} } = {}) => {
    wrapper = shallowMount(BarChart, { propsData });
  };

  it('should render the bar chart with provided data and options', () => {
    createWrapper({
      propsData: {
        data: {
          Office: [
            [100, 'Jim'],
            [210, 'Dwight'],
            [300, 'Pam'],
          ],
        },
        options: {
          yAxis: { name: 'User' },
          xAxis: { name: 'Stars', type: 'category' },
        },
      },
    });

    expect(findBarChart().props()).toMatchObject({
      data: expect.objectContaining({
        Office: [
          [100, 'Jim'],
          [210, 'Dwight'],
          [300, 'Pam'],
        ],
      }),
      option: expect.objectContaining({
        yAxis: { name: 'User' },
        xAxis: { name: 'Stars', type: 'category' },
      }),
      xAxisType: 'category',
      xAxisTitle: 'Stars',
      yAxisTitle: 'User',
      height: 'auto',
    });

    expect(findBarChart().attributes('responsive')).toBe('');
  });
});
