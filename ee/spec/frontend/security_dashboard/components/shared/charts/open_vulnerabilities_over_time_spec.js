import { nextTick } from 'vue';
import { GlLink } from '@gitlab/ui';
import { GlLineChart, GlChartSeriesLabel } from '@gitlab/ui/dist/charts';
import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import OpenVulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';

describe('OpenVulnerabilitiesOverTimeChart', () => {
  let wrapper;

  const firstDayOfChartSeries = '2025-04-17';
  const mockChartSeries = [
    {
      name: 'Critical',
      id: 'CRITICAL',
      data: [
        [firstDayOfChartSeries, 5],
        ['2025-04-18', 5],
        ['2025-04-19', 7],
      ],
    },
    {
      name: 'High',
      id: 'HIGH',
      data: [
        [firstDayOfChartSeries, 25],
        ['2025-04-18', 27],
        ['2025-04-19', 30],
      ],
    },
  ];

  const findLineChart = () => wrapper.findComponent(GlLineChart);

  const defaultProps = {
    chartSeries: mockChartSeries,
    groupedBy: 'severity',
  };

  const defaultProvide = {
    securityVulnerabilitiesPath: 'namespace/security/vulnerabilities',
  };

  const createComponent = ({ props = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = shallowMount(OpenVulnerabilitiesOverTimeChart, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        ...stubs,
      },
    });
  };

  it('passes chart data to GlLineChart via props', () => {
    createComponent();

    expect(findLineChart().props('data')).toBe(mockChartSeries);
  });

  it('does not include legend avg/max values', () => {
    createComponent();

    expect(findLineChart().props('includeLegendAvgMax')).toBe(false);
  });

  it('enables the chart to have click-to-pin tooltip functionality so links within the tooltip can be accessed', () => {
    createComponent();

    expect(findLineChart().props('clickToPinTooltip')).toBe(true);
  });

  describe('tooltip configuration', () => {
    describe('tooltip content', () => {
      describe('when there is a securityVulnerabilitiesPathBase prop', () => {
        const mockTooltipParams = {
          seriesName: 'Severity',
          color: 'red',
          value: ['2025-04-18', 5],
          seriesId: 'CRITICAL',
        };

        beforeEach(() => {
          createComponent({
            stubs: {
              GlLineChart: stubComponent(GlLineChart, {
                data() {
                  return {
                    params: {
                      seriesData: [mockTooltipParams],
                    },
                  };
                },
                template: `
                <div>
                  <slot name="tooltip-content" :params="params"></slot>
                </div>`,
              }),
            },
          });
        });

        it('renders the chart label correctly', () => {
          expect(wrapper.findComponent(GlChartSeriesLabel).text()).toBe(
            mockTooltipParams.seriesName,
          );
          expect(wrapper.findComponent(GlChartSeriesLabel).props('color')).toBe(
            mockTooltipParams.color,
          );
        });

        it('renders the tooltip content with the correct link', () => {
          expect(wrapper.findComponent(GlLink).text()).toBe(`${mockTooltipParams.value[1]}`);
          expect(wrapper.findComponent(GlLink).attributes('href')).toBe(
            `${defaultProvide.securityVulnerabilitiesPath}?activity=ALL&state=CONFIRMED,DETECTED&${defaultProps.groupedBy}=${mockTooltipParams.seriesId}`,
          );
        });
      });
    });

    describe.each`
      condition                                    | componentSetup
      ${'no securityVulnerabilitiesPath provided'} | ${{ provide: { securityVulnerabilitiesPath: null } }}
      ${'no usable groupedBy-prop passed in'}      | ${{ props: { groupedBy: '' } }}
    `('when there is $condition', ({ componentSetup }) => {
      beforeEach(() => {
        createComponent(componentSetup);
      });

      it('does not render link in tooltip', () => {
        expect(wrapper.findComponent(GlLink).exists()).toBe(false);
      });

      it('does not enable click-to-pin tooltip functionality', () => {
        expect(findLineChart().props('clickToPinTooltip')).toBe(false);
      });
    });
  });

  describe('chartOptions', () => {
    it('configures the x-axis correctly', () => {
      createComponent();

      expect(findLineChart().props('option').xAxis).toMatchObject({
        name: null,
        key: 'date',
        type: 'category',
      });
    });

    it('configures the y-axis correctly', () => {
      createComponent();

      expect(findLineChart().props('option').yAxis).toMatchObject({
        name: null,
        key: 'vulnerabilities',
        type: 'value',
        minInterval: 1,
      });
    });

    it('configures dataZoom with the correct start date when chartStartDate is available', () => {
      createComponent();

      expect(findLineChart().props('option').dataZoom[0].startValue).toBe(firstDayOfChartSeries);
    });

    it('does not include dataZoom when chartStartDate is null', async () => {
      createComponent({ props: { chartSeries: [] } });

      await nextTick();

      expect(findLineChart().props('option').dataZoom).toBeUndefined();
    });
  });
});
