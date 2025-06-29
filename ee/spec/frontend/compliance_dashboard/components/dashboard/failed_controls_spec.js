import { shallowMount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import { GL_LIGHT } from '~/constants';
import FailedControls from 'ee/compliance_dashboard/components/dashboard/failed_controls.vue';
import PieChart from 'ee/compliance_dashboard/components/dashboard/components/pie_chart.vue';

describe('Failed controls panel', () => {
  let wrapper;

  function createComponent(controls) {
    wrapper = shallowMount(FailedControls, {
      propsData: {
        failedControls: {
          passed: 1,
          pending: 1,
          failed: 1,
          ...controls,
        },
        colorScheme: GL_LIGHT,
      },
    });
  }

  it('renders empty state when no controls statuses are available', () => {
    createComponent({ passed: 0, pending: 0, failed: 0 });
    expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
  });

  it('renders chart when controls are available', () => {
    createComponent();
    expect(wrapper.findComponent(PieChart).exists()).toBe(true);
  });
});
