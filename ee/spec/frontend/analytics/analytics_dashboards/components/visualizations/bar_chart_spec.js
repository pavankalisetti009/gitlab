import { GlBarChart } from '@gitlab/ui/src/charts';
import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import BarChart from 'ee/analytics/analytics_dashboards/components/visualizations/bar_chart.vue';
import { CHART_TOOLTIP_TITLE_FORMATTERS, UNITS } from '~/analytics/shared/constants';

describe('BarChart Visualization', () => {
  /** @type {import('@vue/test-utils').Wrapper} */
  let wrapper;

  const mockData = {
    Office: [
      [100, 'Jim'],
      [210, 'Dwight'],
      [300, 'Pam'],
    ],
  };

  const mockOptions = {
    yAxis: { name: 'User' },
    xAxis: { name: 'Stars', type: 'category' },
    presentation: 'tiled',
  };

  const findBarChart = () => wrapper.findComponent(GlBarChart);

  const createWrapper = ({ data = mockData, options = {}, stubs = {} } = {}) => {
    wrapper = shallowMount(BarChart, {
      propsData: { data, options: { ...mockOptions, ...options } },
      stubs,
    });
  };

  describe('when mounted', () => {
    it('should render the bar chart with provided data and options', () => {
      createWrapper();

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
        presentation: 'tiled',
      });

      expect(findBarChart().attributes('responsive')).toBe('');
    });
  });

  describe('tooltip', () => {
    const mockSeries = {
      seriesIndex: 0,
      seriesId: 'pushes',
      seriesName: 'Pushes',
      value: [3000, 'dwight schrute'],
    };

    const { TITLE_CASE } = CHART_TOOLTIP_TITLE_FORMATTERS;

    it.each`
      description                       | tooltipOptions                                           | expectedTooltipText
      ${'no options have been defined'} | ${undefined}                                             | ${'dwight schrute 3000'}
      ${'options have been defined'}    | ${{ titleFormatter: TITLE_CASE, valueUnit: UNITS.DAYS }} | ${'Dwight Schrute 3000 days'}
    `(
      'formats the tooltip correctly when $description',
      ({ tooltipOptions, expectedTooltipText }) => {
        createWrapper({
          options: {
            chartTooltip: tooltipOptions,
          },
          stubs: {
            GlBarChart: stubComponent(GlBarChart, {
              data() {
                const [value, title] = mockSeries.value;

                return { value, title, params: { seriesData: [mockSeries] } };
              },
              template: `
              <div>
                <slot name="tooltip-title" :title="title" :params="params"></slot>
                <slot name="tooltip-value" :value="value"></slot>
              </div>
            `,
            }),
          },
        });

        expect(findBarChart().text()).toContain(expectedTooltipText);
      },
    );
  });
});
