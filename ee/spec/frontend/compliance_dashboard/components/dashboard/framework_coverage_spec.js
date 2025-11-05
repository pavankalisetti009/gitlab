import { shallowMount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import { GlChart } from '@gitlab/ui/src/charts';
import { GL_LIGHT } from '~/constants';
import FrameworkCoverage from 'ee/compliance_dashboard/components/dashboard/framework_coverage.vue';
import { ROUTE_PROJECTS } from 'ee/compliance_dashboard/constants';

describe('Framework coverage panel', () => {
  let wrapper;
  const pushMock = jest.fn();

  function createComponent(details = [], totalProjects = 0) {
    wrapper = shallowMount(FrameworkCoverage, {
      propsData: {
        summary: {
          totalProjects,
          coveredCount: 0,
          details,
        },
        colorScheme: GL_LIGHT,
        isTopLevelGroup: true,
      },
      mocks: {
        $router: {
          push: pushMock,
        },
      },
    });
  }

  it('renders empty state when no frameworks are available', () => {
    createComponent();
    expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
  });

  it('renders chart when frameworks are available', () => {
    createComponent([{ id: 1, coveredCount: 10, framework: {} }]);
    expect(wrapper.findComponent(GlChart).exists()).toBe(true);
  });

  it('takes to projects tab when chart is clicked', () => {
    createComponent([{ id: 1, coveredCount: 10, framework: {} }]);

    wrapper.findComponent(GlChart).vm.$emit('chartItemClicked');
    expect(pushMock).toHaveBeenCalledWith({ name: ROUTE_PROJECTS });
  });

  describe('framework sorting', () => {
    it('sorts frameworks by coveredCount in correct order', () => {
      const totalProjects = 100;
      const details = [
        { id: 1, coveredCount: totalProjects * 0.05, framework: { id: 1, name: 'Framework A' } },
        { id: 2, coveredCount: totalProjects * 0.15, framework: { id: 2, name: 'Framework B' } },
        { id: 3, coveredCount: totalProjects * 0.1, framework: { id: 3, name: 'Framework C' } },
      ];

      createComponent(details, totalProjects);

      const valuesPassedToChart = wrapper
        .findComponent(GlChart)
        .props('options')
        .series[0].data.map((d) => d.value);

      // Last one is 0 for "all items"
      expect(valuesPassedToChart).toEqual([5, 10, 15, 0]);
    });
  });
});
