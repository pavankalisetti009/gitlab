import { shallowMount } from '@vue/test-utils';
import { GlIcon, GlLink } from '@gitlab/ui';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import { subgroupsAndProjects } from '../mock_data';

describe('NameCell', () => {
  let wrapper;

  const mockProject = subgroupsAndProjects.data.group.projects.nodes[0];
  const mockGroup = subgroupsAndProjects.data.group.descendantGroups.nodes[0];

  const createComponent = (item) => {
    wrapper = shallowMount(NameCell, {
      propsData: { item },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findLink = () => wrapper.findComponent(GlLink);
  const findAvatar = () => wrapper.findComponent(ProjectAvatar);

  describe('project view', () => {
    beforeEach(() => {
      createComponent(mockProject);
    });

    it('renders icon and text correctly', () => {
      expect(findIcon().props('name')).toBe('project');
      expect(wrapper.text()).toBe(mockProject.name);
    });

    it('does not render a link', () => {
      expect(findLink().exists()).toBe(false);
    });

    it('renders the correct avatar props', () => {
      expect(findAvatar().props()).toMatchObject({
        projectId: mockProject.id,
        projectName: mockProject.name,
        projectAvatarUrl: mockProject.avatarUrl,
      });
    });
  });

  describe('group view', () => {
    beforeEach(() => {
      createComponent(mockGroup);
    });

    it('renders icon and text correctly', () => {
      expect(findIcon().props('name')).toBe('subgroup');
      expect(wrapper.text()).toContain(mockGroup.name);
      expect(wrapper.text()).toContain(
        `${mockGroup.projectsCount} project, ${mockGroup.descendantGroupsCount} subgroups`,
      );
    });

    it('renders the correct link', () => {
      expect(findLink().exists()).toBe(true);
      expect(findLink().attributes('href')).toBe(`#${mockGroup.fullPath}`);
    });

    it('renders the correct avatar props', () => {
      expect(findAvatar().props()).toMatchObject({
        projectId: mockGroup.id,
        projectName: mockGroup.name,
        projectAvatarUrl: mockGroup.avatarUrl,
      });
    });
  });
});
