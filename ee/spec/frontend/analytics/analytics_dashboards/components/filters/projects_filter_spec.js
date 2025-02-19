import { shallowMount } from '@vue/test-utils';
import ProjectsFilter from 'ee/analytics/analytics_dashboards/components/filters/projects_filter.vue';
import ProjectsDropdownFilter from '~/analytics/shared/components/projects_dropdown_filter.vue';

describe('ProjectsFilter', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMount(ProjectsFilter, {
      propsData: {
        groupNamespace: 'group/subgroup',
        ...props,
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  const findProjectsDropdownFilter = () => wrapper.findComponent(ProjectsDropdownFilter);

  it('renders ProjectsDropdownFilter component', () => {
    expect(findProjectsDropdownFilter().exists()).toBe(true);
  });

  it('passes correct props to ProjectsDropdownFilter', () => {
    const dropdownFilter = findProjectsDropdownFilter();

    expect(dropdownFilter.props()).toMatchObject({
      toggleClasses: 'gl-max-w-26',
      queryParams: {
        first: 50,
        includeSubgroups: true,
      },
      groupNamespace: 'group/subgroup',
    });
  });

  describe('onProjectsSelected', () => {
    it('emits projectSelected event with correct values when a project is selected', () => {
      const selectedProject = {
        fullPath: 'group/project',
        id: '123',
      };
      findProjectsDropdownFilter().vm.$emit('selected', [selectedProject]);

      expect(wrapper.emitted('projectSelected')).toEqual([
        [
          {
            projectNamespace: 'group/project',
            projectId: '123',
          },
        ],
      ]);
    });

    it('does not emit projectSelected event if project attributes are null', () => {
      findProjectsDropdownFilter().vm.$emit('selected', [
        {
          fullPath: null,
          id: '123',
        },
      ]);
      findProjectsDropdownFilter().vm.$emit('selected', [
        {
          fullPath: 'abc',
          id: null,
        },
      ]);

      expect(wrapper.emitted('projectSelected')).toBeUndefined();
    });
  });
});
