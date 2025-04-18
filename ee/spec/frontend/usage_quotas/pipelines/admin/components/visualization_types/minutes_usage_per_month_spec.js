import { GlAreaChart } from '@gitlab/ui/dist/charts';
import MinutesUsagePerMonth from 'ee/usage_quotas/pipelines/admin/components/visualization_types/minutes_usage_per_month.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { usageDataInstanceAggregated } from '../../mock_data';

describe('MinutesUsagePerMonth', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findAreaChart = () => wrapper.findComponent(GlAreaChart);
  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(MinutesUsagePerMonth, {
      propsData: {
        usageData: usageDataInstanceAggregated,
        isLoading: false,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders an area chart component', () => {
    expect(findAreaChart().exists()).toBe(true);
  });

  it('should contain a responsive attribute for the area chart', () => {
    expect(findAreaChart().attributes('responsive')).toBeDefined();
  });
});
