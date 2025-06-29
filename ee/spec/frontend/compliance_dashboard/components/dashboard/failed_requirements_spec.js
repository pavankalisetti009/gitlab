import { shallowMount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import { GL_LIGHT } from '~/constants';
import FailedRequirements from 'ee/compliance_dashboard/components/dashboard/failed_requirements.vue';
import PieChart from 'ee/compliance_dashboard/components/dashboard/components/pie_chart.vue';

describe('Failed requirements panel', () => {
  let wrapper;

  function createComponent(requirements) {
    wrapper = shallowMount(FailedRequirements, {
      propsData: {
        failedRequirements: {
          passed: 1,
          pending: 1,
          failed: 1,
          ...requirements,
        },
        colorScheme: GL_LIGHT,
      },
    });
  }

  it('renders empty state when no requirements statuses are available', () => {
    createComponent({ passed: 0, pending: 0, failed: 0 });
    expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
  });

  it('renders chart when requirements are available', () => {
    createComponent();
    expect(wrapper.findComponent(PieChart).exists()).toBe(true);
  });
});
