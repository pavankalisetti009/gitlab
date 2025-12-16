import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import CustomFieldsList from 'ee/groups/settings/work_items/custom_fields/custom_fields_list.vue';
import CustomStatusSettings from 'ee/groups/settings/work_items/custom_status/custom_status_settings.vue';
import ConfigurableTypesSettings from 'ee/groups/settings/work_items/configurable_types/configurable_types_settings.vue';
import SearchSettings from '~/search_settings/components/search_settings.vue';
import WorkItemSettingsHome from 'ee/groups/settings/work_items/work_item_settings_home.vue';

describe('WorkItemSettingsHome', () => {
  let wrapper;
  const fullPath = 'group/project';

  const createComponent = ({
    mocks = {},
    glFeatures = { workItemConfigurableTypes: true },
  } = {}) => {
    wrapper = shallowMount(WorkItemSettingsHome, {
      propsData: {
        fullPath,
      },
      mocks: {
        $route: { hash: '' },
        ...mocks,
      },
      provide: {
        glFeatures,
      },
    });
  };

  const findCustomFieldsList = () => wrapper.findComponent(CustomFieldsList);
  const findCustomStatusSettings = () => wrapper.findComponent(CustomStatusSettings);
  const findConfigurableTypesSettings = () => wrapper.findComponent(ConfigurableTypesSettings);
  const findSearchSettings = () => wrapper.findComponent(SearchSettings);
  const findPageTitle = () => wrapper.find('h1');

  it('renders ConfigurableTypesSettings component with correct props when FF is switched on', () => {
    createComponent();

    expect(findConfigurableTypesSettings().exists()).toBe(true);
    expect(findConfigurableTypesSettings().props('fullPath')).toBe(fullPath);
  });

  it('does not render ConfigurableTypesSettings when `workItemTypesConfigurableTypes` FF is off', () => {
    createComponent({
      glFeatures: { workItemConfigurableTypes: false },
    });

    expect(findConfigurableTypesSettings().exists()).toBe(false);
  });

  it('always renders CustomFieldsList component with correct props', () => {
    createComponent();

    expect(findCustomFieldsList().exists()).toBe(true);
    expect(findCustomFieldsList().props('fullPath')).toBe(fullPath);
  });

  it('renders CustomStatusSettings component with correct props', () => {
    createComponent();

    expect(findCustomStatusSettings().exists()).toBe(true);
  });

  describe('SearchSettings', () => {
    it('renders SearchSettings component when searchRoot is available', async () => {
      createComponent();

      await nextTick();

      expect(findSearchSettings().exists()).toBe(true);
    });

    it('passes correct props to SearchSettings', async () => {
      createComponent();

      await nextTick();

      const searchSettings = findSearchSettings();
      expect(searchSettings.props('sectionSelector')).toBe('.vue-settings-block');
    });
  });

  describe('Toggle Expand', () => {
    let mockRouter;

    beforeEach(() => {
      mockRouter = {
        push: jest.fn(),
      };
    });

    it('navigates to hash when CustomStatusSettings toggle-expand emits true', async () => {
      createComponent({ mocks: { $router: mockRouter } });

      await findCustomStatusSettings().vm.$emit('toggle-expand', true);

      expect(mockRouter.push).toHaveBeenCalledWith({
        name: 'workItemSettingsHome',
        hash: '#js-custom-status-settings',
      });
    });

    it('navigates to hash when CustomFieldsList toggle-expand emits true', async () => {
      createComponent({ mocks: { $router: mockRouter } });

      await findCustomFieldsList().vm.$emit('toggle-expand', true);

      expect(mockRouter.push).toHaveBeenCalledWith({
        name: 'workItemSettingsHome',
        hash: '#js-custom-fields-settings',
      });
    });

    it('navigates to hash when ConfigurableTypesSettings toggle-expand emits true', async () => {
      createComponent({ mocks: { $router: mockRouter } });

      await findConfigurableTypesSettings().vm.$emit('toggle-expand', true);

      expect(mockRouter.push).toHaveBeenCalledWith({
        name: 'workItemSettingsHome',
        hash: '#js-work-item-types-settings',
      });
    });

    it('clears hash when toggling to false without existing hash', async () => {
      createComponent({ mocks: { $router: mockRouter, $route: { hash: '' } } });

      await findCustomStatusSettings().vm.$emit('toggle-expand', false);

      expect(mockRouter.push).not.toHaveBeenCalled();
    });

    it('clears hash when toggling to false with existing hash', async () => {
      createComponent({
        mocks: {
          $router: mockRouter,
          $route: { hash: '#js-custom-status-settings' },
        },
      });

      await findCustomStatusSettings().vm.$emit('toggle-expand', false);

      expect(mockRouter.push).toHaveBeenCalledWith({
        name: 'workItemSettingsHome',
        hash: '',
      });
    });
  });

  describe('Expanded State from Route Hash', () => {
    it('expands CustomStatusSettings when route hash matches section id', () => {
      createComponent({ mocks: { $route: { hash: '#js-custom-status-settings' } } });

      expect(findCustomStatusSettings().props('expanded')).toBe(true);
    });

    it('expands CustomFieldsList when route hash matches section id', () => {
      createComponent({ mocks: { $route: { hash: '#js-custom-fields-settings' } } });

      expect(findCustomFieldsList().props('expanded')).toBe(true);
    });

    it('does not expand sections when hash does not match', () => {
      createComponent({ mocks: { $route: { hash: '#other-section' } } });

      expect(findCustomStatusSettings().props('expanded')).toBe(false);
      expect(findCustomFieldsList().props('expanded')).toBe(false);
    });
  });

  describe('page title', () => {
    it('shows "Work items" when work_item_planning_view feature flag is enabled', () => {
      createComponent({ glFeatures: { workItemPlanningView: true } });

      expect(findPageTitle().text()).toBe('Work items');
    });

    it('shows "Issues" when work_item_planning_view feature flag is disabled', () => {
      createComponent({ glFeatures: { workItemPlanningView: false } });

      expect(findPageTitle().text()).toBe('Issues');
    });
  });
});
