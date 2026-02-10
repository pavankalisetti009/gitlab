import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ConfigurableTypesSettings from 'ee/groups/settings/work_items/configurable_types/configurable_types_settings.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import WorkItemTypesList from 'ee/work_items/components/work_item_types_list.vue';

describe('ConfigurableTypesSettings', () => {
  let wrapper;

  const defaultProps = {
    fullPath: 'test-group',
    id: 'work-item-types-settings',
    expanded: false,
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(ConfigurableTypesSettings, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);
  const findWorkItemTypesList = () => wrapper.findComponent(WorkItemTypesList);
  const findHelpPageLink = () => wrapper.findComponent(HelpPageLink);
  const findDescription = () => wrapper.find('p');

  describe('default rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders SettingsBlock component', () => {
      expect(findSettingsBlock().exists()).toBe(true);
    });

    it('passes correct props to SettingsBlock', () => {
      expect(findSettingsBlock().props()).toEqual({
        id: defaultProps.id,
        title: 'Work item types',
        expanded: defaultProps.expanded,
      });
    });

    it('passes fullPath prop to WorkItemTypesList', () => {
      expect(findWorkItemTypesList().props('fullPath')).toBe(defaultProps.fullPath);
    });

    it('renders description text', () => {
      expect(findDescription().exists()).toBe(true);
      expect(findDescription().text()).toContain(
        'Work item types are used to track different kinds of work. Each work item type can have different lifecycles and fields.',
      );
    });

    it('renders help page link', () => {
      expect(findHelpPageLink().exists()).toBe(true);
      expect(findHelpPageLink().props('href')).toBe('user/work_items/_index.md');
      expect(findHelpPageLink().text()).toBe('How do I use or configure work item types?');
    });
  });

  describe('props handling', () => {
    it('renders with expanded prop as true', () => {
      createWrapper({ expanded: true });

      expect(findSettingsBlock().props('expanded')).toBe(true);
    });

    it('renders with expanded prop as false', () => {
      createWrapper({ expanded: false });

      expect(findSettingsBlock().props('expanded')).toBe(false);
    });

    it('renders with different fullPath', () => {
      const customPath = 'my-group/sub-group/project';
      createWrapper({ fullPath: customPath });

      expect(findWorkItemTypesList().props('fullPath')).toBe(customPath);
    });

    it('renders with different id', () => {
      const customId = 'custom-id-123';
      createWrapper({ id: customId });

      expect(findSettingsBlock().props('id')).toBe(customId);
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits toggle-expand event when SettingsBlock emits toggle-expand', () => {
      findSettingsBlock().vm.$emit('toggle-expand', true);

      expect(wrapper.emitted('toggle-expand')).toHaveLength(1);
      expect(wrapper.emitted('toggle-expand')[0]).toEqual([true]);
    });

    it('emits toggle-expand event with false value', () => {
      findSettingsBlock().vm.$emit('toggle-expand', false);

      expect(wrapper.emitted('toggle-expand')).toHaveLength(1);
      expect(wrapper.emitted('toggle-expand')[0]).toEqual([false]);
    });

    it('emits multiple toggle-expand events', () => {
      findSettingsBlock().vm.$emit('toggle-expand', true);
      findSettingsBlock().vm.$emit('toggle-expand', false);
      findSettingsBlock().vm.$emit('toggle-expand', true);

      expect(wrapper.emitted('toggle-expand')).toHaveLength(3);
    });
  });
});
