import { shallowMount } from '@vue/test-utils';
import { GlChart } from '@gitlab/ui/dist/charts';

import { GL_LIGHT } from '~/constants';
import PieChart from 'ee/compliance_dashboard/components/dashboard/components/pie_chart.vue';

describe('Compliance dashboard pie chart', () => {
  let wrapper;
  const pushMock = jest.fn();

  const getChartConfig = () => wrapper.getComponent(GlChart).props('options');

  const itemFormatter = jest.fn().mockImplementation((value) => `${value} something`);
  const legend = {
    passed: 'Passed',
    failed: 'Failed',
    pending: 'Pending',
  };

  function createComponent(props) {
    wrapper = shallowMount(PieChart, {
      propsData: {
        colorScheme: GL_LIGHT,
        legend,
        path: 'dummy',
        itemFormatter,
        data: {
          passed: 10,
          failed: 15,
          pending: 25,
        },
        ...props,
      },
      mocks: {
        $router: {
          push: pushMock,
        },
      },
    });
  }

  describe('when one of data points is missing', () => {
    beforeEach(() => {
      createComponent({
        data: {
          passed: 0,
          failed: 5,
          pending: 10,
        },
      });
    });

    it('does not put empty element to the legend', () => {
      const config = getChartConfig();
      expect(config.legend.data).toEqual([legend.pending, legend.failed]);
    });

    it('does not include empty series', () => {
      const config = getChartConfig();
      expect(config.series[0].data.map((s) => s.field)).toEqual(['pending', 'failed']);
    });
  });

  it('Calls push when chart is clicked', () => {
    createComponent();
    const chart = wrapper.getComponent(GlChart);
    chart.vm.$emit('chartItemClicked');
    expect(pushMock).toHaveBeenCalledWith({ name: wrapper.props('path') });
  });

  it('uses itemFormatter for representing series', () => {
    createComponent();
    const config = getChartConfig();
    expect(config.series[0].data.map((s) => s.label.formatter)).toEqual([
      '20% passed\n10 something',
      '50% pending\n25 something',
      '30% failed\n15 something',
    ]);
  });
});
