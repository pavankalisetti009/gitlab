import { GlStackedColumnChart } from '@gitlab/ui/src/charts';
import { shallowMount } from '@vue/test-utils';
import VulnerabilitiesByAgeChart from 'ee/security_dashboard/components/shared/charts/vulnerabilities_by_age_chart.vue';

describe('OpenVulnerabilitiesOverTimeChart', () => {
  let wrapper;

  const mockBars = [
    { name: 'Critical', id: 'CRITICAL', data: [10, 5] },
    { name: 'High', id: 'HIGH', data: [15, 20] },
  ];
  const mockLabels = ['<7 days', '7-14 days'];

  const findStackedColumnChart = () => wrapper.findComponent(GlStackedColumnChart);

  const defaultProps = {
    bars: mockBars,
    labels: mockLabels,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(VulnerabilitiesByAgeChart, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('passes bars to GlStackedColumnChart', () => {
    expect(findStackedColumnChart().props('bars')).toBe(mockBars);
  });

  it('passes labels to GlStackedColumnChart', () => {
    expect(findStackedColumnChart().props('groupBy')).toBe(mockLabels);
  });
});
