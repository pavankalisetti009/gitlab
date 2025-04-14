import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import ActionCell from 'ee/security_inventory/components/action_cell.vue';
import { subgroupsAndProjects } from '../mock_data';

describe('ActionCell', () => {
  let wrapper;

  const mockProject = subgroupsAndProjects.data.group.projects.nodes[0];
  const mockGroup = subgroupsAndProjects.data.group.descendantGroups.nodes[0];

  const createComponent = (props = {}) => {
    return shallowMount(ActionCell, {
      propsData: {
        item: {},
        ...props,
      },
    });
  };

  describe.each`
    scenario         | item           | shouldRenderButton
    ${'for group'}   | ${mockGroup}   | ${false}
    ${'for project'} | ${mockProject} | ${true}
  `('$scenario', ({ item, shouldRenderButton }) => {
    beforeEach(() => {
      wrapper = createComponent({ item });
    });

    it(`${shouldRenderButton ? 'renders' : 'does not render'} settings button`, () => {
      expect(wrapper.findComponent(GlButton).exists()).toBe(shouldRenderButton);
    });
  });

  describe('settings button', () => {
    beforeEach(() => {
      wrapper = createComponent({ item: mockProject });
    });

    it('has correct properties', () => {
      const button = wrapper.findComponent(GlButton);
      const title = 'Manage security configuration';

      expect(button.props('icon')).toBe('settings');
      expect(button.attributes('href')).toBe(`${mockProject.webUrl}/-/security/configuration`);
      expect(button.attributes('aria-label')).toBe(title);
      expect(button.attributes('title')).toBe(title);
    });
  });
});
